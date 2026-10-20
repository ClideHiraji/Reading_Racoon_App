<?php

namespace App\Reports;

use App\Models\AiLog;
use App\Models\Student;
use App\Models\SystemLog;
use App\Support\LlmClient;
use App\Support\LlmException;
use Carbon\CarbonImmutable;
use Illuminate\Support\Sleep;
use UnexpectedValueException;

/**
 * The Gemini teacher report (FR-05, FR-21, D-015): the template's lists with
 * two AI-written paragraphs. Each call is logged in ai_logs; a reply is used
 * only if it passes AiReportCheck. After `attempts` failed calls (or one that
 * can't succeed on retry, such as a bad key) the template's own paragraphs
 * are used and the fallback goes to the system log.
 *
 * Called by App\Jobs\WriteAiReport, never during a page view: a report takes
 * a few seconds and up to three calls.
 */
final class GeminiReportWriter implements DiagnosticReportWriter
{
    public function __construct(
        private readonly LlmClient $llm,
        private readonly TemplateReportWriter $template,
    ) {}

    public function write(array $facts): DiagnosticReport
    {
        $fallback = $this->template->write($facts);
        if (! LlmClient::enabled() || $facts['responses'] === 0) {
            return $fallback;
        }

        $settings = config('reading_racoon.ai_report');
        $input = ReportPrompt::input($facts);
        $messages = ReportPrompt::messages($input, $settings['max_words']);
        $studentId = Student::where('code', $facts['student_code'])->value('id');
        $reason = null;

        for ($attempt = 1; $attempt <= $settings['attempts']; $attempt++) {
            if ($attempt > 1) {
                Sleep::for(2 ** ($attempt - 1))->seconds();
            }

            $started = hrtime(true);
            $reply = null;
            $paragraphs = null;
            $retry = true;
            try {
                $reply = $this->llm->chat($messages, $settings['temperature'], $settings['max_tokens'], $settings['timeout_seconds']);
                [$status, $paragraphs, $reason] = $this->check($reply, $input, (int) ceil($settings['max_words'] * 1.2));
            } catch (LlmException $e) {
                [$status, $reason, $retry] = ['error', $e->getMessage(), $e->retryable()];
            }

            $log = AiLog::create([
                'task' => AiLog::TEACHER_REPORT,
                'prompt_version' => ReportPrompt::VERSION,
                'model' => LlmClient::model(),
                'student_id' => $studentId,
                'input' => $input,
                'output' => $reply['text'] ?? null,
                'status' => $status,
                'error' => $reason === null ? null : mb_substr($reason, 0, 255),
                'latency_ms' => intdiv(hrtime(true) - $started, 1_000_000),
                'prompt_tokens' => $reply['prompt_tokens'] ?? null,
                'completion_tokens' => $reply['completion_tokens'] ?? null,
            ]);

            if ($paragraphs !== null) {
                return $fallback->withParagraphs($paragraphs, LlmClient::model(), CarbonImmutable::now(), $log->id);
            }
            if (! $retry) {
                break;
            }
        }

        SystemLog::record('ai.report_fallback', 'warning', [
            'student' => $facts['student_code'], 'attempts' => min($attempt, $settings['attempts']), 'reason' => $reason,
        ]);

        return $fallback;
    }

    /**
     * @param  array{text: ?string, finish_reason: ?string}  $reply
     * @param  array<string, mixed>  $input
     * @return array{0: string, 1: ?list<string>, 2: ?string} status, paragraphs, reason
     */
    private function check(array $reply, array $input, int $maxWords): array
    {
        if ($reply['text'] === null || trim($reply['text']) === '' || in_array($reply['finish_reason'], ['content_filter', 'safety'], true)) {
            return ['blocked', null, 'empty or blocked reply (finish_reason '.($reply['finish_reason'] ?? 'none').')'];
        }
        if ($reply['finish_reason'] === 'length') {
            return ['invalid', null, 'cut off at max_tokens'];
        }

        try {
            return ['ok', AiReportCheck::paragraphs($reply['text'], $input, $maxWords), null];
        } catch (UnexpectedValueException $e) {
            return ['invalid', null, $e->getMessage()];
        }
    }
}
