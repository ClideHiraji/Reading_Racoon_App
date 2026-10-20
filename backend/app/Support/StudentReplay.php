<?php

namespace App\Support;

use App\Enums\SyncEventType;
use Carbon\CarbonImmutable;
use Closure;
use DateTimeInterface;
use Ramsey\Uuid\Uuid;

/**
 * Replays one student's synced events, in arrival order, through the same
 * rules as the client (reading-racoon/scripts/core/student_model.gd and
 * lesson_session.gd) and produces the official state: the 14 BKT states,
 * highest unlocked map level, wallet, flags, items, daily usage and path.
 * The server is the BKT authority (docs/knowledge/03-architecture.md, D-008,
 * D-010). Pure PHP, no database: App\Actions\ReplayStudentEvents feeds it.
 *
 * Fields read per event type (anything else is stored but ignored):
 * - response: skill, level, correct, num_choices, rescue, assessment ("pre"|"post")
 * - rescue_start: skill, level · rescue_end: (none, the server counts the answers)
 * - flag: type, skill, level (+ details) · lesson_end: level, node, correct, total, ended_early
 * - chest: level · usage: date, minutes, window · purchase: item_id, cost, slot · equip: item_id, slot
 * - bkt_state, level_up, hearts: ignored (the server computes them itself)
 *
 * An event whose fields don't make sense (unknown skill, level out of range,
 * missing "correct") is skipped, never fatal: the raw event stays stored.
 */
final class StudentReplay
{
    /** Racoon's Rescue serves 3 items; 3/3 is a full recovery (D-004). */
    public const RESCUE_ITEMS = 3;

    /** Namespace for the deterministic ids of server-raised low-mastery flags. */
    private const FLAG_NAMESPACE = '0e9b6f4e-3c1d-5a7b-9f20-7d4c2b1a0e55';

    /** @var array<string, array{p: float, attempts: int, mastered: bool, review: bool, mastered_at: ?CarbonImmutable}> "skill:level" => state */
    public array $states = [];

    public int $highestUnlocked = 1;

    public int $xp = 0;

    public int $coins = 0;

    /** @var array<string, array{type: string, sub_skill: ?string, level: ?int, details: array<string, mixed>, raised_at: CarbonImmutable}> keyed by flag uuid */
    public array $flags = [];

    /** @var array<string, array{slot: ?string, cost: int, acquired_at: CarbonImmutable}> keyed by item id */
    public array $items = [];

    /** @var array<string, string> slot => item id */
    public array $equipped = [];

    /** @var array<string, array{minutes: int, class_minutes: int}> "YYYY-MM-DD" => minutes */
    public array $usage = [];

    /** @var array<string, array{done: int, chest: bool, bonus: list<int>}> PathProgress.worlds shape */
    public array $worlds = [];

    /** @var list<array{uuid: string, time: CarbonImmutable, skill: string, level: int, correct: bool, assessment: ?string, posterior: float, p: float, attempts: int, mastered_now: bool, level_up: bool}> one row per BKT observation */
    public array $history = [];

    /** @var list<array{time: CarbonImmutable, level: int, node: int, correct: int, total: int, stars: int, xp: int, coins: int, level_up: bool}> */
    public array $lessons = [];

    /** @var list<array{time: CarbonImmutable, skill: string, from_level: int, correct: int, full: bool, demoted_level: ?int}> */
    public array $rescues = [];

    /** @var array{pre: array<string, array{correct: int, total: int}>, post: array<string, array{correct: int, total: int}>} */
    public array $assessments = ['pre' => [], 'post' => []];

    public int $responses = 0;

    public int $correctResponses = 0;

    public ?CarbonImmutable $lastActivity = null;

    private float $masteryP;

    private int $masteryMinAttempts;

    private float $hintP;

    private float $demoteCap;

    /** @var array{xp_per_correct: int, coins_per_star: int, level_up_coins: int, chest_coins: int, lessons_per_world: int} */
    private array $rewards;

    /** @var array{skill: string, from_level: int, answered: int, correct: int}|null */
    private ?array $rescue = null;

    private bool $levelUpSinceLesson = false;

    /** @var array<string, true> state keys with a low-mastery flag raised and not yet recovered */
    private array $lowFlagged = [];

