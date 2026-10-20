<?php

namespace App\Console\Commands;

use App\Jobs\WriteAiReport;
use App\Models\Student;
use App\Support\LlmClient;
use Illuminate\Console\Command;

/**
 * Writes the Gemini teacher report now, without the queue (D-015): to check
 * the LLM settings in .env, or to produce reports for the teachers' rating
 * (MLDLC Stage 4). Each call is in ai_logs like any other.
 */
class WriteReport extends Command
{
    protected $signature = 'report:write
        {code* : Student codes, e.g. RR-7K2M9Q}
        {--force : Write again even if a report exists for the current numbers}';

    protected $description = 'Write the AI teacher report for learners now';

    public function handle(): int
    {
        if (! LlmClient::enabled()) {
            $this->error('The AI is off: set LLM_BASE_URL, LLM_API_KEY and LLM_MODEL in .env.');

            return self::FAILURE;
        }

        $ok = true;
        foreach ($this->argument('code') as $code) {
            $code = strtoupper(trim($code));
            $student = Student::firstWhere('code', $code);
            if ($student === null) {
                $this->error("{$code}: no such learner.");
                $ok = false;

                continue;
            }
            if (! WriteAiReport::eligible($student)) {
                $this->warn("{$code}: no parental consent on file, so nothing is sent to the AI.");

                continue;
            }

            $report = app()->call([new WriteAiReport($student->id, (bool) $this->option('force')), 'handle']);
            if ($report === null) {
                $this->warn("{$code}: no gameplay synced yet.");
            } elseif ($report->paragraphs === null) {
                $this->warn("{$code}: the AI replies failed their checks, so the template is shown. See AI calls in the admin logs.");
                $ok = false;
            } else {
                $this->info("{$code}: written by {$report->generated_by} ({$report->generated_at->toIso8601ZuluString()}).");
                $this->line(implode(PHP_EOL.PHP_EOL, $report->paragraphs));
            }
        }

        return $ok ? self::SUCCESS : self::FAILURE;
    }
}
