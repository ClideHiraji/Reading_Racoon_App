<?php

namespace App\Support;

use App\Enums\SyncEventType;
use Carbon\CarbonImmutable;
use DateTimeInterface;
use Ramsey\Uuid\Uuid;

/**
 * Replays one student's synced events, in arrival order, through the same
 * rules as the client (reading-racoon/scripts/core/student_model.gd,
 * lesson_session.gd, assessment_session.gd, wardrobe.gd) and produces the
 * official state: the 14 BKT states, highest unlocked map level, wallet,
 * flags, items and outfit, daily usage, path and pre/post-test scores.
 * The server is the BKT authority (docs/knowledge/03-architecture.md, D-008,
 * D-010). Pure PHP, no database: App\Actions\ReplayStudentEvents feeds it.
 *
 * Fields read per event type (anything else is stored but ignored):
 * - response: skill, level, correct, num_choices, rescue. With assessment
 *   "pre"/"post" it is a test item: scored, never a BKT observation.
 * - placement: start_level (BKT placed from the pre-test answers, like StudentModel.place())
 * - assessment: kind, scores {skill: {correct, total}} (raw test scores, FR-02/FR-10)
 * - rescue_start: skill, level · rescue_end: (none, the server counts the answers)
 * - flag: type, skill, level (+ details); type clock_jump is an admin anomaly, not a teacher flag
 * - lesson_end: level, node, correct, total, ended_early · chest: level
 * - usage: date, minutes (cumulative after-school minutes that day; the largest wins)
 * - purchase: item, price · outfit: equipped {slot: item}
 * - bkt_state, level_up, hearts, access: stored only (the server computes the rest itself)
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

    /** @var array<string, array{slot: ?string, cost: int, acquired_at: ?CarbonImmutable}> keyed by item id */
    public array $items = [];

    /** @var array<string, string> slot => item id */
    public array $equipped = [];

    /** @var array<string, int> "YYYY-MM-DD" => after-school minutes played that day */
    public array $usage = [];

    /** @var array<string, array{done: int, chest: bool, bonus: list<int>}> PathProgress.worlds shape */
    public array $worlds = [];

    /** @var list<array{uuid: string, time: CarbonImmutable, skill: string, level: int, correct: bool, posterior: float, p: float, attempts: int, mastered_now: bool, level_up: bool}> one row per gameplay answer */
    public array $history = [];

    /** @var list<array{time: CarbonImmutable, level: int, node: int, correct: int, total: int, stars: int, xp: int, coins: int, level_up: bool}> */
    public array $lessons = [];

    /** @var list<array{time: CarbonImmutable, skill: string, from_level: int, correct: int, full: bool, demoted_level: ?int}> */
    public array $rescues = [];

    /** @var array{pre: array<string, array{correct: int, total: int}>, post: array<string, array{correct: int, total: int}>} per sub-skill */
    public array $assessments = ['pre' => [], 'post' => []];

    /** @var array{pre: ?CarbonImmutable, post: ?CarbonImmutable} when each test was finished */
    public array $assessedAt = ['pre' => null, 'post' => null];

    /** Map level the pre-test placed the learner on (null before the pre-test). */
    public ?int $placedLevel = null;

    /** @var list<array{time: CarbonImmutable, from: mixed, to: mixed}> device clock moved backwards */
    public array $clockJumps = [];

    public int $responses = 0;

    public int $correctResponses = 0;

    public ?CarbonImmutable $lastActivity = null;

    private float $masteryP;

    private int $masteryMinAttempts;

    private float $hintP;

    private float $demoteCap;

    /** @var array{xp_per_correct: int, coins_per_star: int, level_up_coins: int, chest_coins: int, lessons_per_world: int} */
    private array $rewards;

    /** @var array<string, array{slot: string, price: int}> */
    private array $shop;

    /** @var array{skill: string, from_level: int, answered: int, correct: int}|null */
    private ?array $rescue = null;

    private bool $levelUpSinceLesson = false;

    /** @var array<string, true> state keys with a low-mastery flag raised and not yet recovered */
    private array $lowFlagged = [];

    /** @var list<array{skill: string, correct: bool}> pre-test answers waiting for the placement event */
    private array $preAnswers = [];

    public function __construct()
    {
        $bkt = config('reading_racoon.bkt');
        $this->masteryP = (float) $bkt['mastery_p'];
        $this->masteryMinAttempts = (int) $bkt['mastery_min_attempts'];
        $this->hintP = (float) $bkt['hint_p'];
        $this->demoteCap = (float) $bkt['demote_cap'];
        $this->rewards = config('reading_racoon.rewards');
        $this->shop = config('reading_racoon.shop.items');

        $this->resetStates();
        // Wardrobe: every learner starts owning and wearing the starter items.
        foreach (config('reading_racoon.shop.starter') as $item) {
            $slot = $this->shop[$item]['slot'] ?? null;
            $this->items[$item] = ['slot' => $slot, 'cost' => 0, 'acquired_at' => null];
            if ($slot !== null) {
                $this->equipped[$slot] = $item;
            }
        }
    }

    public static function key(string $skill, int $level): string
    {
        return "$skill:$level";
    }

    /**
     * @param  iterable<array<string, mixed>|object>  $events  rows with uuid, type, payload (array or
     *                                                         JSON string) and device_time, oldest first (sync_events.id order)
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
            'placement' => $this->placement($p, $time),
            'assessment' => $this->assessment($p, $time),
            'rescue_start' => $this->rescueStart($p),
            'rescue_end' => $this->rescueEnd($time),
            'flag' => $this->flag($p, $time, $uuid),
            'lesson_end' => $this->lessonEnd($p, $time),
            'chest' => $this->chest($p),
            'usage' => $this->usage($p),
            'purchase' => $this->purchase($p, $time),
            'outfit' => $this->outfit($p),
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

        $assessment = $p['assessment'] ?? null;
        if ($assessment === 'pre' || $assessment === 'post') {
            // Test items are scored only (AssessmentSession.submit); BKT gets the
            // pre-test once, through the placement event.
            if ($this->assessedAt[$assessment] === null) {
                $score = $this->assessments[$assessment][$skill] ?? ['correct' => 0, 'total' => 0];
                $score['total']++;
                $score['correct'] += $correct ? 1 : 0;
                $this->assessments[$assessment][$skill] = $score;
            }
            if ($assessment === 'pre') {
                $this->preAnswers[] = ['skill' => $skill, 'correct' => $correct];
            }

            return;
        }

        if (! SkillCatalog::isActive($skill, $level)) {
            return;
        }
        $this->responses++;
        $this->correctResponses += $correct ? 1 : 0;
        $this->record($skill, $level, $correct, self::int($p['num_choices'] ?? null) ?? 0, $time, $uuid);

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
            'posterior' => $post, 'p' => $st['p'], 'attempts' => $st['attempts'],
            'mastered_now' => $masteredNow, 'level_up' => $levelUp,
        ];
    }

    /**
     * Pre-test placement, exactly as StudentModel.place() (05-bkt-engine.md,
     * FR-02): fresh states; each sub-skill's pre-test answers replayed on its
     * lowest-level state from P(L0) with the Table 3.5 guess rate; mastered when
     * the final posterior reaches 0.95 (no minimum attempts); start on the lowest
     * map level that still has an unmastered skill. The server recomputes it from
     * the answers it holds and only falls back to start_level without them.
     *
     * @param  array<string, mixed>  $p
     */
    private function placement(array $p, CarbonImmutable $time): void
    {
        if ($this->preAnswers === []) {
            $start = self::int($p['start_level'] ?? null);
            if ($start !== null && $start >= 1 && $start <= SkillCatalog::MAX_LEVEL) {
                $this->highestUnlocked = max($this->highestUnlocked, $start);
                $this->placedLevel = $start;
            }

            return;
        }

        $this->resetStates();
        $bySkill = [];
        foreach ($this->preAnswers as $answer) {
            $bySkill[$answer['skill']][] = $answer['correct'];
        }
        foreach ($bySkill as $skill => $answers) {
            $prm = SkillCatalog::params($skill);
            $key = self::key($skill, SkillCatalog::minLevel($skill));
            $pl = (float) $prm['l0'];
            $post = $pl;
            foreach ($answers as $correct) {
                $post = Bkt::posterior($pl, $correct, $prm['g'], $prm['s']);
                $pl = Bkt::transition($post, $prm['t']);
            }
            $mastered = $post >= $this->masteryP;
            $this->states[$key] = ['p' => $pl, 'attempts' => count($answers), 'mastered' => $mastered,
                'review' => false, 'mastered_at' => $mastered ? $time : null];
        }

        $this->highestUnlocked = SkillCatalog::MAX_LEVEL;
        for ($level = 1; $level <= SkillCatalog::MAX_LEVEL; $level++) {
            if (! $this->isLevelComplete($level)) {
                $this->highestUnlocked = $level;
                break;
            }
        }
        $this->placedLevel = $this->highestUnlocked;
        $this->preAnswers = [];
    }

    /**
     * Raw pre/post-test scores per sub-skill (FR-02, FR-10, RQ1). The first
     * report of each test counts; they replace the server's own tally.
     *
     * @param  array<string, mixed>  $p
     */
    private function assessment(array $p, CarbonImmutable $time): void
    {
        $kind = $p['kind'] ?? null;
        if (($kind !== 'pre' && $kind !== 'post') || $this->assessedAt[$kind] !== null) {
            return;
        }
        if (is_array($p['scores'] ?? null)) {
            $scores = [];
            foreach ($p['scores'] as $skill => $score) {
                $total = self::int(is_array($score) ? ($score['total'] ?? null) : null);
                $correct = self::int(is_array($score) ? ($score['correct'] ?? null) : null);
                if (SkillCatalog::isSkill($skill) && $total !== null && $correct !== null && $total >= 0 && $correct >= 0 && $correct <= $total) {
                    $scores[$skill] = ['correct' => $correct, 'total' => $total];
                }
            }
            $this->assessments[$kind] = $scores;
        }
        $this->assessedAt[$kind] = $time;
    }

    /**
     * Server-raised flag (FR-17): P(L) < 0.30 after >= 5 attempts at a level. One
     * flag per skill-level until it is mastered, however often P(L) bounces
     * around 0.30, so the teacher isn't flooded. The id is derived from the
     * triggering answer, so replaying again gives the same id.
     */
    private function checkLowMastery(string $key, string $skill, int $level, CarbonImmutable $time, string $uuid): void
    {
        $st = $this->states[$key];
        if ($st['mastered']) {
            unset($this->lowFlagged[$key]);

            return;
        }
        if ($st['p'] >= $this->hintP || $st['attempts'] < $this->masteryMinAttempts || isset($this->lowFlagged[$key])) {
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
     * Client-raised teacher flag (FR-17); its id is the event's UUID. A
     * clock_jump is kept for the admin logs instead (open issue 10).
     *
     * @param  array<string, mixed>  $p
     */
    private function flag(array $p, CarbonImmutable $time, string $uuid): void
    {
        $type = $p['type'] ?? null;
        if ($type === 'clock_jump') {
            $this->clockJumps[] = ['time' => $time, 'from' => $p['from'] ?? null, 'to' => $p['to'] ?? null];

            return;
        }
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
     * After-school minutes played on a local date (FR-12). The client sends its
     * running total for the day, so the largest value wins.
     *
     * @param  array<string, mixed>  $p
     */
    private function usage(array $p): void
    {
        $date = $p['date'] ?? null;
        $minutes = $p['minutes'] ?? null;
        if (! is_string($date) || ! preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $date, $m)
            || ! checkdate((int) $m[2], (int) $m[3], (int) $m[1])
            || ! (is_int($minutes) || is_float($minutes)) || $minutes < 0 || $minutes > 1440) {
            return;
        }
        $this->usage[$date] = max($this->usage[$date] ?? 0, (int) floor($minutes));
    }

    /**
     * A shop purchase (FR-07), as Wardrobe.buy(). Catalogue items cost the
     * server's price; an unknown item costs what the client paid. Ignored when
     * already owned or the replayed wallet can't pay: the server wins (D-008).
     *
     * @param  array<string, mixed>  $p
     */
    private function purchase(array $p, CarbonImmutable $time): void
    {
        $item = $p['item'] ?? $p['item_id'] ?? null;
        if (! self::isId($item, 64) || isset($this->items[$item])) {
            return;
        }
        $price = isset($this->shop[$item]) ? $this->shop[$item]['price'] : self::int($p['price'] ?? $p['cost'] ?? null);
        if ($price === null || $price < 0 || $price > 100000 || $this->coins < $price) {
            return;
        }
        $this->coins -= $price;
        $this->items[$item] = ['slot' => $this->shop[$item]['slot'] ?? null, 'cost' => $price, 'acquired_at' => $time];
    }

    /**
     * What the raccoon wears, {slot: item}, replacing the previous outfit.
     * Only owned items, in their own slot.
     *
     * @param  array<string, mixed>  $p
     */
    private function outfit(array $p): void
    {
        if (! is_array($p['equipped'] ?? null)) {
            return;
        }
        $equipped = [];
        foreach ($p['equipped'] as $slot => $item) {
            if (! self::isId((string) $slot, 32) || ! is_string($item) || ! isset($this->items[$item])) {
                continue;
            }
            $catalogSlot = $this->shop[$item]['slot'] ?? null;
            if ($catalogSlot !== null && $catalogSlot !== $slot) {
                continue;
            }
            $equipped[$slot] = $item;
            $this->items[$item]['slot'] ??= $slot;
        }
        $this->equipped = $equipped;
    }

    // --- Helpers -----------------------------------------------------------------

    private function resetStates(): void
    {
        foreach (SkillCatalog::states() as ['skill' => $skill, 'level' => $level]) {
            $this->states[self::key($skill, $level)] = [
                'p' => (float) SkillCatalog::params($skill)['l0'],
                'attempts' => 0,
                'mastered' => false,
                'review' => false,
                'mastered_at' => null,
            ];
        }
        $this->highestUnlocked = 1;
        $this->lowFlagged = [];
    }

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
