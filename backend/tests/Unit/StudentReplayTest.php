<?php

namespace Tests\Unit;

use App\Support\Bkt;
use App\Support\SkillCatalog;
use App\Support\StudentReplay;
use Carbon\CarbonImmutable;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Server-side BKT replay (FR-03, FR-04, FR-07, FR-12, FR-17, D-003, D-004, D-010):
 * the same answers must give the same state as the client's StudentModel.
 * No database.
 */
class StudentReplayTest extends TestCase
{
    private CarbonImmutable $time;

    protected function setUp(): void
    {
        parent::setUp();
        $this->time = CarbonImmutable::parse('2026-10-20T00:00:00Z');
    }

    /** @param list<array{0: string, 1: array<string, mixed>}> $events */
    private function replay(array $events): StudentReplay
    {
        $rows = [];
        foreach ($events as $i => [$type, $payload]) {
            $rows[] = ['uuid' => (string) Str::uuid(), 'type' => $type, 'payload' => $payload,
                'device_time' => $this->time->addSeconds($i)->toIso8601ZuluString()];
        }

        return (new StudentReplay)->run($rows);
    }

    private function answer(string $skill, int $level, bool $correct, array $extra = []): array
    {
        return ['response', ['item_id' => 'x', 'skill' => $skill, 'level' => $level, 'answer' => 'a',
            'correct' => $correct, 'response_ms' => 1000, 'rescue' => false, 'num_choices' => 3, ...$extra]];
    }

    /** @return list<array{0: string, 1: array<string, mixed>}> */
    private function correct(string $skill, int $level, int $times, array $extra = []): array
    {
        return array_fill(0, $times, $this->answer($skill, $level, true, $extra));
    }

    public function test_every_student_starts_with_14_states_at_their_prior(): void
    {
        $replay = $this->replay([]);

        $this->assertCount(14, $replay->states);
        $this->assertSame(0.25, $replay->states['phonics:2']['p']);
        $this->assertSame(1, $replay->highestUnlocked);
    }

    public function test_one_answer_follows_the_bkt_equations_with_guess_one_over_choices(): void
    {
        $replay = $this->replay([$this->answer('phonological_awareness', 1, true)]);

        // P(L0)=0.20, S=0.10, T=0.15, G=1/3 for a 3-choice item (D-003 rule 7).
        $post = 0.2 * 0.9 / (0.2 * 0.9 + 0.8 / 3);
        $state = $replay->states['phonological_awareness:1'];
        $this->assertEqualsWithDelta($post + (1 - $post) * 0.15, $state['p'], 1e-12);
        $this->assertSame(1, $state['attempts']);
        $this->assertEqualsWithDelta($post, $replay->history[0]['posterior'], 1e-12);
    }

    public function test_without_num_choices_the_table_guess_is_used(): void
    {
        $replay = $this->replay([['response', ['skill' => 'phonics', 'level' => 1, 'correct' => true]]]);

        $this->assertEqualsWithDelta(Bkt::posterior(0.25, true, 0.20, 0.10), $replay->history[0]['posterior'], 1e-12);
        // The guess always stays below 1 - S (here 1 - 0.6 - 0.01).
        $this->assertEqualsWithDelta(0.39, Bkt::guessFor(0.2, 0.6, 2), 1e-12);
    }

    public function test_mastery_needs_095_and_at_least_five_attempts(): void
    {
        $replay = $this->replay($this->correct('phonological_awareness', 1, 4));
        $this->assertFalse($replay->states['phonological_awareness:1']['mastered'], 'P(L) passes 0.95 after 3, but 4 attempts are not enough');

        $replay = $this->replay($this->correct('phonological_awareness', 1, 5));
        $state = $replay->states['phonological_awareness:1'];
        $this->assertTrue($state['mastered']);
        $this->assertSame(5, $state['attempts']);
        $this->assertNotNull($state['mastered_at']);
        $this->assertTrue($replay->history[4]['mastered_now']);
    }

    public function test_level_up_when_every_skill_active_at_the_level_is_mastered(): void
    {
        $replay = $this->replay($this->correct('phonological_awareness', 1, 5));
        $this->assertSame(1, $replay->highestUnlocked, 'phonics L1 is not mastered yet');

        $replay = $this->replay([...$this->correct('phonological_awareness', 1, 5), ...$this->correct('phonics', 1, 5)]);
        $this->assertSame(2, $replay->highestUnlocked);
        $this->assertTrue($replay->history[9]['level_up']);
    }

