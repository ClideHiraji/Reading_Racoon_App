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
     * @param  ?int  $aiLogId  the ai_logs row the paragraphs came from (D-018)
     */
    public function __construct(
        public readonly array $paragraphs,
        public readonly array $strengths,
        public readonly array $needs,
        public readonly array $interventions,
        public readonly string $generatedBy,
        public readonly CarbonImmutable $generatedAt,
        public readonly ?int $aiLogId = null,
    ) {}

    /** The same lists with AI-written paragraphs (D-018). */
    public function withParagraphs(array $paragraphs, string $generatedBy, CarbonImmutable $generatedAt, ?int $aiLogId): self
    {
        return new self($paragraphs, $this->strengths, $this->needs, $this->interventions, $generatedBy, $generatedAt, $aiLogId);
    }
}
