<?php

namespace App\Support;

use App\Models\BktState;
use App\Models\InterventionFlag;
use App\Models\Section;
use App\Models\Student;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Class-wide numbers for the teacher dashboard, read from the replayed tables
 * (bkt_states, path_progress, intervention_flags).
 */
final class SectionStats
{
    /**
     * Flags in a teacher's words: badge, dot colour, label. Red and orange come from
     * Racoon's Rescue, amber from a low P(L).
     */
    public const FLAG_STYLES = [
        'rescue_limit' => ['badge-red', '#c8423b', 'Out of rescue tries'],
        'rescue_partial' => ['badge-orange', '#e76f51', 'Went back a level'],
        'low_mastery' => ['badge-amber', '#e9a23b', 'Keeps missing a skill'],
    ];

    /** What each flag means, with the numbers (shown under "What do these mean?"). */
    public const FLAG_HELP = [
        'rescue_limit' => 'Lost all hearts and used up every Racoon\'s Rescue try on this skill.',
        'rescue_partial' => 'Lost all hearts, then missed the Racoon\'s Rescue questions, so this skill went back one level to review.',
        'low_mastery' => 'Mastery is still under 30% after 5 or more answers at this level.',
    ];

    public const FLAG_SEVERITY = ['rescue_limit' => 3, 'rescue_partial' => 2, 'low_mastery' => 1];

    /**
     * A learner's state in one sub-skill, in plain words. The P(L) numbers stay one click
     * away on the learner page and in the exports.
     */
    public const STATES = [
        'got' => 'Got it',
        'slip' => 'Slipping',
        'prac' => 'Practising',
        'help' => 'Needs help',
        'new' => 'Not started',
        'locked' => 'Not reached yet',
    ];

    /** A flag "looks better" once its skill-level is mastered again or P(L) reaches this. */
    public const BETTER_P = 0.50;

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

    /** @var array<int, array<string, array{key: string, label: string, level: int, p: ?float, attempts: int, review: bool}>> student id => skill => state */
    public array $states = [];

    /** @var array<string, array<string, int>> skill => state key => learners */
    public array $skillStates = [];

    /** @var array<int, int> map level => learners whose highest unlocked level it is */
    public array $levels = [];

    /** Learners who mastered every skill of level 5. */
    public int $finished = 0;

    /**
     * Open flags grouped by learner, most urgent first.
     *
     * @var list<array{student: Student, flags: list<array{flag: InterventionFlag, badge: string, color: string, label: string, help: string, skill: ?string, better: bool}>, active: int, severity: int}>
     */
    public array $needsHelp = [];

    /** @var array<int, int> student id => sort weight for "needs help first" */
    public array $severity = [];

    /** @var array<int, string> student id => last time the server received events (server time) */
    public array $lastSync = [];

    /** The game checks in every 2 minutes while open and online; 5 allows one missed round. */
    public const ACTIVE_MINUTES = 5;

    /** @var array<int, true> student id => playing right now (its sign-in token was used recently) */
    public array $activeNow = [];

    /** @var array<int, array{active: int, better: int}> student id => open flags still needing help / looking better */
    public array $flagCounts = [];

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
        // When the server last heard from each tablet, by the server's clock, not the device's.
        // "Active now": Sanctum stamps last_used_at on every signed-in game request.
        $byUser = $stats->students->pluck('id', 'user_id');
        $stats->activeNow = DB::table('personal_access_tokens')->where('tokenable_type', User::class)
            ->whereIn('tokenable_id', $byUser->keys())->where('last_used_at', '>=', now()->subMinutes(self::ACTIVE_MINUTES))
            ->pluck('tokenable_id')->unique()->mapWithKeys(fn ($userId) => [$byUser[$userId] => true])->all();
        $stats->lastSync = DB::table('sync_events')->whereIn('student_id', $ids)
            ->groupBy('student_id')->selectRaw('student_id, max(received_at) as last')
            ->pluck('last', 'student_id')->all();

        $stats->computeSkills();
        $stats->computeBands();
        $stats->computeStates();
        $stats->computeNeedsHelp();

