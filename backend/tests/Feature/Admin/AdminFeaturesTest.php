<?php

namespace Tests\Feature\Admin;

use App\Actions\EnrollStudent;
use App\Actions\ReplayStudentEvents;
use App\Enums\RegistrationStatus;
use App\Models\AuditLog;
use App\Models\Student;
use App\Models\SystemLog;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * What a signed-in admin can do (FR-08, FR-22): approve/deny teachers, read
 * logs with anomalies, run the RA 10173 privacy audit, export research CSVs.
 * Every action lands in the audit log.
 */
class AdminFeaturesTest extends AdminTestCase
{
    private User $root;

    protected function setUp(): void
    {
        parent::setUp();

        [$this->root, $secret] = $this->makeAdmin();
        $this->signIn($this->root, $secret)->assertRedirect($this->admin('home'));
    }

    public function test_approving_a_teacher_lets_them_sign_in_and_denying_revokes_it(): void
    {
        $teacher = User::factory()->registered(RegistrationStatus::Pending)->create(['name' => 'Maria Santos']);
        $teacher->sections()->create(['name' => 'Grade 1 - Sampaguita']);
        $registration = $teacher->registration;

        $this->get($this->admin('registrations'))->assertOk()->assertSee('Maria Santos')->assertSee('Grade 1 - Sampaguita');

        $this->post($this->admin("registrations/{$registration->id}/approve"), ['note' => 'Verified with principal'])->assertRedirect();
        $registration->refresh();
        $this->assertSame(RegistrationStatus::Approved, $registration->status);
        $this->assertSame($this->root->id, $registration->reviewed_by);
        $this->post('/login', ['email' => $teacher->email, 'password' => 'password'])->assertRedirect(route('teacher.home'));

        $this->post($this->admin("registrations/{$registration->id}/deny"))->assertRedirect();
        $this->get('/teacher')->assertRedirect(route('login'));

        $actions = AuditLog::whereIn('action', ['registration.approve', 'registration.deny'])->orderBy('id')->get();
        $this->assertSame(['registration.approve', 'registration.deny'], $actions->pluck('action')->all());
        $this->assertSame('Verified with principal', $actions[0]->details['note']);
        $this->assertSame($this->root->email, $actions[0]->actor_label);
    }

    public function test_an_unknown_registration_is_a_404(): void
    {
        $this->post($this->admin('registrations/999999/approve'))->assertNotFound();
    }

    public function test_logs_can_be_filtered_and_anomalies_are_highlighted(): void
    {
        SystemLog::record('access.check', 'info', ['status' => 'allowed']);
        SystemLog::record('sync.clock_ahead', 'warning', ['student' => 'RR-ABCDEF'], anomaly: true);

        $this->get($this->admin('logs'))->assertOk()
            ->assertSee('sync.clock_ahead')->assertSee('class="anomaly"', false);
        $this->get($this->admin('logs?anomaly=1'))->assertOk()
            ->assertSee('RR-ABCDEF')->assertDontSee('&quot;allowed&quot;', false);
        $this->get($this->admin('logs?kind=audit'))->assertOk()->assertSee('admin.login');
        $this->get($this->admin('logs?kind=nope&level=loud'))->assertOk()->assertSee('System log'); // bad filters are dropped
    }

    public function test_the_privacy_audit_reports_consent_and_security_checks(): void
    {
        $teacher = User::factory()->registered()->create();
        $section = $teacher->sections()->create(['name' => 'Grade 1 - Rosal']);
        $enroll = app(EnrollStudent::class);
        $consented = $enroll->handle($section, 'Ana')['student'];
        $consented->forceFill(['consent_recorded_at' => now()])->save();
        $enroll->handle($section, 'Ben');

        $response = $this->get($this->admin('privacy'))->assertOk();
        $response->assertSee('Parental consent on file')->assertSee('1 of 2 learners')->assertSee('1 missing');
        $response->assertSee('Every admin has TOTP 2FA');
        $checks = collect($response->viewData('checks'))->keyBy(0);
        $this->assertSame('ok', $checks['Every admin has TOTP 2FA'][1]);
        $this->assertSame('ok', $checks['Audit log is append-only'][1]);
        $this->assertSame('ok', $checks['Admin portal path'][1]);
    }

    public function test_research_exports_hold_consented_learners_by_code_only(): void
    {
        $teacher = User::factory()->registered()->create();
        $section = $teacher->sections()->create(['name' => 'Grade 1 - Rosal']);
        $ana = app(EnrollStudent::class)->handle($section, 'Ana')['student'];
        $ben = app(EnrollStudent::class)->handle($section, 'Ben')['student'];
        $ana->forceFill(['consent_recorded_at' => now()])->save();
        foreach ([$ana, $ben] as $student) {
            $this->play($student, [
                ['response', ['skill' => 'phonics', 'level' => 1, 'correct' => true, 'assessment' => 'pre']],
                ['assessment', ['kind' => 'pre', 'scores' => ['phonics' => ['correct' => 1, 'total' => 1]], 'correct' => 1, 'total' => 1]],
                ['response', ['skill' => 'phonics', 'level' => 1, 'correct' => true, 'num_choices' => 3]],
                ['response', ['skill' => 'phonics', 'level' => 1, 'correct' => false, 'num_choices' => 3]],
            ]);
        }

        $csv = $this->get($this->admin('export/students.csv'))->assertOk();
        $this->assertStringStartsWith('text/csv', $csv->headers->get('Content-Type'));
        $rows = array_map('str_getcsv', array_filter(explode("\n", $csv->streamedContent())));
        $header = $rows[0];
        $this->assertCount(2, $rows, 'header + the consented learner only');
        $row = array_combine($header, $rows[1]);
        $this->assertSame($ana->code, $row['student_code']);
        $this->assertSame(['1', '1', '2', '50'], [$row['pre_correct'], $row['pre_total'], $row['responses'], $row['accuracy_pct']]);
        $this->assertSame('1', $row['pre_phonics_correct']);
        $this->assertStringNotContainsString('Ana', $csv->streamedContent());
        $this->assertStringNotContainsString($ben->code, $csv->streamedContent());

        $history = $this->get($this->admin('export/bkt-history.csv'))->assertOk()->streamedContent();
        $lines = array_values(array_filter(explode("\n", $history)));
        $this->assertCount(3, $lines, 'header + 2 gameplay answers (pre-test answers are not BKT)');
        $this->assertStringStartsWith($ana->code.',1,', $lines[1]);

        $audit = AuditLog::where('action', 'export.students')->sole();
        $this->assertSame(1, $audit->details['learners']);
        $this->assertSame(1, AuditLog::where('action', 'export.bkt_history')->count());
    }

    public function test_the_audit_log_cannot_be_rewritten(): void
    {
        $entry = AuditLog::firstOrFail();

        $this->expectException(QueryException::class);
        DB::table('audit_logs')->where('id', $entry->id)->update(['action' => 'nothing.happened']);
    }

    /** Stores events and replays them, as POST /api/sync does. */
    private function play(Student $student, array $events): void
    {
        foreach ($events as $i => [$type, $payload]) {
            DB::table('sync_events')->insert(['uuid' => (string) Str::uuid(), 'student_id' => $student->id, 'type' => $type,
                'payload' => json_encode($payload), 'device_time' => now()->subMinutes(60 - $i)]);
        }
        app(ReplayStudentEvents::class)->handle($student);
    }
}
