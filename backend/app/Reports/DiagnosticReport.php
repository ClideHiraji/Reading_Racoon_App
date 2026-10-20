<?php

namespace App\Reports;

use Carbon\CarbonImmutable;

/**
 * A plain-language diagnostic summary for the teacher (FR-05, FR-18):
 * two paragraphs plus strengths, needs and suggested interventions.
 */
final class DiagnosticReport
{
    /**
     * @param  list<string>  $paragraphs
     * @param  list<string>  $strengths
     * @param  list<string>  $needs
     * @param  list<string>  $interventions
     * @param  string  $generatedBy  "template" or the LLM model id
     */
    public function __construct(
        public readonly array $paragraphs,
        public readonly array $strengths,
        public readonly array $needs,
        public readonly array $interventions,
        public readonly string $generatedBy,
        public readonly CarbonImmutable $generatedAt,
    ) {}
}
