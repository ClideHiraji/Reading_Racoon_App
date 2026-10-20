<?php

namespace App\Reports;

use App\Jobs\WriteAiReport;
use App\Models\AiReport;
use App\Models\Student;

/**
 * What the teacher's report page and PDF use (FR-05, FR-18, D-015): the
 * template's lists with the stored Gemini paragraphs written for exactly
 * these numbers. Without one, the template's own paragraphs are shown and an
 * AI version is queued (if AI is on and consent is on file), so a reload a
 * little later shows it. Never calls the LLM itself, so the page stays fast.
 */
final class StoredReportWriter implements DiagnosticReportWriter
{
    public function __construct(private readonly TemplateReportWriter $template) {}

    public function write(array $facts): DiagnosticReport
    {
        $report = $this->template->write($facts);
        $student = Student::firstWhere('code', $facts['student_code']);
        if ($student === null || $facts['responses'] === 0) {
            return $report;
        }

        $stored = AiReport::where('student_id', $student->id)
            ->where('facts_hash', ReportPrompt::hash(ReportPrompt::input($facts)))
            ->first();
        if ($stored === null) {
            WriteAiReport::queueFor($student);

            return $report;
        }

        // Null paragraphs: the AI failed on these numbers, so the template stays until they change.
        return $stored->paragraphs === null ? $report
            : $report->withParagraphs($stored->paragraphs, $stored->generated_by, $stored->generated_at, $stored->ai_log_id);
    }
}
