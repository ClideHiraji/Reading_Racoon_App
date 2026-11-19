<?php

namespace App\Jobs;

use App\Actions\ReplayStudentEvents;
use App\Models\AiReport;
use App\Models\Student;
use App\Reports\GeminiReportWriter;
use App\Reports\ReportPrompt;
use App\Reports\StudentFacts;
use App\Support\LlmClient;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * Writes the Gemini teacher report for one learner (FR-05, FR-21, D-018).
 * Queued delay_minutes after a sync (syncs meanwhile don't queue another, so
 * one play session gives one report), or when a teacher opens a report that
 * has no AI version for the current numbers. Facts that already have a
 * stored report are skipped, so a re-run costs nothing.
 */
final class WriteAiReport implements ShouldBeUnique, ShouldQueue
{
    use Queueable;

    /** GeminiReportWriter retries the LLM call itself; each attempt is logged. */
    public int $tries = 1;

    public int $timeout = 150;

    /** A lock left by a lost job expires after an hour. */
    public int $uniqueFor = 3600;

    public function __construct(public readonly int $studentId, public readonly bool $force = false) {}

    public function uniqueId(): string
    {
        return (string) $this->studentId;
    }

    /** AI is configured and the learner's parental consent is on file (RA 10173). */
    public static function eligible(Student $student): bool
    {
        return LlmClient::enabled() && $student->consent_recorded_at !== null;
    }

    public static function queueFor(Student $student, bool $afterSync = false): void
    {
        if (! self::eligible($student)) {
            return;
        }
        $pending = self::dispatch($student->id);
        if ($afterSync) {
            $pending->delay(now()->addMinutes(config('reading_racoon.ai_report.delay_minutes')));
        }
    }

    /** @return ?AiReport the report for the current numbers, or null when there is nothing to write */
    public function handle(ReplayStudentEvents $replayer, GeminiReportWriter $writer): ?AiReport
    {
        $student = Student::find($this->studentId);
        if ($student === null || ! self::eligible($student)) {
            return null;
        }
        $facts = StudentFacts::build($student, $replayer->replay($student));
        if ($facts['responses'] === 0) {
            return null;
        }

        $hash = ReportPrompt::hash(ReportPrompt::input($facts));
        $existing = AiReport::where('student_id', $student->id)->where('facts_hash', $hash)->first();
        if ($existing !== null && ! $this->force) {
            return $existing;
        }

        $report = $writer->write($facts);
        $ai = $report->generatedBy !== 'template';

        return AiReport::updateOrCreate(['student_id' => $student->id, 'facts_hash' => $hash], [
            'paragraphs' => $ai ? $report->paragraphs : null,
            'generated_by' => $report->generatedBy,
            'prompt_version' => ReportPrompt::VERSION,
            'ai_log_id' => $report->aiLogId,
            'generated_at' => $report->generatedAt,
        ]);
    }
}