    /**
     * @param  (Closure(CarbonImmutable): bool)|null  $inClassWindow  classifies usage
     *                                                                events that don't say which window they were played in
     */
    public function __construct(private readonly ?Closure $inClassWindow = null)
    {
        $bkt = config('reading_racoon.bkt');
        $this->masteryP = (float) $bkt['mastery_p'];
        $this->masteryMinAttempts = (int) $bkt['mastery_min_attempts'];
        $this->hintP = (float) $bkt['hint_p'];
        $this->demoteCap = (float) $bkt['demote_cap'];
        $this->rewards = config('reading_racoon.rewards');

        foreach (SkillCatalog::states() as ['skill' => $skill, 'level' => $level]) {
            $this->states[self::key($skill, $level)] = [
                'p' => (float) SkillCatalog::params($skill)['l0'],
                'attempts' => 0,
                'mastered' => false,
                'review' => false,
                'mastered_at' => null,
            ];
        }
    }

    public static function key(string $skill, int $level): string
    {
        return "$skill:$level";
    }

    /**
     * @param  iterable<array<string, mixed>|object>  $events  rows with uuid, type, payload
     *                                                         (array or JSON string) and device_time, oldest first (sync_events.id order)
     */
    public function run(iterable $events): self
    {
        foreach ($events as $event) {
            $event = (array) $event;
            $payload = is_string($event['payload']) ? json_decode($event['payload'], true) : $event['payload'];
            $type = $event['type'] instanceof SyncEventType ? $event['type']->value : (string) $event['type'];
            $time = $event['device_time'] instanceof DateTimeInterface
                ? CarbonImmutable::instance($event['device_time'])->utc()
                : CarbonImmutable::parse($event['device_time'])->utc();

            $this->apply($type, is_array($payload) ? $payload : [], $time, strtolower((string) $event['uuid']));
        }

        return $this;
    }

    /**
     * @param  array<string, mixed>  $p
     */
    public function apply(string $type, array $p, CarbonImmutable $time, string $uuid): void
    {
        $this->lastActivity = $this->lastActivity === null || $time->greaterThan($this->lastActivity) ? $time : $this->lastActivity;

        match ($type) {
            'response' => $this->response($p, $time, $uuid),
            'rescue_start' => $this->rescueStart($p),
            'rescue_end' => $this->rescueEnd($time),
            'flag' => $this->flag($p, $time, $uuid),
            'lesson_end' => $this->lessonEnd($p, $time),
            'chest' => $this->chest($p),
            'usage' => $this->usage($p, $time),
            'purchase' => $this->purchase($p, $time),
            'equip' => $this->equip($p),
            default => null,
        };
    }

    /** Every sub-skill active at $level is mastered there (Level Up rule, D-003 rule 4). */
    public function isLevelComplete(int $level): bool
    {
        foreach (SkillCatalog::activeSkills($level) as $skill) {
            if (! $this->states[self::key($skill, $level)]['mastered']) {
                return false;
            }
        }

        return true;
    }

    /**
     * Exactly the shape of the client's StudentModel.to_dict(), so the game can
     * adopt the server state with model.from_dict().
     *
     * @return array{states: array<string, array{p: float, attempts: int, mastered: bool, review: bool}>, highest_unlocked: int}
     */
    public function model(): array
    {
        $states = [];
        foreach ($this->states as $key => $st) {
            $states[$key] = ['p' => $st['p'], 'attempts' => $st['attempts'], 'mastered' => $st['mastered'], 'review' => $st['review']];
        }

        return ['states' => $states, 'highest_unlocked' => $this->highestUnlocked];
    }

    /** Stars for a lesson, as LessonSession.summary() (FR-15). */
    public static function stars(int $correct, int $total): int
    {
        $accuracy = $total > 0 ? $correct / $total : 0.0;

        return $accuracy >= 0.9 ? 3 : ($accuracy >= 0.7 ? 2 : 1);
    }

    // --- Event handlers --------------------------------------------------------

