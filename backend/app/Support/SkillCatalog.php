<?php

namespace App\Support;

/**
 * The five MATATAG sub-skills (FR-09), their level ranges and BKT parameters,
 * read from config/reading_racoon.php. Server twin of the client's
 * reading-racoon/scripts/core/skill_catalog.gd.
 */
final class SkillCatalog
{
    /**
     * @return list<string>
     */
    public static function skills(): array
    {
        return array_keys(config('reading_racoon.bkt.skills'));
    }

    /**
     * @return array{levels: array{0: int, 1: int}, l0: float, t: float, g: float, s: float}
     */
    public static function params(string $skill): array
    {
        return config("reading_racoon.bkt.skills.$skill");
    }

    /**
     * Every (sub-skill, level) pair a student has a BKT state for: 14 (D-003).
     *
     * @return list<array{skill: string, level: int}>
     */
    public static function states(): array
    {
        $out = [];
        foreach (self::skills() as $skill) {
            [$min, $max] = self::params($skill)['levels'];
            foreach (range($min, $max) as $level) {
                $out[] = ['skill' => $skill, 'level' => $level];
            }
        }

        return $out;
    }
}
