<?php

namespace App\Reports;

use App\Support\SkillCatalog;
use UnexpectedValueException;

/**
 * Checks Gemini's report text against the facts it was given before anyone
 * sees it (FR-05, D-015, docs/knowledge/08-ai-integration.md "Validate output"):
 *
 * - two plain paragraphs, not too short or long, no list or heading formatting;
 * - no learner code other than this learner's;
 * - every number in the text appears in the JSON (or is a BKT threshold), so
 *   the AI can't invent or miscalculate a score;
 * - every sub-skill in needs_support is named.
 *
 * A reply that fails is logged as invalid and retried; the template is the fallback.
 */
final class AiReportCheck
{
    public const MIN_WORDS = 40;

    /**
     * @param  array<string, mixed>  $input  ReportPrompt::input()
     * @return list<string> the two paragraphs, whitespace tidied
     *
     * @throws UnexpectedValueException with the reason, for ai_logs.error
     */
    public static function paragraphs(string $text, array $input, int $maxWords): array
    {
        $text = str_replace(['**', '__'], '', trim($text));
        if (preg_match('/^\s*(#|[-*•]\s|\d+[.)]\s)/mu', $text)) {
            throw new UnexpectedValueException('formatted as a list or heading');
        }

        $paragraphs = array_values(array_filter(
            array_map(fn (string $p) => trim(preg_replace('/\s+/u', ' ', $p)), preg_split('/\R\s*\R/u', $text)),
            fn (string $p) => $p !== ''));
        if (count($paragraphs) !== 2) {
            throw new UnexpectedValueException('expected 2 paragraphs, got '.count($paragraphs));
        }

        $body = implode(' ', $paragraphs);
        $words = preg_match_all('/\S+/u', $body);
        if ($words < self::MIN_WORDS || $words > $maxWords) {
            throw new UnexpectedValueException("{$words} words, expected ".self::MIN_WORDS."-{$maxWords}");
        }

        preg_match_all('/\bRR-[A-Z0-9]+/i', $body, $codes);
        foreach ($codes[0] as $code) {
            if (strtoupper($code) !== $input['learner_code']) {
                throw new UnexpectedValueException("names another learner code ({$code})");
            }
        }

        // The code has digits of its own; take it out before reading numbers.
        $allowed = self::numbers($input);
        preg_match_all('/\d+(?:\.\d+)?/', str_ireplace($input['learner_code'], ' ', $body), $numbers);
        foreach ($numbers[0] as $number) {
            if (! self::isAllowed((float) $number, $allowed)) {
                throw new UnexpectedValueException("number {$number} is not in the facts");
            }
        }

        foreach ($input['needs_support'] as $label) {
            if (! self::mentions($body, $label)) {
                throw new UnexpectedValueException("does not name {$label}, which needs support");
            }
        }

        return $paragraphs;
    }

    /**
     * Every number in the JSON, P(L)-style fractions also as percentages, and
     * the BKT thresholds the prompt explains.
     *
     * @param  array<string, mixed>  $input
     * @return list<float>
     */
    public static function numbers(array $input): array
    {
        $out = [];
        array_walk_recursive($input, function (mixed $value) use (&$out) {
            if (is_int($value) || is_float($value)) {
                $out[] = (float) $value;
                if (is_float($value) && $value >= 0 && $value <= 1) {
                    $out[] = round($value * 100);
                }
            }
        });
        $mastery = (float) config('reading_racoon.bkt.mastery_p');
        $low = (float) config('reading_racoon.bkt.hint_p');
        array_push($out, $mastery, round($mastery * 100), $low, round($low * 100),
            (float) config('reading_racoon.bkt.mastery_min_attempts'), 1.0, (float) SkillCatalog::MAX_LEVEL);

        return array_values(array_unique($out, SORT_REGULAR));
    }

    /**
     * @param  list<float>  $allowed
     */
    private static function isAllowed(float $number, array $allowed): bool
    {
        foreach ($allowed as $value) {
            if (abs($value - $number) < 0.0001) {
                return true;
            }
        }

        return false;
    }

    /** The teacher-facing label ("Reading Fluency") or the plain sub-skill name ("fluency"). */
    private static function mentions(string $body, string $label): bool
    {
        if (stripos($body, $label) !== false) {
            return true;
        }
        foreach (SkillCatalog::skills() as $skill) {
            if (SkillCatalog::label($skill) === $label) {
                return stripos($body, str_replace('_', ' ', $skill)) !== false;
            }
        }

        return false;
    }
}