    /**
     * @param  array<string, mixed>  $p
     */
    private function response(array $p, CarbonImmutable $time, string $uuid): void
    {
        $skill = $p['skill'] ?? null;
        $level = self::int($p['level'] ?? null);
        $correct = $p['correct'] ?? null;
        if (! SkillCatalog::isSkill($skill) || $level === null || ! is_bool($correct)) {
            return;
        }
        $choices = self::int($p['num_choices'] ?? null) ?? 0;
        $assessment = $p['assessment'] ?? null;

        if ($assessment === 'pre' || $assessment === 'post') {
            $score = $this->assessments[$assessment][$skill] ?? ['correct' => 0, 'total' => 0];
            $score['total']++;
            $score['correct'] += $correct ? 1 : 0;
            $this->assessments[$assessment][$skill] = $score;
            // The post-test measures the outcome (FR-10); it doesn't move BKT.
            if ($assessment === 'pre') {
                $this->place($skill, $correct, $choices, $time, $uuid);
            }

            return;
        }

        if (! SkillCatalog::isActive($skill, $level)) {
            return;
        }
        $this->responses++;
        $this->correctResponses += $correct ? 1 : 0;
        $this->record($skill, $level, $correct, $choices, $time, $uuid);

        if ($this->rescue !== null && ($p['rescue'] ?? false) === true && $this->rescue['skill'] === $skill) {
            $this->rescue['answered']++;
            $this->rescue['correct'] += $correct ? 1 : 0;
        }
    }

    /** One answer (Figure 3.17): posterior, mastery check, transition, Level Up. StudentModel.record(). */
    private function record(string $skill, int $level, bool $correct, int $choices, CarbonImmutable $time, string $uuid): void
    {
        $key = self::key($skill, $level);
        $st = $this->states[$key];
        $prm = SkillCatalog::params($skill);
        $post = Bkt::posterior($st['p'], $correct, Bkt::guessFor($prm['g'], $prm['s'], $choices), $prm['s']);
        $st['attempts']++;
        $masteredNow = false;
        if (! $st['mastered'] && $post >= $this->masteryP && $st['attempts'] >= $this->masteryMinAttempts) {
            $st['mastered'] = true;
            $st['review'] = false;
            $st['mastered_at'] = $time;
            $masteredNow = true;
        }
        $st['p'] = Bkt::transition($post, $prm['t']);
        $this->states[$key] = $st;

        $levelUp = false;
        if ($masteredNow && $level === $this->highestUnlocked && $this->isLevelComplete($level)
            && $this->highestUnlocked < SkillCatalog::MAX_LEVEL) {
            $this->highestUnlocked++;
            $this->levelUpSinceLesson = true;
            $levelUp = true;
        }

        $this->checkLowMastery($key, $skill, $level, $time, $uuid);
        $this->history[] = [
            'uuid' => $uuid, 'time' => $time, 'skill' => $skill, 'level' => $level, 'correct' => $correct,
            'assessment' => null, 'posterior' => $post, 'p' => $st['p'], 'attempts' => $st['attempts'],
            'mastered_now' => $masteredNow, 'level_up' => $levelUp,
        ];
    }

    /**
     * Pre-test placement (docs/knowledge/05-bkt-engine.md): the item updates the
     * sub-skill's lowest-level state, mastery needs no minimum attempts, and the
     * learner starts on the lowest map level that still has an unmastered skill.
     */
    private function place(string $skill, bool $correct, int $choices, CarbonImmutable $time, string $uuid): void
    {
        $level = SkillCatalog::minLevel($skill);
        $key = self::key($skill, $level);
        $st = $this->states[$key];
        $prm = SkillCatalog::params($skill);
        $post = Bkt::posterior($st['p'], $correct, Bkt::guessFor($prm['g'], $prm['s'], $choices), $prm['s']);
        $st['attempts']++;
        $masteredNow = false;
        if (! $st['mastered'] && $post >= $this->masteryP) {
            $st['mastered'] = true;
            $st['review'] = false;
            $st['mastered_at'] = $time;
            $masteredNow = true;
        }
        $st['p'] = Bkt::transition($post, $prm['t']);
        $this->states[$key] = $st;

        $placed = SkillCatalog::MAX_LEVEL;
        for ($l = 1; $l <= SkillCatalog::MAX_LEVEL; $l++) {
            if (! $this->isLevelComplete($l)) {
                $placed = $l;
                break;
            }
        }
        $levelUp = $placed > $this->highestUnlocked;
        $this->highestUnlocked = max($this->highestUnlocked, $placed);

        $this->history[] = [
            'uuid' => $uuid, 'time' => $time, 'skill' => $skill, 'level' => $level, 'correct' => $correct,
            'assessment' => 'pre', 'posterior' => $post, 'p' => $st['p'], 'attempts' => $st['attempts'],
            'mastered_now' => $masteredNow, 'level_up' => $levelUp,
        ];
    }