        return $stats;
    }

    /**
     * One sub-skill of a learner in plain words: Got it (current level
     * mastered), Needs help (P(L) under 0.30 after 5+ answers, the low-mastery
     * flag rule), Practising, Not started, or Not reached yet.
     *
     * @return array{key: string, label: string, level: int, p: ?float, attempts: int, review: bool}
     */
    public static function skillState(Student $student, string $skill): array
    {
        $state = self::currentState($student, $skill);
        if ($state === null) {
            return ['key' => 'locked', 'label' => self::STATES['locked'], 'level' => SkillCatalog::minLevel($skill),
                'p' => null, 'attempts' => 0, 'review' => false];
        }
        $low = (float) config('reading_racoon.bkt.hint_p', 0.30);
        $min = (int) config('reading_racoon.bkt.mastery_min_attempts', 5);
        $key = match (true) {
            // Mastery latches, but the estimate keeps moving: say so when it has fallen.
            $state->mastered_at !== null && $state->p_mastery < self::BETTER_P => 'slip',
            $state->mastered_at !== null => 'got',
            $state->attempts === 0 && ! $state->review => 'new',
            $state->p_mastery < $low && $state->attempts >= $min => 'help',
            default => 'prac',
        };

        return ['key' => $key, 'label' => self::STATES[$key], 'level' => $state->level, 'p' => $state->p_mastery,
            'attempts' => $state->attempts, 'review' => (bool) $state->review];
    }

    /**
     * True when the child seems past what the flag reported: the skill-level
     * (or the level it went back to) was mastered after the flag, or a
     * low-mastery flag's P(L) has climbed to BETTER_P. The teacher still decides.
     */
    public static function looksBetter(Student $student, InterventionFlag $flag): bool
    {
        if ($flag->sub_skill === null || $flag->level === null) {
            return false;
        }
        $levels = array_filter([$flag->level, $flag->details['demoted_level'] ?? null], fn ($l) => is_int($l) && $l > 0);
        $states = $student->bktStates->where('sub_skill', $flag->sub_skill)->whereIn('level', $levels);
        if ($states->contains(fn (BktState $s) => $s->mastered_at !== null && $s->mastered_at->greaterThan($flag->raised_at))) {
            return true;
        }
        if ($flag->type === 'low_mastery') {
            $state = $states->firstWhere('level', $flag->level);

            return $state !== null && ($state->mastered_at !== null || $state->p_mastery >= self::BETTER_P);
        }

        return false;
    }

    private function computeStates(): void
    {
        foreach (SkillCatalog::skills() as $skill) {
            $this->skillStates[$skill] = array_fill_keys(array_keys(self::STATES), 0);
        }
        $this->levels = array_fill_keys(range(1, SkillCatalog::MAX_LEVEL), 0);
        foreach ($this->students as $student) {
            foreach (SkillCatalog::skills() as $skill) {
                $state = self::skillState($student, $skill);
                $this->states[$student->id][$skill] = $state;
                $this->skillStates[$skill][$state['key']]++;
            }
            $this->levels[self::highest($student)]++;
            if (str_ends_with(self::band($student), '(complete)')) {
                $this->finished++;
            }
        }
    }

    private function computeNeedsHelp(): void
    {
        $byStudent = $this->openFlags->groupBy('student_id');
        foreach ($this->students as $student) {
            $flags = collect($byStudent->get($student->id, []))
                ->map(fn (InterventionFlag $flag) => self::flagRow($student, $flag))
                ->sortBy([
                    fn ($a, $b) => $a['better'] <=> $b['better'],
                    fn ($a, $b) => (self::FLAG_SEVERITY[$b['flag']->type] ?? 0) <=> (self::FLAG_SEVERITY[$a['flag']->type] ?? 0),
                    fn ($a, $b) => $a['flag']->raised_at <=> $b['flag']->raised_at,
                ])->values();

            $active = $flags->where('better', false);
            $this->flagCounts[$student->id] = ['active' => $active->count(), 'better' => $flags->count() - $active->count()];
            $helpState = collect($this->states[$student->id] ?? [])->contains(fn ($s) => $s['key'] === 'help');
            $top = $active->max(fn ($f) => self::FLAG_SEVERITY[$f['flag']->type] ?? 0) ?? 0;
            $this->severity[$student->id] = $top * 10 + $active->count() + ($helpState ? 1 : 0);

            if ($flags->isNotEmpty()) {
                $this->needsHelp[] = ['student' => $student, 'flags' => $flags->all(), 'active' => $active->count(),
                    'severity' => $this->severity[$student->id]];
            }
        }
        usort($this->needsHelp, fn ($a, $b) => [$b['active'] > 0, $b['severity']] <=> [$a['active'] > 0, $a['severity']]
            ?: strcmp(mb_strtolower($a['student']->displayName()), mb_strtolower($b['student']->displayName())));
    }

    /**
     * One flag as the views show it: label, colours, meaning, skill name and
     * whether it looks better now.
     *
     * @return array{flag: InterventionFlag, badge: string, color: string, label: string, help: string, skill: ?string, better: bool}
     */
    public static function flagRow(Student $student, InterventionFlag $flag): array
    {
        [$badge, $color, $label] = self::FLAG_STYLES[$flag->type] ?? ['badge', '#6b6b78', ucfirst(str_replace('_', ' ', $flag->type))];

        return ['flag' => $flag, 'badge' => $badge, 'color' => $color, 'label' => $label,
            'help' => self::FLAG_HELP[$flag->type] ?? '',
            'skill' => $flag->sub_skill ? SkillCatalog::label($flag->sub_skill) : null,
            'better' => $flag->status === 'open' && self::looksBetter($student, $flag)];
    }

    /** Children whose open flags all look better: the "check and close" group. */
    public function betterRows(): array
    {
        return array_values(array_filter($this->needsHelp, fn ($row) => $row['active'] === 0));
    }

    /** Children with at least one open flag that doesn't look better yet. */
    public function activeRows(): array
    {
        return array_values(array_filter($this->needsHelp, fn ($row) => $row['active'] > 0));
    }

    /**
     * Ids of the flags of the children in "Looks better" (for "Close all"). A child still in
     * "Needs your help" keeps every flag until the teacher closes it there.
     */
    public function betterFlagIds(): array
    {
        $ids = [];
        foreach ($this->betterRows() as $row) {
            foreach ($row['flags'] as $f) {
                if ($f['better']) {
                    $ids[] = $f['flag']->id;
                }
            }
        }

        return $ids;
    }

    /** The newest time the server heard from any tablet in the section. */
    public function lastSectionSync(): ?string
    {
        return $this->lastSync === [] ? null : max($this->lastSync);
    }

    /**
     * A child's open flags merged per skill-level (one row, one "Mark resolved"
     * for all its flags), most urgent first.
     *
     * @return list<array{skill: ?string, level: ?int, flags: list<array>, ids: list<string>, better: bool, raised: mixed}>
     */
    public static function bySkill(array $flags): array
    {
        $groups = [];
        foreach ($flags as $f) {
            $key = ($f['flag']->sub_skill ?? '-').':'.($f['flag']->level ?? '-');
            $groups[$key] ??= ['skill' => $f['skill'], 'level' => $f['flag']->level, 'flags' => [], 'ids' => [], 'better' => true, 'raised' => $f['flag']->raised_at];
            $groups[$key]['flags'][] = $f;
            $groups[$key]['ids'][] = $f['flag']->id;
            $groups[$key]['better'] = $groups[$key]['better'] && $f['better'];
            if ($f['flag']->raised_at < $groups[$key]['raised']) {
                $groups[$key]['raised'] = $f['flag']->raised_at;
            }
        }

        return array_values($groups);
    }

    /** Learners with at least one open flag that doesn't look better yet. */
    public function needingHelpCount(): int
    {
        return count(array_filter($this->needsHelp, fn ($row) => $row['active'] > 0));
    }

    public function needsHelpNow(Student $student): bool
    {
        foreach ($this->needsHelp as $row) {
            if ($row['student']->is($student)) {
                return $row['active'] > 0;
            }
        }

        return false;
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

    /** ARAL band of a learner (from the highest unlocked map level). */
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
