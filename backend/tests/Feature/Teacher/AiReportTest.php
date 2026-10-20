<?php

namespace Tests\Feature\Teacher;

use App\Actions\EnrollStudent;
use App\Actions\ReplayStudentEvents;
use App\Jobs\WriteAiReport;
use App\Models\AiLog;
use App\Models\AiReport;
use App\Models\Section;
use App\Models\Student;
use App\Models\SystemLog;
use App\Models\User;
use App\Reports\ReportPrompt;
use App\Reports\StudentFacts;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Sleep;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * The Gemini teacher report (FR-05, FR-21, D-015): only checked replies are
 * shown, every call is logged, failures fall back to the template, and only
 * learners with parental consent are ever sent. Gemini is faked throughout.
 */
class AiReportTest extends TestCase
{
    use RefreshDatabase;

    private const MODEL = 'gemini-test-flash';

    private User $teacher;

    private Section $section;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        config(['services.llm' => [
            'base_url' => 'https://llm.test/v1beta/openai/', 'key' => 'test-key', 'model' => self::MODEL, 'reasoning_effort' => null,
        ]]);
        Http::preventStrayRequests();
        Sleep::fake();

        $this->teacher = User::factory()->registered()->create(['name' => 'Maria Santos']);
        $this->section = $this->teacher->sections()->create(['name' => 'Grade 1 - Sampaguita']);
        $this->actingAs($this->teacher);
        $this->student = $this->enroll('Ana', consent: true);
    }

    private function enroll(string $name, bool $consent): Student
    {
        $student = app(EnrollStudent::class)->handle($this->section, $name)['student'];
        if ($consent) {
            $student->forceFill(['consent_recorded_at' => now(), 'consent_recorded_by' => $this->teacher->id])->save();
        }

        return $student;
    }

    /** Phonological Awareness L1 mastered, Phonics L1 needs support. Stored and replayed as a sync does. */
    private function play(?Student $student = null, int $wrongPhonics = 6): void
    {
        $student ??= $this->student;
        $events = [
            ...array_fill(0, 5, ['response', ['skill' => 'phonological_awareness', 'level' => 1, 'correct' => true, 'num_choices' => 3]]),
            ...array_fill(0, $wrongPhonics, ['response', ['skill' => 'phonics', 'level' => 1, 'correct' => false, 'num_choices' => 3]]),
            ['lesson_end', ['level' => 1, 'node' => 0, 'correct' => 5, 'total' => 5 + $wrongPhonics]],
        ];
        foreach ($events as $i => [$type, $payload]) {
            DB::table('sync_events')->insert(['uuid' => (string) Str::uuid(), 'student_id' => $student->id, 'type' => $type,
                'payload' => json_encode($payload), 'device_time' => now()->subMinutes(60 - $i)]);
        }
        app(ReplayStudentEvents::class)->handle($student);
    }

    /** @return array<string, mixed> the JSON the prompt carries */
    private function input(): array
    {
        return ReportPrompt::input(StudentFacts::build($this->student->fresh(), app(ReplayStudentEvents::class)->replay($this->student)));
    }

    /** A reply that passes every check: numbers from the JSON, Phonics named. */
    private function validText(): string
    {
        $in = $this->input();

        return "The learner {$in['learner_code']} is on map level {$in['map_level']}, in the {$in['aral_band']} band. "
            ."Across their first lesson they gave {$in['answers']} answers, {$in['accuracy_percent']}% of them correct, "
            ."and mastered {$in['skill_levels_mastered']} of {$in['skill_levels_total']} skill-levels. "
            .'Phonological Awareness is a clear strength: the learner mastered it at level 1 and handled the sound tasks well.'
            ."\n\n"
            .'Phonics needs support, because the learner is still at level 1 and most recent answers were wrong. '
            .'Practise letter sounds every day with picture cards, then build simple words with letter tiles from word families '
            .'and let the learner read them aloud in a small group. Praise each correct sound to keep the learner motivated.';
    }

    private function reply(?string $text, string $finish = 'stop')
    {
        return Http::response([
            'choices' => [['index' => 0, 'message' => ['role' => 'assistant', 'content' => $text], 'finish_reason' => $finish]],
            'usage' => ['prompt_tokens' => 900, 'completion_tokens' => 140, 'total_tokens' => 1040],
        ]);
    }

    private function writeNow(): ?AiReport
    {
        return app()->call([new WriteAiReport($this->student->id), 'handle']);
    }

    public function test_a_checked_reply_is_stored_logged_and_shown_with_the_template_lists(): void
    {
        $this->play();
        $text = $this->validText();
        Http::fake(['llm.test/*' => $this->reply($text)]);

        $report = $this->writeNow();
        $this->assertSame(self::MODEL, $report->generated_by);
        $this->assertCount(2, $report->paragraphs);
        $this->assertStringStartsWith("The learner {$this->student->code} is on map level", $report->paragraphs[0]);

        $log = AiLog::sole();
        $this->assertSame(['teacher_report', 'ok', self::MODEL, ReportPrompt::VERSION, $this->student->id, 900, 140],
            [$log->task, $log->status, $log->model, $log->prompt_version, $log->student_id, $log->prompt_tokens, $log->completion_tokens]);
        $this->assertSame($this->student->code, $log->input['learner_code']);
        $this->assertSame(['Phonics'], $log->input['needs_support']);
        $this->assertSame($text, $log->output);
        $this->assertSame($log->id, $report->ai_log_id);

        Http::assertSent(function (Request $request) {
            $user = $request['messages'][1]['content'];

            return $request->url() === 'https://llm.test/v1beta/openai/chat/completions'
                && $request->hasHeader('Authorization', 'Bearer test-key')
                && $request['model'] === self::MODEL && $request['temperature'] === 0.3
                && str_contains($user, $this->student->code)
                // RA 10173: no names and no dates leave the server.
                && ! str_contains($user, 'Ana') && ! str_contains($user, 'Maria') && ! str_contains($user, now()->format('Y-'));
        });

        Queue::fake();
        $page = $this->get(route('teacher.students.report', $this->student))->assertOk();
        $page->assertSee('Praise each correct sound')->assertSee('word families')->assertSee('written by AI ('.self::MODEL.')');
        $this->assertSame(self::MODEL, $page->viewData('report')->generatedBy);
        $this->assertStringStartsWith('%PDF', $this->get(route('teacher.students.report.pdf', $this->student))->getContent());
        Queue::assertNothingPushed();

        // Same numbers: nothing is sent again.
        $this->writeNow();
        Http::assertSentCount(1);
    }

    /**
     * @return array<string, array{0: string, 1: string, 2: string, 3: string}> how to spoil a valid reply, finish reason, status, logged reason
     */
    public static function badReplies(): array
    {
        return [
            'one paragraph' => ['join', 'stop', 'invalid', 'expected 2 paragraphs, got 1'],
            'three paragraphs' => ['extra', 'stop', 'invalid', 'expected 2 paragraphs, got 3'],
            'a number not in the facts' => ['number', 'stop', 'invalid', 'number 73 is not in the facts'],
            "another learner's code" => ['code', 'stop', 'invalid', 'names another learner code (RR-ZZZZZZ)'],
            'the needs-support skill is not named' => ['skill', 'stop', 'invalid', 'does not name Phonics, which needs support'],
            'a bulleted list' => ['list', 'stop', 'invalid', 'formatted as a list or heading'],
            'cut off at max_tokens' => ['none', 'length', 'invalid', 'cut off at max_tokens'],
            'blocked by the safety filter' => ['empty', 'content_filter', 'blocked', 'empty or blocked reply (finish_reason content_filter)'],
        ];
    }

    #[DataProvider('badReplies')]
    public function test_replies_that_fail_the_checks_fall_back_to_the_template(string $spoil, string $finish, string $status, string $reason): void
    {
        $this->play();
        [$first, $second] = explode("\n\n", $this->validText());
        $text = match ($spoil) {
            'join' => "{$first} {$second}",
            'extra' => "{$first}\n\n{$second}\n\nThank you.",
            'number' => "{$first}\n\n{$second} Aim for 73% next week.",
            'code' => "{$first} Unlike RR-ZZZZZZ, they keep trying.\n\n{$second}",
            'skill' => $first."\n\n".str_replace('Phonics', 'Letter work', $second),
            'list' => "{$first}\n\n- {$second}",
            'none' => "{$first}\n\n{$second}",
            'empty' => null,
        };
        Http::fake(['llm.test/*' => $this->reply($text, $finish)]);

        $report = $this->writeNow();
        $this->assertNull($report->paragraphs);
        $this->assertSame('template', $report->generated_by);

        Http::assertSentCount(3);
        $logs = AiLog::orderBy('id')->get();
        $this->assertSame([$status, $status, $status], $logs->pluck('status')->all());
        $this->assertSame($reason, $logs[0]->error);
        $this->assertSame(1, SystemLog::where('event', 'ai.report_fallback')->count());
        Sleep::assertSleptTimes(2);

        Queue::fake();
        $page = $this->get(route('teacher.students.report', $this->student))->assertOk();
        $page->assertSee("Learner {$this->student->code} is on Map Level 1", false)->assertSee('written by the built-in template');
        $this->assertSame('template', $page->viewData('report')->generatedBy);
        // These numbers already had their attempt: the page doesn't queue another.
        Queue::assertNothingPushed();
    }

    public function test_timeouts_and_server_errors_are_retried(): void
    {
        $this->play();
        Http::fake(['llm.test/*' => Http::sequence()
            ->push(['error' => ['message' => 'The model is overloaded.']], 503)
            ->pushFailedConnection('cURL error 28: Operation timed out')
            ->pushResponse($this->reply($this->validText()))]);

        $this->assertSame(self::MODEL, $this->writeNow()->generated_by);

        $logs = AiLog::orderBy('id')->get();
        $this->assertSame(['error', 'error', 'ok'], $logs->pluck('status')->all());
        $this->assertSame('HTTP 503 The model is overloaded.', $logs[0]->error);
        $this->assertStringContainsString('connection', $logs[1]->error);
        Sleep::assertSleptTimes(2);
        $this->assertSame(0, SystemLog::where('event', 'ai.report_fallback')->count());
    }

    public function test_three_failed_calls_fall_back_to_the_template(): void
    {
        $this->play();
        Http::fake(['llm.test/*' => Http::response(['error' => ['message' => 'Internal error']], 500)]);

        $this->assertNull($this->writeNow()->paragraphs);
        Http::assertSentCount(3);
        $this->assertSame(3, AiLog::where('status', 'error')->count());
        $this->assertSame('HTTP 500 Internal error', SystemLog::where('event', 'ai.report_fallback')->sole()->context['reason']);
    }

    public function test_a_bad_key_is_not_retried(): void
    {
        $this->play();
        Http::fake(['llm.test/*' => Http::response([['error' => ['code' => 401, 'message' => 'API key not valid.']]], 401)]);

        $this->assertNull($this->writeNow()->paragraphs);
        Http::assertSentCount(1);
        $this->assertSame('HTTP 401 API key not valid.', AiLog::sole()->error);
        Sleep::assertNeverSlept();
    }

    public function test_without_llm_settings_the_template_is_used_and_nothing_is_sent(): void
    {
        config(['services.llm.key' => null]);
        Http::fake();
        Queue::fake();
        $this->play();

        $this->assertNull($this->writeNow());
        $page = $this->get(route('teacher.students.report', $this->student))->assertOk();
        $this->assertSame('template', $page->viewData('report')->generatedBy);

        Http::assertNothingSent();
        Queue::assertNothingPushed();
        $this->assertSame(0, AiLog::count());
        $this->artisan('report:write', ['code' => [$this->student->code]])
            ->expectsOutputToContain('The AI is off')->assertFailed();
    }

    public function test_learners_without_consent_are_never_sent(): void
    {
        Http::fake();
        Queue::fake();
        $this->student->forceFill(['consent_recorded_at' => null])->save();
        $this->play();

        $this->assertNull($this->writeNow());
        $this->get(route('teacher.students.report', $this->student))->assertOk();
        Sanctum::actingAs($this->student->user);
        $this->postJson('/api/sync', ['events' => [$this->syncEvent()]])->assertOk();
        $this->artisan('report:write', ['code' => [$this->student->code]])
            ->expectsOutputToContain('no parental consent on file')->assertSuccessful();

        Http::assertNothingSent();
        Queue::assertNothingPushed();
        $this->assertSame(0, AiLog::count());
    }

    private function syncEvent(): array
    {
        return ['id' => (string) Str::uuid(), 'type' => 'response', 'device_time' => now()->subMinute()->utc()->format('Y-m-d\TH:i:s\Z'),
            'payload' => ['item_id' => 'x', 'skill' => 'phonics', 'level' => 1, 'answer' => 'a', 'correct' => true,
                'response_ms' => 900, 'rescue' => false, 'num_choices' => 3]];
    }

    public function test_a_sync_queues_one_delayed_report(): void
    {
        Queue::fake();
        Sanctum::actingAs($this->student->user);
        $event = $this->syncEvent();

        $this->postJson('/api/sync', ['events' => [$event]])->assertOk();
        Queue::assertPushed(WriteAiReport::class, fn (WriteAiReport $job) => $job->studentId === $this->student->id
            && $job->delay !== null && now()->addMinutes(9)->lessThan($job->delay));

        // The same event again stores nothing new, so nothing more is queued.
        $this->postJson('/api/sync', ['events' => [$event]])->assertOk();
        Queue::assertPushed(WriteAiReport::class, 1);
    }

    public function test_opening_a_report_without_an_ai_version_queues_one(): void
    {
        $this->play();
        Queue::fake();

        $page = $this->get(route('teacher.students.report', $this->student))->assertOk();
        $this->assertSame('template', $page->viewData('report')->generatedBy);
        Queue::assertPushed(WriteAiReport::class, fn (WriteAiReport $job) => $job->studentId === $this->student->id && $job->delay === null);
    }

    public function test_new_numbers_make_the_stored_report_stale(): void
    {
        $this->play();
        Http::fake(['llm.test/*' => $this->reply($this->validText())]);
        $this->writeNow();

        $this->play(wrongPhonics: 1);
        Queue::fake();
        $page = $this->get(route('teacher.students.report', $this->student))->assertOk();
        $this->assertSame('template', $page->viewData('report')->generatedBy);
        Queue::assertPushed(WriteAiReport::class);
    }

    public function test_removing_a_learner_deletes_their_ai_rows(): void
    {
        $this->play();
        Http::fake(['llm.test/*' => $this->reply($this->validText())]);
        $this->writeNow();
        $this->assertSame([1, 1], [AiLog::count(), AiReport::count()]);

        $this->delete(route('teacher.students.destroy', $this->student))->assertRedirect();
        $this->assertSame([0, 0], [AiLog::count(), AiReport::count()]);
    }

    public function test_report_write_checks_the_settings_without_playing_again(): void
    {
        $this->play();
        Http::fake(['llm.test/*' => $this->reply($this->validText())]);

        $this->artisan('report:write', ['code' => [strtolower($this->student->code)]])
            ->expectsOutputToContain("{$this->student->code}: written by ".self::MODEL)
            ->expectsOutputToContain('Praise each correct sound')
            ->assertSuccessful();
        $this->artisan('report:write', ['code' => [$this->student->code], '--force' => true])->assertSuccessful();
        Http::assertSentCount(2);
        $this->assertSame(1, AiReport::count());

        $this->artisan('report:write', ['code' => ['RR-NOPE00']])->expectsOutputToContain('no such learner')->assertFailed();
    }
}
