<?php

namespace App\Reports;

use App\Models\Student;
use App\Support\SectionStats;
use App\Support\SkillCatalog;
use App\Support\StudentReplay;

/**
 * The numbers a diagnostic report is written from (FR-05, FR-18). Identified by
 * the student code only, never the name: this is the JSON block a Gemini
 * prompt will inject (docs/knowledge/08-ai-integration.md, RA 10173).
 */
final class StudentFacts
{
    /** Answers per sub-skill that count as "recent" for accuracy. */
    public const RECENT = 10;

    /**
     * @return array{
     *     student_code: string, highest_level: int, level_name: string, world: string, aral_band: string,
     *     responses: int, accuracy: ?int, lessons: int, average_stars: ?float,
     *     skills: array<string, array{label: string, unlocked: bool, current_level: ?int, p: ?float, attempts: int,
     *         mastered_levels: list<int>, levels: list<int>, review: bool, recent_accuracy: ?int, recent_answers: int}>,
     *     rescues: array{total: int, partial: int}, open_flags: list<array{type: string, sub_skill: ?string, level: ?int}>,
     *     pre_test: array<string, array{correct: int, total: int}>, post_test: array<string, array{correct: int, total: int}>,
     *     first_activity: ?string, last_activity: ?string
     * }
     */
    public static function build(Student $student, StudentReplay $replay): array
    {
        $student->loadMissing(['bktStates', 'pathProgress', 'interventionFlags']);
        $highest = SectionStats::highest($student);
        $level = SkillCatalog::level($highest);

        $skills = [];
        foreach (SkillCatalog::skills() as $skill) {
            $current = SectionStats::currentState($student, $skill);
            $states = $student->bktStates->where('sub_skill', $skill)->sortBy('level');
            $recent = array_slice(array_values(array_filter($replay->history,
                fn (array $h) => $h['skill'] === $skill && $h['assessment'] === null)), -self::RECENT);
            $skills[$skill] = [
                'label' => SkillCatalog::label($skill),
                'unlocked' => $current !== null,
                'current_level' => $current?->level,
                'p' => $current === null ? null : round($current->p_mastery, 2),
                'attempts' => $current?->attempts ?? 0,
                'mastered_levels' => $states->whereNotNull('mastered_at')->pluck('level')->values()->all(),
                'levels' => range(SkillCatalog::minLevel($skill), SkillCatalog::maxLevel($skill)),
                'review' => $states->contains('review', true),
                'recent_accuracy' => $recent === [] ? null
                    : (int) round(100 * count(array_filter($recent, fn (array $h) => $h['correct'])) / count($recent)),
                'recent_answers' => count($recent),
            ];
        }

        $first = $replay->history[0]['time'] ?? $replay->lessons[0]['time'] ?? null;

        return [
            'student_code' => $student->code,
            'highest_level' => $highest,
            'level_name' => $level['name'],
            'world' => $level['world'],
            'aral_band' => $level['band'],
            'responses' => $replay->responses,
            'accuracy' => $replay->responses > 0 ? (int) round(100 * $replay->correctResponses / $replay->responses) : null,
            'lessons' => count($replay->lessons),
            'average_stars' => $replay->lessons === [] ? null
                : round(array_sum(array_column($replay->lessons, 'stars')) / count($replay->lessons), 1),
            'skills' => $skills,
            'rescues' => [
                'total' => count($replay->rescues),
                'partial' => count(array_filter($replay->rescues, fn (array $r) => ! $r['full'])),
            ],
            'open_flags' => $student->interventionFlags->where('status', 'open')
                ->map(fn ($f) => ['type' => $f->type, 'sub_skill' => $f->sub_skill, 'level' => $f->level])->values()->all(),
            'pre_test' => $replay->assessments['pre'],
            'post_test' => $replay->assessments['post'],
            'first_activity' => $first?->toIso8601ZuluString(),
            'last_activity' => $replay->lastActivity?->toIso8601ZuluString(),
        ];
    }
}