    public function test_a_level_above_the_highest_unlocked_never_levels_up(): void
    {
        // Answers at level 2 while level 1 isn't cleared master the states but unlock nothing.
        $replay = $this->replay([
            ...$this->correct('phonological_awareness', 2, 5),
            ...$this->correct('phonics', 2, 5),
            ...$this->correct('vocabulary', 2, 5),
        ]);

        $this->assertTrue($replay->isLevelComplete(2));
        $this->assertSame(1, $replay->highestUnlocked);
    }

    public function test_answers_for_unknown_skills_or_levels_are_skipped(): void
    {
        $replay = $this->replay([
            ['response', ['skill' => 'spelling', 'level' => 1, 'correct' => true]],
            ['response', ['skill' => 'fluency', 'level' => 1, 'correct' => true]],
            ['response', ['skill' => 'phonics', 'level' => 2, 'correct' => 'yes']],
            ['response', ['answer' => 'cat']],
            ['bkt_state', ['skill' => 'phonics', 'level' => 1, 'p' => 0.99, 'mastered' => true]],
            ['level_up', ['to_level' => 5]],
        ]);

        $this->assertSame([], $replay->history);
        $this->assertSame(1, $replay->highestUnlocked, 'client bkt_state and level_up events are not trusted');
        $this->assertSame(0.25, $replay->states['phonics:1']['p']);
    }

    public function test_partial_rescue_demotes_the_level_below_and_full_rescue_does_not(): void
    {
        $masterPhonics1 = $this->correct('phonics', 1, 5);
        $rescue = fn (int $right) => [
            ['rescue_start', ['skill' => 'phonics', 'level' => 2]],
            ...array_map(fn (int $i) => $this->answer('phonics', 1, $i < $right, ['rescue' => true]), range(0, 2)),
            ['rescue_end', ['skill' => 'phonics', 'correct' => 3, 'full' => true]], // the server counts for itself
        ];

        $partial = $this->replay([...$masterPhonics1, ...$rescue(1)]);
        $state = $partial->states['phonics:1'];
        $this->assertFalse($state['mastered']);
        $this->assertTrue($state['review']);
        $this->assertSame(0, $state['attempts']);
        $this->assertLessThanOrEqual(0.70, $state['p']);
        $this->assertNull($state['mastered_at']);
        $this->assertSame([false, 1, 1], [$partial->rescues[0]['full'], $partial->rescues[0]['correct'], $partial->rescues[0]['demoted_level']]);

        $full = $this->replay([...$masterPhonics1, ...$rescue(3)]);
        $this->assertTrue($full->states['phonics:1']['mastered']);
        $this->assertFalse($full->states['phonics:1']['review']);
        $this->assertTrue($full->rescues[0]['full']);

        // At a sub-skill's lowest level there is nothing below to demote.
        $lowest = $this->replay([
            ['rescue_start', ['skill' => 'phonics', 'level' => 1]],
            ...array_fill(0, 3, $this->answer('phonics', 1, false, ['rescue' => true])),
            ['rescue_end', []],
        ]);
        $this->assertNull($lowest->rescues[0]['demoted_level']);
        $this->assertFalse($lowest->states['phonics:1']['review']);
    }

    public function test_client_flags_keep_the_event_uuid_and_details(): void
    {
        $id = (string) Str::uuid();
        $replay = (new StudentReplay)->run([[
            'uuid' => strtoupper($id), 'type' => 'flag', 'device_time' => '2026-10-20T01:00:00Z',
            'payload' => ['type' => 'rescue_partial', 'skill' => 'phonics', 'level' => 2, 'correct' => 1, 'demoted_level' => 1],
        ]]);

        $flag = $replay->flags[$id];
        $this->assertSame(['rescue_partial', 'phonics', 2], [$flag['type'], $flag['sub_skill'], $flag['level']]);
        $this->assertSame(['correct' => 1, 'demoted_level' => 1], $flag['details']);
    }

    public function test_low_mastery_raises_one_server_flag_per_episode_with_a_stable_id(): void
    {
        $rows = [];
        for ($i = 0; $i < 6; $i++) {
            $rows[] = ['uuid' => "00000000-0000-4000-8000-00000000000$i", 'type' => 'response', 'device_time' => '2026-10-20T01:00:0'.$i.'Z',
                'payload' => ['skill' => 'phonics', 'level' => 1, 'correct' => false, 'num_choices' => 3]];
        }
        $first = (new StudentReplay)->run($rows);
        $again = (new StudentReplay)->run($rows);

        $this->assertCount(1, $first->flags, 'five wrong answers: one flag, not one per answer');
        $bouncing = $this->replay([
            ...array_fill(0, 5, $this->answer('phonics', 1, false)),
            $this->answer('phonics', 1, true), $this->answer('phonics', 1, true),   // back above 0.30
            ...array_fill(0, 3, $this->answer('phonics', 1, false)),              // and below again
        ]);
        $this->assertCount(1, $bouncing->flags, 'one flag per skill-level until it is mastered');
        $flag = array_values($first->flags)[0];
        $this->assertSame(['low_mastery', 'phonics', 1, 5], [$flag['type'], $flag['sub_skill'], $flag['level'], $flag['details']['attempts']]);
        $this->assertSame(array_keys($first->flags), array_keys($again->flags));
    }

