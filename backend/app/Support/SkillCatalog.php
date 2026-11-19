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

    public const MAX_LEVEL = 5;

    public static function isSkill(mixed $skill): bool
    {
        return is_string($skill) && config("reading_racoon.bkt.skills.$skill") !== null;
    }

    public static function minLevel(string $skill): int
    {
        return self::params($skill)['levels'][0];
    }

    public static function maxLevel(string $skill): int
    {
        return self::params($skill)['levels'][1];
    }

    /** The sub-skill has a BKT state (and tasks) at this map level. */
    public static function isActive(string $skill, int $level): bool
    {
        return $level >= self::minLevel($skill) && $level <= self::maxLevel($skill);
    }

    /**
     * Sub-skills with tasks at map level $level.
     *
     * @return list<string>
     */
    public static function activeSkills(int $level): array
    {
        return array_values(array_filter(self::skills(), fn (string $skill) => self::isActive($skill, $level)));
    }

    /** Teacher-facing name, e.g. "Reading Fluency". */
    public static function label(string $skill): string
    {
        return config("reading_racoon.skill_labels.$skill", $skill);
    }

    /**
     * World name, level name and ARAL band of a map level (D-003, D-009).
     *
     * @return array{world: string, name: string, band: string}
     */
    public static function level(int $level): array
    {
        return config('reading_racoon.levels.'.max(1, min(self::MAX_LEVEL, $level)));
    }
}
