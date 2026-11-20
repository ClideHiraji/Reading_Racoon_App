<?php

namespace App\Support;

/**
 * Geometry for the learner page's small multiples (FR-06, D-037): one SVG line
 * per sub-skill of P(L) after each of its answers, with the level changes
 * and the 0.95 mastery line. Drawn on the server, so it needs no script, no
 * CDN and works offline and in print; the skill-level table is its twin.
 */
final class SkillHistory
{
    public const WIDTH = 320;

    public const HEIGHT = 104;

    private const LEFT = 4;

    private const RIGHT = 40;

    private const TOP = 16;

    private const BOTTOM = 6;

    /**
     * @param  list<array{skill: string, level: int, p: float}>  $history  replay history, oldest first
     * @return array<string, array{n: int, line: string, area: string, goal: float, end: array{x: float, y: float, p: int}, first: int, levels: list<array{x: float, level: int}>}>
     */
    public static function build(array $history): array
    {
        $bySkill = [];
        foreach ($history as $h) {
            $bySkill[$h['skill']][] = ['p' => (float) $h['p'], 'level' => (int) $h['level']];
        }

        $out = [];
        foreach ($bySkill as $skill => $points) {
            $out[$skill] = self::chart($points);
        }

        return $out;
    }

    /** @param  list<array{p: float, level: int}>  $points */
    private static function chart(array $points): array
    {
        $n = count($points);
        $plotW = self::WIDTH - self::LEFT - self::RIGHT;
        $plotH = self::HEIGHT - self::TOP - self::BOTTOM;
        $x = fn (int $i) => round(self::LEFT + ($n === 1 ? $plotW / 2 : $plotW * $i / ($n - 1)), 1);
        $y = fn (float $p) => round(self::TOP + (1 - max(0, min(1, $p))) * $plotH, 1);

        $line = '';
        $levels = [];
        $previous = null;
        foreach ($points as $i => $point) {
            $line .= ($i === 0 ? 'M' : ' L').$x($i).' '.$y($point['p']);
            if ($point['level'] !== $previous) {
                // The new level starts halfway between its first answer and the one before.
                $levels[] = ['x' => $i === 0 ? $x(0) : round(($x($i - 1) + $x($i)) / 2, 1), 'level' => $point['level']];
                $previous = $point['level'];
            }
        }
        $base = self::TOP + $plotH;
        $area = $line.' L'.$x($n - 1).' '.$base.' L'.$x(0).' '.$base.' Z';
        $last = $points[$n - 1];

        return [
            'n' => $n,
            'line' => $line,
            'area' => $area,
            'goal' => $y((float) config('reading_racoon.bkt.mastery_p', 0.95)),
            'end' => ['x' => $x($n - 1), 'y' => $y($last['p']), 'p' => (int) round(100 * $last['p'])],
            'first' => (int) round(100 * $points[0]['p']),
            'levels' => $levels,
        ];
    }
}