    /**
     * Server-raised flag (FR-17): P(L) < 0.30 after >= 5 attempts at a level. One
     * flag per episode; a new one only after P(L) climbs back over 0.30. The id is
     * derived from the triggering answer, so replaying again gives the same id.
     */
    private function checkLowMastery(string $key, string $skill, int $level, CarbonImmutable $time, string $uuid): void
    {
        $st = $this->states[$key];
        if ($st['p'] >= $this->hintP || $st['mastered']) {
            unset($this->lowFlagged[$key]);

            return;
        }
        if ($st['attempts'] < $this->masteryMinAttempts || isset($this->lowFlagged[$key])) {
            return;
        }
        $this->lowFlagged[$key] = true;
        $id = Uuid::uuid5(self::FLAG_NAMESPACE, "low_mastery:$uuid:$key")->toString();
        $this->flags[$id] = [
            'type' => 'low_mastery', 'sub_skill' => $skill, 'level' => $level,
            'details' => ['p' => round($st['p'], 4), 'attempts' => $st['attempts'], 'source' => 'server'],
            'raised_at' => $time,
        ];
    }

    /**
     * @param  array<string, mixed>  $p
     */
    private function rescueStart(array $p): void
    {
        $skill = $p['skill'] ?? null;
        $level = self::int($p['level'] ?? null);
        if (! SkillCatalog::isSkill($skill) || $level === null || ! SkillCatalog::isActive($skill, $level)) {
            return;
        }
        $this->rescue = ['skill' => $skill, 'from_level' => $level, 'answered' => 0, 'correct' => 0];
    }

    /** Partial recovery (< 3/3) drops the skill one tier: LessonSession._submit_rescue() (D-004). */
    private function rescueEnd(CarbonImmutable $time): void
    {
        if ($this->rescue === null) {
            return;
        }
        ['skill' => $skill, 'from_level' => $from, 'correct' => $correct] = $this->rescue;
        $full = $correct >= self::RESCUE_ITEMS;
        $demoted = null;
        $lower = $from - 1;
        if (! $full && $lower >= SkillCatalog::minLevel($skill)) {
            $key = self::key($skill, $lower);
            $st = $this->states[$key];
            $st['p'] = min($st['p'], $this->demoteCap);
            $st['attempts'] = 0;
            $st['mastered'] = false;
            $st['mastered_at'] = null;
            $st['review'] = true;
            $this->states[$key] = $st;
            $demoted = $lower;
        }
        $this->rescues[] = ['time' => $time, 'skill' => $skill, 'from_level' => $from, 'correct' => $correct, 'full' => $full, 'demoted_level' => $demoted];
        $this->rescue = null;
    }

    /**
     * Client-raised teacher flag (FR-17); its id is the event's UUID.
     *
     * @param  array<string, mixed>  $p
     */
    private function flag(array $p, CarbonImmutable $time, string $uuid): void
    {
        $type = $p['type'] ?? null;
        $level = self::int($p['level'] ?? null);
        $this->flags[$uuid] = [
            'type' => is_string($type) && $type !== '' && strlen($type) <= 32 ? $type : 'flag',
            'sub_skill' => SkillCatalog::isSkill($p['skill'] ?? null) ? $p['skill'] : null,
            'level' => $level !== null && $level >= 1 && $level <= SkillCatalog::MAX_LEVEL ? $level : null,
            'details' => array_diff_key($p, array_flip(['type', 'skill', 'level'])),
            'raised_at' => $time,
        ];
    }

    /**
     * XP and coins as GameState.finish_lesson(), recomputed by the server (FR-15).
     *
     * @param  array<string, mixed>  $p
     */
    private function lessonEnd(array $p, CarbonImmutable $time): void
    {
        $level = self::int($p['level'] ?? null);
        if ($level === null || $level < 1 || $level > SkillCatalog::MAX_LEVEL) {
            return;
        }
        $total = max(0, min(100, self::int($p['total'] ?? null) ?? 0));
        $correct = max(0, min($total, self::int($p['correct'] ?? null) ?? 0));
        $node = max(0, self::int($p['node'] ?? null) ?? 0);
        $stars = self::stars($correct, $total);
        $xp = $correct * $this->rewards['xp_per_correct'];
        $coins = $stars * $this->rewards['coins_per_star'] + ($this->levelUpSinceLesson ? $this->rewards['level_up_coins'] : 0);

        $this->xp += $xp;
        $this->coins += $coins;
        if (($p['ended_early'] ?? false) !== true) {
            $world = $this->world($level);
            if ($node >= $world['done']) {
                $world['done'] = min($world['done'] + 1, $this->rewards['lessons_per_world']);
            }
            $this->worlds[(string) $level] = $world;
        }
        $this->lessons[] = [
            'time' => $time, 'level' => $level, 'node' => $node, 'correct' => $correct, 'total' => $total,
            'stars' => $stars, 'xp' => $xp, 'coins' => $coins, 'level_up' => $this->levelUpSinceLesson,
        ];
        $this->levelUpSinceLesson = false;
    }

