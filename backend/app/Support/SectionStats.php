<?php

namespace App\Support;

use App\Models\BktState;
use App\Models\InterventionFlag;
use App\Models\Section;
use App\Models\Student;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Class-wide numbers for the teacher dashboard (FR-06, FR-17), read from the
 * replayed projections (bkt_states, path_progress, intervention_flags).
 */
final class SectionStats
{
    /** Flag colours: failed Heart Recovery is red/orange, low P(L) is amber (FR-17). */
    public const FLAG_STYLES = [
        'rescue_limit' => ['badge-red', '#c8423b', 'Rescue limit reached'],
        'rescue_partial' => ['badge-orange', '#e76f51', 'Heart Recovery failed'],
        'low_mastery' => ['badge-amber', '#e9a23b', 'Low mastery (P(L) < 0.30)'],
    ];

    /** @var Collection<int, Student> */
    public Collection $students;

    /** @var array<string, array{label: string, mastered_pct: int, avg_p: ?int, learners: int}> */
    public array $skills = [];

    /** @var array<string, int> band label => learners */
    public array $bands = [];

    /** @var Collection<int, InterventionFlag> */
    public Collection $openFlags;

    /** @var array<int, string> student id => last activity (device time, ISO) */
    public array $lastActivity = [];

    public static function for(Section $section): self
    {
        $stats = new self;
        $stats->students = $section->students()
            ->with(['user', 'pathProgress', 'wallet', 'bktStates'])
            ->withCount(['interventionFlags as open_flags_count' => fn ($q) => $q->where('status', 'open')])
            ->get()
            ->sortBy(fn (Student $s) => mb_strtolower($s->displayName()))
            ->values();

        $ids = $stats->students->pluck('id');
        $stats->openFlags = InterventionFlag::with('student.user')
            ->whereIn('student_id', $ids)->where('status', 'open')
            ->orderByDesc('raised_at')->get();
        $stats->lastActivity = DB::table('sync_events')->whereIn('student_id', $ids)
            ->groupBy('student_id')->selectRaw('student_id, max(device_time) as last')
            ->pluck('last', 'student_id')->all();

        $stats->computeSkills();
        $stats->computeBands();

        return $stats;
    }

    public static function highest(Student $student): int
    {
        return $student->pathProgress?->highest_unlocked ?? 1;
    }

    /**
     * The (sub-skill, level) state a learner is working on: the lowest unmastered
     * level of that skill they can reach. Null when the skill isn't unlocked yet
     * (e.g. fluency while on level 1); the highest state when all are mastered.
     */
    public static function currentState(Student $student, string $skill): ?BktState
    {
        $highest = self::highest($student);
        if (SkillCatalog::minLevel($skill) > $highest) {
            return null;
        }
        $states = $student->bktStates->where('sub_skill', $skill)->sortBy('level');
        $reachable = $states->filter(fn (BktState $s) => $s->level <= $highest);

        return $reachable->first(fn (BktState $s) => $s->mastered_at === null) ?? $reachable->last();
    }

    /** ARAL band label of a learner (from the highest unlocked map level, D-003). */
    public static function band(Student $student): string
    {
        $highest = self::highest($student);
        $complete = $highest === SkillCatalog::MAX_LEVEL && $student->bktStates
            ->filter(fn (BktState $s) => $s->level === SkillCatalog::MAX_LEVEL)
            ->every(fn (BktState $s) => $s->mastered_at !== null);

        return 'L'.$highest.' · '.SkillCatalog::level($highest)['band'].($complete ? ' (complete)' : '');
    }

    private function computeSkills(): void
    {
        foreach (SkillCatalog::skills() as $skill) {
            $levels = SkillCatalog::maxLevel($skill) - SkillCatalog::minLevel($skill) + 1;
            $mastered = 0;
            $ps = [];
            foreach ($this->students as $student) {
                $mastered += $student->bktStates->where('sub_skill', $skill)->whereNotNull('mastered_at')->count();
                $current = self::currentState($student, $skill);
                if ($current !== null && $current->mastered_at === null) {
                    $ps[] = $current->p_mastery;
                }
            }
            $possible = $levels * $this->students->count();
            $this->skills[$skill] = [
                'label' => SkillCatalog::label($skill),
                'mastered_pct' => $possible > 0 ? (int) round(100 * $mastered / $possible) : 0,
                'avg_p' => $ps === [] ? null : (int) round(100 * array_sum($ps) / count($ps)),
                'learners' => count($ps),
            ];
        }
    }

    private function computeBands(): void
    {
        foreach (range(1, SkillCatalog::MAX_LEVEL) as $level) {
            $this->bands['L'.$level.' · '.SkillCatalog::level($level)['band']] = 0;
        }
        $this->bands['L5 · Grade-Level Proficient (complete)'] = 0;
        foreach ($this->students as $student) {
            $this->bands[self::band($student)]++;
        }
    }
}
