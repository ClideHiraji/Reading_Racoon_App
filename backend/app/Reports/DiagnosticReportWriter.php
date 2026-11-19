<?php

namespace App\Reports;

/**
 * Writes a diagnostic report from App\Reports\StudentFacts (FR-05, FR-18).
 *
 * THE LLM SEAM (D-012): today the container binds TemplateReportWriter. The
 * Gemini slice adds a GeminiReportWriter (prompt: temperature 0.3,
 * max_tokens 250, facts injected as JSON, docs/knowledge/08-ai-integration.md)
 * that validates the output against the facts, logs the call in ai_logs
 * (FR-21) and falls back to TemplateReportWriter on any failure. Swap the
 * binding in AppServiceProvider; controllers and views don't change.
 */
interface DiagnosticReportWriter
{
    /**
     * @param  array<string, mixed>  $facts  StudentFacts::build() output (student code, no names)
     */
    public function write(array $facts): DiagnosticReport;
}