    public function test_wallet_and_path_are_recomputed_from_lessons_and_chests(): void
    {
        $replay = $this->replay([
            ['lesson_end', ['level' => 1, 'node' => 0, 'correct' => 7, 'total' => 8, 'stars' => 3]],
            ['lesson_end', ['level' => 1, 'node' => 1, 'correct' => 8, 'total' => 8, 'stars' => 3]],
            ['chest', ['level' => 1, 'coins' => 999]],
            ['chest', ['level' => 1, 'coins' => 15]],
            ['lesson_end', ['level' => 1, 'node' => 2, 'correct' => 2, 'total' => 8, 'ended_early' => true]],
        ]);

        // 7/8 = 2 stars (the client's "3" is ignored), 8/8 = 3 stars, 2/8 = 1 star.
        $this->assertSame([2, 3, 1], array_column($replay->lessons, 'stars'));
        $this->assertSame((7 + 8 + 2) * 10, $replay->xp);
        $this->assertSame((2 + 3 + 1) * 5 + 15, $replay->coins, 'one chest per world, with the server\'s coins');
        $this->assertSame(['1' => ['done' => 2, 'chest' => true, 'bonus' => []]], $replay->worlds);
    }

    public function test_a_level_up_adds_the_bonus_to_the_next_lesson_end(): void
    {
        $replay = $this->replay([
            ...$this->correct('phonological_awareness', 1, 5),
            ...$this->correct('phonics', 1, 3),
            ['lesson_end', ['level' => 1, 'node' => 0, 'correct' => 8, 'total' => 8]],
            ...$this->correct('phonics', 1, 2),
            ['lesson_end', ['level' => 1, 'node' => 1, 'correct' => 2, 'total' => 2]],
            ['lesson_end', ['level' => 2, 'node' => 0, 'correct' => 2, 'total' => 2]],
        ]);

        $this->assertSame([false, true, false], array_column($replay->lessons, 'level_up'));
        $this->assertSame([15, 35, 15], array_column($replay->lessons, 'coins'));
    }

    public function test_purchases_use_the_server_price_and_need_enough_coins(): void
    {
        $replay = $this->replay([
            ['lesson_end', ['level' => 1, 'node' => 0, 'correct' => 8, 'total' => 8]],    // 15 coins
            ['chest', ['level' => 1]],                                                   // +15 = 30
            ['purchase', ['item' => 'gold_crown', 'price' => 120, 'coins_left' => 0]],     // can't pay
            ['purchase', ['item' => 'cap', 'price' => 1, 'coins_left' => 29]],             // costs 30, not 1
            ['purchase', ['item' => 'cap', 'price' => 30, 'coins_left' => 0]],             // already owned
            ['purchase', ['item' => 'mystery_hat', 'price' => 0]],                         // unknown: client price
        ]);

        $this->assertSame(['scarf_teal', 'cap', 'mystery_hat'], array_keys($replay->items));
        $this->assertSame(['hat', 30], [$replay->items['cap']['slot'], $replay->items['cap']['cost']]);
        $this->assertNull($replay->items['mystery_hat']['slot']);
        $this->assertSame(0, $replay->coins);
    }

    public function test_the_outfit_holds_owned_items_in_their_own_slot(): void
    {
        $this->assertSame(['neck' => 'scarf_teal'], $this->replay([])->equipped, 'starter scarf, as Wardrobe');

        $replay = $this->replay([
            ['chest', ['level' => 1]],
            ['chest', ['level' => 2]],                                                   // 30 coins
            ['purchase', ['item' => 'cap', 'price' => 30, 'coins_left' => 0]],
            ['outfit', ['equipped' => ['hat' => 'cap', 'neck' => 'scarf_teal', 'eyes' => 'sunglasses', 'badge' => 'cap']]],
        ]);
        $this->assertSame(['hat' => 'cap', 'neck' => 'scarf_teal'], $replay->equipped, 'not owned and wrong slot are dropped');

        $bare = $this->replay([['outfit', ['equipped' => []]]]);
        $this->assertSame([], $bare->equipped);
    }

