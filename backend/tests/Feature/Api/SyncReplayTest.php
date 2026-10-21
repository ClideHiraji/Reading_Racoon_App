<?php

namespace Tests\Feature\Api;

use App\Actions\EnrollStudent;
use App\Models\InterventionFlag;
use App\Models\Section;
use App\Models\Student;
use App\Models\SystemLog;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * After POST /api/sync the server replays the student's events and stores the
 * official state (FR-03, FR-11, FR-17, D-008, D-011).
 */
class SyncReplayTest extends TestCase
{
    use RefreshDatabase;

    private Student $student;

    private int $second = 0;

    protected function setUp(): void
    {
        parent::setUp();

        $this->student = app(EnrollStudent::class)->handle(Section::factory()->create(), 'Ana')['student'];
        Sanctum::actingAs($this->student->user);
    }

    private function event(string $type, array $payload): array
    {
        $time = now()->subHour()->addSeconds($this->second++)->utc()->format('Y-m-d\TH:i:s\Z');

        return ['id' => (string) Str::uuid(), 'type' => $type, 'payload' => $payload, 'device_time' => $time];
    }

    private function answers(string $skill, int $level, int $times, bool $correct = true): array
    {
        return array_map(fn () => $this->event('response', ['item_id' => 'x', 'skill' => $skill, 'level' => $level,
            'answer' => 'a', 'correct' => $correct, 'response_ms' => 900, 'rescue' => false, 'num_choices' => 3]), range(1, $times));
    }

    public function test_synced_answers_update_the_bkt_states_level_and_wallet(): void
    {
        $this->postJson('/api/sync', ['events' => [
            ...$this->answers('phonological_awareness', 1, 5),
            ...$this->answers('phonics', 1, 5),
            $this->event('lesson_end', ['level' => 1, 'node' => 0, 'correct' => 8, 'total' => 8, 'stars' => 3]),
        ]])->assertOk();

        $states = $this->student->bktStates()->get()->keyBy(fn ($s) => "$s->sub_skill:$s->level");
        $this->assertSame(5, $states['phonics:1']->attempts);
        $this->assertNotNull($states['phonics:1']->mastered_at);
        $this->assertGreaterThan(0.95, $states['phonological_awareness:1']->p_mastery);
        $this->assertSame(0, $states['phonics:2']->attempts);

        $this->assertSame(2, $this->student->pathProgress()->first()->highest_unlocked);
        $wallet = $this->student->wallet()->first();
        $this->assertSame([80, 15 + 20], [$wallet->xp, $wallet->coins]);
    }

    public function test_the_same_batch_twice_gives_the_same_state(): void
    {
        $batch = [...$this->answers('phonics', 1, 3), $this->event('chest', ['level' => 1, 'coins' => 15])];

        $this->postJson('/api/sync', ['events' => $batch])->assertOk();
        $first = $this->student->bktStates()->orderBy('id')->pluck('p_mastery')->all();
        $this->postJson('/api/sync', ['events' => $batch])->assertOk();

        $this->assertSame($first, $this->student->bktStates()->orderBy('id')->pluck('p_mastery')->all());
        $this->assertSame(15, $this->student->wallet()->first()->coins);
    }

    public function test_flags_become_teacher_alerts_and_a_resolved_flag_stays_resolved(): void
    {
        $flag = $this->event('flag', ['type' => 'rescue_partial', 'skill' => 'phonics', 'level' => 2, 'correct' => 1, 'demoted_level' => 1]);
        $this->postJson('/api/sync', ['events' => [$flag]])->assertOk();

        $stored = InterventionFlag::findOrFail($flag['id']);
        $this->assertSame(['rescue_partial', 'phonics', 2, 'open'], [$stored->type, $stored->sub_skill, $stored->level, $stored->status]);
        $this->assertSame(['correct' => 1, 'demoted_level' => 1], $stored->details);

        $stored->forceFill(['status' => 'resolved', 'resolved_at' => now()])->save();
        $this->postJson('/api/sync', ['events' => [$this->event('hearts', ['hearts' => 3])]])->assertOk();

        $this->assertSame('resolved', $stored->fresh()->status);
    }

    public function test_five_wrong_answers_raise_a_low_mastery_flag(): void
    {
        $this->postJson('/api/sync', ['events' => $this->answers('vocabulary', 2, 6, correct: false)])->assertOk();

        $flag = InterventionFlag::sole();
        $this->assertSame(['low_mastery', 'vocabulary', 2], [$flag->type, $flag->sub_skill, $flag->level]);
    }