    /**
     * One chest per world (PathProgress.open_chest); the server sets the coins.
     *
     * @param  array<string, mixed>  $p
     */
    private function chest(array $p): void
    {
        $level = self::int($p['level'] ?? null);
        if ($level === null || $level < 1 || $level > SkillCatalog::MAX_LEVEL) {
            return;
        }
        $world = $this->world($level);
        if (! $world['chest']) {
            $world['chest'] = true;
            $this->coins += $this->rewards['chest_coins'];
            $this->worlds[(string) $level] = $world;
        }
    }

    /**
     * Minutes played since the previous usage event (FR-12). Class-window minutes
     * don't count toward the daily after-school cap.
     *
     * @param  array<string, mixed>  $p
     */
    private function usage(array $p, CarbonImmutable $time): void
    {
        $date = $p['date'] ?? null;
        $minutes = self::int($p['minutes'] ?? null);
        if (! is_string($date) || ! preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $date, $m)
            || ! checkdate((int) $m[2], (int) $m[3], (int) $m[1]) || $minutes === null || $minutes < 0 || $minutes > 600) {
            return;
        }
        $window = $p['window'] ?? null;
        $inClass = $window === 'class'
            || ($window === null && $this->inClassWindow !== null && ($this->inClassWindow)($time));

        $day = $this->usage[$date] ?? ['minutes' => 0, 'class_minutes' => 0];
        $day[$inClass ? 'class_minutes' : 'minutes'] += $minutes;
        $this->usage[$date] = $day;
    }

    /**
     * A shop purchase (FR-07). Ignored when the item is already owned or the
     * replayed wallet can't pay for it: the server wins (D-008).
     *
     * @param  array<string, mixed>  $p
     */
    private function purchase(array $p, CarbonImmutable $time): void
    {
        $item = $p['item_id'] ?? null;
        $cost = self::int($p['cost'] ?? null);
        if (! self::isId($item, 64) || $cost === null || $cost < 0 || $cost > 100000
            || isset($this->items[$item]) || $this->coins < $cost) {
            return;
        }
        $this->coins -= $cost;
        $slot = $p['slot'] ?? null;
        $this->items[$item] = ['slot' => self::isId($slot, 32) ? $slot : null, 'cost' => $cost, 'acquired_at' => $time];
    }

    /**
     * Put an owned item in a slot, or clear the slot with item_id null (FR-07).
     *
     * @param  array<string, mixed>  $p
     */
    private function equip(array $p): void
    {
        $slot = $p['slot'] ?? null;
        if (! self::isId($slot, 32) || ! array_key_exists('item_id', $p)) {
            return;
        }
        $item = $p['item_id'];
        if ($item === null) {
            unset($this->equipped[$slot]);

            return;
        }
        if (! is_string($item) || ! isset($this->items[$item])) {
            return;
        }
        $this->equipped = array_filter($this->equipped, fn (string $equipped) => $equipped !== $item);
        $this->equipped[$slot] = $item;
        $this->items[$item]['slot'] ??= $slot;
    }

    // --- Helpers -----------------------------------------------------------------

    /**
     * @return array{done: int, chest: bool, bonus: list<int>}
     */
    private function world(int $level): array
    {
        return $this->worlds[(string) $level] ?? ['done' => 0, 'chest' => false, 'bonus' => []];
    }

    /** An integer from JSON (2 or 2.0); anything else is null. */
    private static function int(mixed $value): ?int
    {
        if (is_int($value)) {
            return $value;
        }
        if (is_float($value) && floor($value) === $value && abs($value) < PHP_INT_MAX) {
            return (int) $value;
        }

        return null;
    }

    private static function isId(mixed $value, int $max): bool
    {
        return is_string($value) && preg_match('/^[A-Za-z0-9_.-]{1,'.$max.'}$/', $value) === 1;
    }
}