    public function test_usage_keeps_the_largest_running_total_per_day(): void
    {
        $replay = $this->replay([
            ['usage', ['date' => '2026-10-20', 'minutes' => 1.0]],
            ['usage', ['date' => '2026-10-20', 'minutes' => 12.7]],
            ['usage', ['date' => '2026-10-20', 'minutes' => 4]],      // an older total arriving late
            ['usage', ['date' => '2026-10-21', 'minutes' => 3]],
            ['usage', ['date' => '2026-02-30', 'minutes' => 4]],
            ['usage', ['date' => '2026-10-22', 'minutes' => -3]],
            ['usage', ['date' => '2026-10-22', 'minutes' => '9']],
        ]);

        $this->assertSame(['2026-10-20' => 12, '2026-10-21' => 3], $replay->usage);
    }

    public function test_placement_replays_the_pre_test_like_the_client(): void
    {
        $pre = fn (string $skill, bool $correct) => ['response', ['skill' => $skill, 'level' => SkillCatalog::minLevel($skill), 'correct' => $correct,
            'num_choices' => 3, 'assessment' => 'pre']];
        $replay = $this->replay([
            $pre('phonological_awareness', true), $pre('phonological_awareness', true), $pre('phonological_awareness', true),
            $pre('phonics', true), $pre('phonics', true), $pre('phonics', true),
            $pre('vocabulary', true), $pre('vocabulary', true), $pre('vocabulary', true), $pre('vocabulary', false),
            ['placement', ['start_level' => 5]],       // the server recomputes; it doesn't trust this number
            ['assessment', ['kind' => 'pre', 'scores' => ['phonics' => ['correct' => 3, 'total' => 3], 'spelling' => ['correct' => 1, 'total' => 1]],
                'correct' => 9, 'total' => 10]],
        ]);

        // Table 3.5 guess rates (not 1/choices) and the FINAL posterior decide mastery.
        $this->assertTrue($replay->states['phonological_awareness:1']['mastered']);
        $this->assertTrue($replay->states['phonics:1']['mastered']);
        $this->assertFalse($replay->states['vocabulary:2']['mastered'], 'the last answer was wrong');
        $this->assertSame(3, $replay->states['phonics:1']['attempts']);
        $this->assertSame(4, $replay->states['vocabulary:2']['attempts']);
        $this->assertSame(2, $replay->highestUnlocked);
        $this->assertSame(2, $replay->placedLevel);
        $this->assertSame([], $replay->history, 'test items are not gameplay answers');
        $this->assertSame(0, $replay->responses);
        $this->assertSame(['phonics' => ['correct' => 3, 'total' => 3]], $replay->assessments['pre'], 'the reported scores, unknown skills dropped');
        $this->assertNotNull($replay->assessedAt['pre']);
    }

    public function test_placement_without_pre_test_answers_falls_back_to_the_start_level(): void
    {
        $replay = $this->replay([['placement', ['start_level' => 3]]]);

        $this->assertSame(3, $replay->highestUnlocked);
        $this->assertSame(0.2, $replay->states['phonological_awareness:1']['p']);
    }

    public function test_post_test_answers_are_scored_but_do_not_move_bkt(): void
    {
        $replay = $this->replay($this->correct('fluency', 3, 4, ['assessment' => 'post']));

        $this->assertSame(['correct' => 4, 'total' => 4], $replay->assessments['post']['fluency']);
        $this->assertSame(0.15, $replay->states['fluency:3']['p']);
        $this->assertSame([], $replay->history);
        $this->assertNull($replay->assessedAt['post'], 'no assessment event yet: the server\'s own tally');
    }

    public function test_a_clock_jump_is_not_a_teacher_flag(): void
    {
        $replay = $this->replay([['flag', ['type' => 'clock_jump', 'from' => 1760000000, 'to' => 1759990000]]]);

        $this->assertSame([], $replay->flags);
        $this->assertSame([1760000000, 1759990000], [$replay->clockJumps[0]['from'], $replay->clockJumps[0]['to']]);
    }

    public function test_the_model_has_the_shape_of_the_clients_student_model(): void
    {
        $model = $this->replay($this->correct('phonics', 1, 2))->model();

        $this->assertSame(['states', 'highest_unlocked'], array_keys($model));
        $this->assertSame(['p', 'attempts', 'mastered', 'review'], array_keys($model['states']['phonics:1']));
        $this->assertSame(2, $model['states']['phonics:1']['attempts']);
    }
}
