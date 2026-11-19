<?php

namespace Tests\Feature;

use App\Jobs\ReplayStudent;
use App\Models\BktState;
use App\Models\Student;
use App\Models\SyncEvent;
use App\Models\SystemLog;
use App\Models\User;
use App\Support\Ops;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use RuntimeException;
use Tests\TestCase;

/**
 * Internet hosting from the home laptop (NFR-02, NFR-04, D-036): the tunnel
 * proxy, browser headers, CORS, sync acknowledgements that survive a failing
 * replay, the replay debounce, health, log retention and backups.
 */
class HardeningTest extends TestCase
{
    use RefreshDatabase;

    /** A request arriving through the local tunnel connector for $clientIp. */
    private function viaTunnel(string $clientIp, string $proto = 'https'): static
    {
        return $this->withServerVariables(['REMOTE_ADDR' => '127.0.0.1'])
            ->withHeaders(['X-Forwarded-For' => $clientIp, 'X-Forwarded-Proto' => $proto]);
    }

    private function event(array $payload = ['hearts' => 2], string $type = 'hearts'): array
    {
        return ['id' => (string) Str::uuid(), 'type' => $type, 'payload' => $payload, 'device_time' => '2026-11-19T01:00:00Z'];
    }

    // --- The tunnel proxy (config/trustedproxy.php) ------------------------------------

    public function test_each_school_behind_the_tunnel_gets_its_own_login_limit(): void
    {
        for ($i = 0; $i < 60; $i++) {
            $this->viaTunnel('198.51.100.7')->postJson('/api/auth/login', ['login_code' => 'ABCD-2345'])->assertUnprocessable();
        }
        $this->viaTunnel('198.51.100.7')->postJson('/api/auth/login', ['login_code' => 'ABCD-2345'])->assertTooManyRequests();

        // Another school is not locked out by the first one's typos.
        $this->viaTunnel('203.0.113.20')->postJson('/api/auth/login', ['login_code' => 'ABCD-2345'])->assertUnprocessable();
    }

    public function test_the_system_log_records_the_real_client_address(): void
    {
        $this->viaTunnel('198.51.100.7')->postJson('/api/auth/login', ['login_code' => 'ABCD-2345']);
        $this->viaTunnel('198.51.100.7')->post('/login', ['email' => 'nobody@example.org', 'password' => 'wrong-password']);

        $this->assertSame(['198.51.100.7'], SystemLog::query()->whereNotNull('ip')->distinct()->pluck('ip')->all());
    }

    public function test_only_the_local_connector_may_say_who_the_client_is(): void
    {
        // A client reaching the web server directly can't forge its address or https.
        $this->withServerVariables(['REMOTE_ADDR' => '192.0.2.50'])
            ->withHeaders(['X-Forwarded-For' => '10.9.9.9', 'X-Forwarded-Proto' => 'https'])
            ->get('/login')->assertOk()->assertHeaderMissing('Strict-Transport-Security');
        $this->assertSame('192.0.2.50', request()->ip());

        $this->viaTunnel('198.51.100.7')->get('/login')->assertOk()->assertHeader('Strict-Transport-Security');
        $this->assertSame('198.51.100.7', request()->ip());
        $this->assertTrue(request()->isSecure());
    }

    // --- Browser headers and CORS ------------------------------------------------------

    public function test_pages_carry_the_security_headers_and_a_fresh_script_nonce(): void
    {
        // Plain http (local development) gets no HSTS. (First: the test client
        // builds later URLs from the previous request's scheme.)
        $plain = $this->get('/login')->assertOk()->assertHeaderMissing('Strict-Transport-Security');

        $tunnel = $this->viaTunnel('198.51.100.7')->get('/login')->assertOk()
            ->assertHeader('Strict-Transport-Security', 'max-age=15552000')
            ->assertHeader('X-Content-Type-Options', 'nosniff')
            ->assertHeader('X-Frame-Options', 'DENY')
            ->assertHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
        $csp = $tunnel->headers->get('Content-Security-Policy');
        $this->assertStringContainsString("default-src 'self'", $csp);
        $this->assertStringContainsString("frame-ancestors 'none'", $csp);
        $this->assertMatchesRegularExpression("/script-src 'self' 'nonce-[A-Za-z0-9]{40}'/", $csp);
        $this->assertNotSame($csp, $plain->headers->get('Content-Security-Policy'), 'each response gets its own nonce');
    }

    public function test_the_dashboard_scripts_carry_the_nonce_and_chart_js_is_pinned(): void
    {
        $teacher = User::factory()->registered()->create();
        $section = $teacher->sections()->create(['name' => 'Grade 1 - Sampaguita']);

        $page = $this->actingAs($teacher)->get(route('teacher.sections.show', $section))->assertOk();

        preg_match("/'nonce-([A-Za-z0-9]{40})'/", $page->headers->get('Content-Security-Policy'), $m);
        $html = $page->getContent();
        $this->assertGreaterThanOrEqual(2, substr_count($html, '<script nonce="'.$m[1].'">'), 'the layout and chart scripts may run');
        $this->assertStringNotContainsString('<script>', $html, 'no inline script without the nonce');
        $this->assertStringContainsString('chart.umd.js" integrity="sha384-dug+JxfBvklEQdJ4AYuBBAIScUz0bVN73xpy273gcAwHjb3qI0fXmuYNaNfdyYJG" crossorigin="anonymous"', $html);
    }

