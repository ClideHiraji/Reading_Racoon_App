<?php

namespace App\Support;

/**
 * Bayesian Knowledge Tracing update equations (FR-03). Server twin of the
 * client's reading-racoon/scripts/core/bkt.gd; both use 64-bit floats, so the
 * same answers give the same numbers. Source: docs/knowledge/05-bkt-engine.md.
 */
final class Bkt
{
    /** P(L | obs): mastery probability after seeing one answer. */
    public static function posterior(float $p, bool $correct, float $g, float $s): float
    {
        if ($correct) {
            $known = $p * (1.0 - $s);

            return $known / ($known + (1.0 - $p) * $g);
        }
        $slipped = $p * $s;

        return $slipped / ($slipped + (1.0 - $p) * (1.0 - $g));
    }

    /** P(L t+1): the chance of learning the skill from this practice opportunity. */
    public static function transition(float $pPost, float $t): float
    {
        return $pPost + (1.0 - $pPost) * $t;
    }

    /**
     * Guess rate for one item. Choice-style items use 1 / number of choices
     * (D-003 rule 7). Always keeps 1 - S > G.
     */
    public static function guessFor(float $baseG, float $s, int $numChoices): float
    {
        $g = $numChoices >= 2 ? 1.0 / $numChoices : $baseG;

        return min($g, 1.0 - $s - 0.01);
    }
}
