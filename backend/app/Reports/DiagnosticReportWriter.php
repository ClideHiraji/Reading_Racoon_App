<?php

namespace App\Reports;

/**
 * Writes a diagnostic report from App\Reports\StudentFacts.
 *
 * AppServiceProvider picks which writer is used; controllers and views don't change.
 * TemplateReportWriter builds it from the numbers alone. GeminiReportWriter adds AI paragraphs
 * (temperature 0.3, max_tokens 250, facts sent as JSON, see docs/knowledge/08-ai-integration.md),
 * checks them against the facts, logs the call in ai_logs, and falls back to the template on
 * any failure.
 */
interface DiagnosticReportWriter
{
    /**
     * @param  array<string, mixed>  $facts  StudentFacts::build() output (student code, no names)
     */
    public function write(array $facts): DiagnosticReport;
}
