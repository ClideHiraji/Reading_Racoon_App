<?php

namespace App\Reports;

use Carbon\CarbonImmutable;

/**
 * Diagnostic summary built only from the numbers (FR-05, FR-18). It is the
 * report until the Gemini slice lands, and stays as the fallback when the LLM
 * fails or its output doesn't validate (docs/knowledge/08-ai-integration.md).
 * Every sentence quotes the facts, so it can't invent anything.
 */
final class TemplateReportWriter implements DiagnosticReportWriter
{
    /** Classroom follow-up per sub-skill (MATATAG competency areas, FR-09). */
    public const INTERVENTIONS = [
        'phonological_awareness' => 'Sound games in a small group: clap the syllables of names, find rhyming pairs, say the first sound of picture words.',
        'phonics' => 'Daily letter-sound practice with picture cards; build simple words with letter tiles using word families (-at, -ock).',
        'vocabulary' => 'Picture-word matching and sight-word cards; have the learner use each new word in a short spoken sentence.',
        'fluency' => 'Echo and paired reading of short sentences; reread the same text two or three times to build speed and accuracy.',
        'literal_comprehension' => 'Read a short story aloud, ask who/what/where/when questions, then have the learner retell it with picture cards in order.',
    ];

    public function write(array $facts): DiagnosticReport
    {
        $strengths = [];
        $needs = [];
        $interventions = [];
        $labels = ['strengths' => [], 'needs' => []];
        $flagged = array_filter(array_column($facts['open_flags'], 'sub_skill'));

        foreach ($facts['skills'] as $skill => $s) {
            if (! $s['unlocked']) {
                continue;
            }
            $mastered = $s['mastered_levels'] === [] ? '' : ' (mastered at level '.implode(', ', $s['mastered_levels']).')';
            $recent = $s['recent_accuracy'] === null ? '' : ", {$s['recent_accuracy']}% of the last {$s['recent_answers']} answers correct";

            $isStrong = $s['mastered_levels'] !== [] || ($s['p'] !== null && $s['p'] >= 0.7 && ($s['recent_accuracy'] ?? 0) >= 80);
            $isNeed = $s['review']
                || in_array($skill, $flagged, true)
                || ($s['p'] !== null && $s['p'] < 0.3 && $s['attempts'] >= 5)
                || ($s['recent_accuracy'] !== null && $s['recent_accuracy'] < 60 && $s['recent_answers'] >= 5);

            if ($isNeed) {
                $why = $s['review'] ? 'reviewing a lower level after Heart Recovery' : 'P(L) '.$this->pct($s['p'])." at level {$s['current_level']}";
                $needs[] = "{$s['label']}: {$why}{$recent}.";
                $labels['needs'][] = $s['label'];
                $interventions[] = "{$s['label']}: ".self::INTERVENTIONS[$skill];
            } elseif ($isStrong) {
                $strengths[] = "{$s['label']}{$mastered}{$recent}.";
                $labels['strengths'][] = $s['label'];
            }
        }

        return new DiagnosticReport(
            paragraphs: [$this->overview($facts), $this->guidance($facts, $labels['strengths'], $labels['needs'])],
            strengths: $strengths,
            needs: $needs,
            interventions: $interventions,
            generatedBy: 'template',
            generatedAt: CarbonImmutable::now(),
        );
    }

    /**
     * @param  array<string, mixed>  $facts
     */
    private function overview(array $facts): string
    {
        $where = "Learner {$facts['student_code']} is on Map Level {$facts['highest_level']} ({$facts['world']}, {$facts['level_name']}), which is the {$facts['aral_band']} band.";
        if ($facts['responses'] === 0) {
            return $where.' No gameplay has been synced yet, so there is nothing to analyse. Let the learner play while the tablet is online so the answers can sync.';
        }

        $mastered = [];
        $total = 0;
        foreach ($facts['skills'] as $s) {
            $total += count($s['levels']);
            foreach ($s['mastered_levels'] as $level) {
                $mastered[] = "{$s['label']} L{$level}";
            }
        }
        $stars = $facts['average_stars'] === null ? '' : " (average {$facts['average_stars']} stars)";
        $text = "{$where} Across {$facts['lessons']} lessons{$stars} they gave {$facts['responses']} answers, {$facts['accuracy']}% of them correct. "
            .($mastered === [] ? 'No skill-level is mastered yet.' : 'Mastered '.count($mastered)." of {$total} skill-levels: ".implode(', ', $mastered).'.');

        foreach (['pre_test' => 'Pre-test', 'post_test' => 'Post-test'] as $key => $label) {
            if ($facts[$key] !== []) {
                $correct = array_sum(array_column($facts[$key], 'correct'));
                $items = array_sum(array_column($facts[$key], 'total'));
                $text .= " {$label}: {$correct}/{$items} correct.";
            }
        }

        return $text;
    }

    /**
     * @param  array<string, mixed>  $facts
     * @param  list<string>  $strengths  sub-skill labels
     * @param  list<string>  $needs  sub-skill labels
     */
    private function guidance(array $facts, array $strengths, array $needs): string
    {
        $parts = [];
        if ($strengths !== []) {
            $parts[] = 'Strengths: '.implode(', ', $strengths).'.';
        }
        if ($needs !== []) {
            $parts[] = 'Needs support in '.implode(', ', $needs).'; see the suggested activities below.';
        } elseif ($facts['responses'] > 0) {
            $parts[] = 'No sub-skill needs intervention right now; keep the learner practising at the current level.';
        }
        if ($facts['rescues']['partial'] > 0) {
            $parts[] = "Heart Recovery was not completed {$facts['rescues']['partial']} time(s), which moved a skill back one level for review.";
        }
        $parts[] = 'This summary is built from the game\'s numbers and supports, not replaces, your own judgement.';

        return implode(' ', $parts);
    }

    private function pct(?float $p): string
    {
        return $p === null ? 'n/a' : round($p * 100).'%';
    }
}