    public function test_purchases_outfit_and_usage_are_projected(): void
    {
        $this->postJson('/api/sync', ['events' => [
            $this->event('chest', ['level' => 1, 'coins' => 15]),
            $this->event('chest', ['level' => 2, 'coins' => 15]),
            $this->event('purchase', ['item' => 'cap', 'price' => 30, 'coins_left' => 0]),
            $this->event('outfit', ['equipped' => ['hat' => 'cap', 'neck' => 'scarf_teal']]),
            $this->event('usage', ['date' => '2026-10-20', 'minutes' => 6.2]),
            $this->event('usage', ['date' => '2026-10-20', 'minutes' => 10.4]),
        ]])->assertOk();

        $items = $this->student->items()->orderBy('item_id')->get()
            ->map(fn ($i) => [$i->item_id, $i->slot, $i->equipped, $i->cost])->all();
        $this->assertSame([['cap', 'hat', true, 30], ['scarf_teal', 'neck', true, 0]], $items);
        $this->assertSame(0, $this->student->wallet()->first()->coins);
        $this->assertSame(10, $this->student->dailyUsage()->sole()->minutes);
    }

    public function test_the_pre_test_places_the_learner_and_its_scores_are_kept(): void
    {
        $pre = fn (string $skill, int $level) => $this->event('response', ['item_id' => 'pre-1', 'skill' => $skill, 'level' => $level,
            'answer' => 'a', 'correct' => true, 'response_ms' => 900, 'assessment' => 'pre']);
        $this->postJson('/api/sync', ['events' => [
            $pre('phonological_awareness', 1), $pre('phonological_awareness', 1), $pre('phonological_awareness', 1),
            $pre('phonics', 1), $pre('phonics', 1), $pre('phonics', 1),
            $this->event('placement', ['start_level' => 2]),
            $this->event('assessment', ['kind' => 'pre', 'scores' => ['phonological_awareness' => ['correct' => 3, 'total' => 3],
                'phonics' => ['correct' => 3, 'total' => 3]], 'correct' => 6, 'total' => 6]),
        ]])->assertOk()->assertJsonCount(0, 'rejected');

        $this->assertSame(2, $this->student->pathProgress()->first()->highest_unlocked);
        $this->assertNotNull($this->student->bktStates()->where('sub_skill', 'phonics')->where('level', 1)->value('mastered_at'));
        $this->assertSame(0, InterventionFlag::count());
    }

    public function test_lock_screens_and_clock_jumps_reach_the_admin_logs_once(): void
    {
        $batch = [
            $this->event('access', ['status' => 'class_lock', 'time' => '2026-10-20T10:00:00']),
            $this->event('flag', ['type' => 'clock_jump', 'from' => 1760954400, 'to' => 1760868000]),
        ];

        $this->postJson('/api/sync', ['events' => $batch])->assertOk()->assertJsonCount(2, 'acknowledged');
        $this->postJson('/api/sync', ['events' => $batch])->assertOk(); // a retry logs nothing new

        $access = SystemLog::where('event', 'access.device')->sole();
        $this->assertSame(['class_lock', $this->student->code], [$access->context['status'], $access->context['student']]);
        $this->assertFalse($access->anomaly);
        $jump = SystemLog::where('event', 'sync.clock_jump')->sole();
        $this->assertTrue($jump->anomaly);
        $this->assertSame(0, InterventionFlag::count(), 'a clock jump is not a reading flag for the teacher');
    }

    public function test_every_event_type_the_game_sends_is_accepted(): void
    {
        $types = ['response', 'bkt_state', 'hearts', 'rescue_start', 'rescue_end', 'level_up', 'flag', 'lesson_end', 'chest',
            'placement', 'assessment', 'usage', 'purchase', 'outfit', 'access'];

        $this->postJson('/api/sync', ['events' => array_map(fn ($t) => $this->event($t, []), $types)])
            ->assertOk()->assertJsonCount(count($types), 'acknowledged')->assertJsonCount(0, 'rejected');
        $this->postJson('/api/sync', ['events' => [$this->event('equip', [])]])->assertJsonPath('rejected.0.reason', 'invalid');
    }

    public function test_a_device_clock_ahead_of_the_server_is_logged_as_an_anomaly(): void
    {
        $ahead = $this->event('hearts', ['hearts' => 3]);
        $ahead['device_time'] = now()->addDay()->utc()->format('Y-m-d\TH:i:s\Z');

        $this->postJson('/api/sync', ['events' => [$ahead]])->assertOk();

        $log = SystemLog::where('event', 'sync.clock_ahead')->sole();
        $this->assertTrue($log->anomaly);
        $this->assertSame($this->student->code, $log->context['student']);
    }
}