    public function test_other_websites_cannot_call_the_api_from_a_browser(): void
    {
        $this->withHeaders(['Origin' => 'https://evil.example', 'Access-Control-Request-Method' => 'POST'])
            ->options('/api/auth/login')
            ->assertHeaderMissing('Access-Control-Allow-Origin');

        config(['cors.allowed_origins' => ['https://web.racoon.example']]);
        $this->withHeaders(['Origin' => 'https://web.racoon.example', 'Access-Control-Request-Method' => 'POST'])
            ->options('/api/auth/login')
            ->assertHeader('Access-Control-Allow-Origin', 'https://web.racoon.example');
    }

    // --- Sync: the acknowledgement depends only on the stored events -------------------

    public function test_a_failing_replay_never_costs_the_device_its_acknowledgement(): void
    {
        $student = Student::factory()->create();
        Sanctum::actingAs($student->user);
        // Break the replay for real: its rule tables are unreadable.
        config(['reading_racoon.shop.items' => 'broken']);
        $events = [$this->event(), $this->event()];

        $this->postJson('/api/sync', ['events' => $events])->assertOk()
            ->assertJsonPath('acknowledged', array_column($events, 'id'));

        $this->assertSame(2, SyncEvent::where('student_id', $student->id)->count());
        // The retry is acknowledged again, so the device can empty its queue.
        $this->postJson('/api/sync', ['events' => $events])->assertOk()
            ->assertJsonPath('acknowledged', array_column($events, 'id'));
        $this->assertSame(2, SyncEvent::where('student_id', $student->id)->count());
    }

    public function test_a_backlog_uploaded_in_many_batches_queues_one_replay(): void
    {
        Queue::fake();
        $student = Student::factory()->create();
        Sanctum::actingAs($student->user);

        for ($batch = 0; $batch < 5; $batch++) {
            $this->postJson('/api/sync', ['events' => [$this->event(), $this->event()]])->assertOk();
        }

        Queue::assertPushed(ReplayStudent::class, 1);
        Queue::assertPushed(ReplayStudent::class, fn (ReplayStudent $job) => $job->studentId === $student->id
            && $job->delay !== null);
    }

    public function test_the_replay_job_writes_the_official_state(): void
    {
        $student = Student::factory()->create();
        Sanctum::actingAs($student->user);
        $this->postJson('/api/sync', ['events' => [$this->event(['skill' => 'phonics', 'level' => 1,
            'correct' => true, 'num_choices' => 3, 'rescue' => false], 'response')]])->assertOk();

        // The "sync" test queue ran the job right away.
        $this->assertSame(1, BktState::where('student_id', $student->id)->where('sub_skill', 'phonics')
            ->where('level', 1)->value('attempts'));
    }

    public function test_a_replay_that_keeps_failing_is_logged_for_the_admin(): void
    {
        (new ReplayStudent(42))->failed(new RuntimeException('lock timeout'));

        $log = SystemLog::where('event', 'sync.replay_failed')->sole();
        $this->assertTrue($log->anomaly);
        $this->assertSame(42, $log->context['student_id']);
    }

    // --- Health, retention, backups ----------------------------------------------------

    public function test_health_reports_the_database_worker_and_scheduler(): void
    {
        $this->getJson('/api/health')->assertOk()
            ->assertJson(['status' => 'degraded', 'database' => true, 'queue_worker' => true, 'scheduler' => false])
            ->assertHeader('Cache-Control', 'no-store, private');

        Ops::beat('scheduler');
        $this->getJson('/api/health')->assertOk()->assertJsonPath('status', 'ok');

        DB::table('jobs')->insert(['queue' => 'default', 'payload' => '{}', 'attempts' => 0,
            'available_at' => now()->subMinutes(10)->getTimestamp(), 'created_at' => now()->subMinutes(10)->getTimestamp()]);
        config(['queue.default' => 'database']);
        $this->getJson('/api/health')->assertOk()->assertJson(['status' => 'degraded', 'queue_worker' => false]);
    }

    public function test_old_routine_log_rows_are_pruned_and_anomalies_kept_longer(): void
    {
        $old = fn (string $level, bool $anomaly, int $days) => tap(SystemLog::record('test.row', $level, anomaly: $anomaly),
            fn (SystemLog $log) => $log->forceFill(['created_at' => now()->subDays($days)])->save());
        $old('info', false, 100);   // pruned (info, > 90 days)
        $old('info', false, 10);    // kept
        $old('warning', true, 100); // kept (anomaly, < 365 days)
        $old('error', true, 400);   // pruned (> 365 days)

        $this->artisan('model:prune', ['--model' => [SystemLog::class]])->assertSuccessful();

        $this->assertSame([10, 100], SystemLog::where('event', 'test.row')->get()
            ->map(fn (SystemLog $log) => (int) round($log->created_at->diffInDays(now())))->sort()->values()->all());
    }

    public function test_a_failed_backup_leaves_no_partial_dump_and_alerts_the_admin(): void
    {
        $dir = storage_path('framework/testing/backups-'.Str::random(6));
        config(['reading_racoon.backup.path' => $dir, 'reading_racoon.backup.pg_dump' => $dir.'/no-such-pg_dump']);

        $this->artisan('app:backup')->assertFailed();

        $this->assertSame([], glob($dir.'/*') ?: []);
        $this->assertTrue(SystemLog::where('event', 'backup.failed')->sole()->anomaly);
        @rmdir($dir);
    }

    public function test_preflight_runs_and_flags_debug_on_a_production_box(): void
    {
        $this->artisan('app:preflight')->assertSuccessful();

        $this->app['env'] = 'production';
        config(['app.debug' => true, 'app.url' => 'http://racoon.example']);
        $this->artisan('app:preflight')
            ->expectsOutputToContain('APP_DEBUG is on')
            ->expectsOutputToContain('APP_URL is not https')
            ->assertFailed();
    }
}
