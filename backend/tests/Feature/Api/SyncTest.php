<?php

namespace Tests\Feature\Api;

use App\Enums\SyncEventType;
use App\Models\Student;
use App\Models\SyncEvent;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * POST /api/sync: idempotent upload of the client's offline event queue (FR-11, D-008).
 */
class SyncTest extends TestCase
{
    use RefreshDatabase;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        $this->student = Student::factory()->create();
        Sanctum::actingAs($this->student->user);
    }

    /** One queued event, shaped like SaveStore.queue_event() in the Godot client. */
    private function event(string $type, array $payload, ?string $id = null, string $deviceTime = '2026-10-20T04:34:56Z'): array
    {
        return ['id' => $id ?? (string) Str::uuid(), 'type' => $type, 'payload' => $payload, 'device_time' => $deviceTime];
    }

    /** One of each event type, with payloads as lesson_session.gd and game_state.gd build them. */
    private function clientQueue(): array
    {
        return [
            $this->event('response', ['item_id' => 'ph2-03', 'skill' => 'phonics', 'level' => 2, 'answer' => 'b',
                'correct' => false, 'response_ms' => 2350, 'rescue' => false]),
            $this->event('bkt_state', ['skill' => 'phonics', 'level' => 2, 'p' => 0.2132075471698113,
                'posterior' => 0.0402930402930403, 'attempts' => 4, 'mastered' => false]),
            $this->event('hearts', ['hearts' => 0]),
            $this->event('rescue_start', ['skill' => 'phonics', 'level' => 2]),
            $this->event('rescue_end', ['skill' => 'phonics', 'correct' => 2, 'full' => false]),
            $this->event('flag', ['type' => 'rescue_partial', 'skill' => 'phonics', 'level' => 2,
                'correct' => 2, 'demoted_level' => 1]),
            $this->event('level_up', ['to_level' => 2], deviceTime: '2026-10-20T04:35:10Z'),
            $this->event('lesson_end', ['level' => 1, 'node' => 0, 'correct' => 7, 'total' => 8, 'stars' => 2],
                deviceTime: '2026-10-20T04:35:10Z'),
            $this->event('chest', ['level' => 1, 'coins' => 15], deviceTime: '2026-10-20T04:36:00Z'),
        ];
    }

    private function sync(array $events)
    {
        return $this->postJson('/api/sync', ['events' => $events]);
    }

    public function test_sync_needs_a_token_and_answers_json_without_an_accept_header(): void
    {
        $this->app['auth']->forgetGuards();

        $this->post('/api/sync', ['events' => []])
            ->assertUnauthorized()
            ->assertJsonPath('message', 'Unauthenticated.');
    }

    public function test_only_students_can_sync(): void
    {
        Sanctum::actingAs(User::factory()->create()); // a teacher

        $this->sync([$this->event('hearts', ['hearts' => 3])])->assertForbidden();
        $this->assertDatabaseCount('sync_events', 0);
    }

    public function test_the_client_queue_is_stored_and_every_id_acknowledged_in_order(): void
    {
        $queue = $this->clientQueue();

        $this->sync($queue)
            ->assertOk()
            ->assertJsonPath('acknowledged', array_column($queue, 'id'))
            ->assertJsonPath('rejected', [])
            ->assertJsonStructure(['server_time']);

        $rows = SyncEvent::orderBy('id')->get();
        $this->assertSame(array_column($queue, 'id'), $rows->pluck('uuid')->all());
        foreach ($queue as $i => $event) {
            $row = $rows[$i];
            $this->assertSame($this->student->id, $row->student_id);
            $this->assertSame(SyncEventType::from($event['type']), $row->type);
            $this->assertEquals($event['payload'], $row->payload);
            $this->assertTrue(CarbonImmutable::parse($event['device_time'])->equalTo($row->device_time));
            $this->assertNotNull($row->received_at);
        }

        // jsonb is queryable, e.g. for the teacher dashboard and the BKT replay.
        $this->assertSame(1, DB::table('sync_events')->where('payload->type', 'rescue_partial')->count());
    }

    public function test_device_time_is_stored_as_the_same_instant(): void
    {
        $event = $this->event('hearts', ['hearts' => 2], deviceTime: '2026-10-20T12:34:56+08:00');

        $this->sync([$event])->assertOk();

        $epoch = DB::selectOne('select extract(epoch from device_time)::bigint as e from sync_events')->e;
        $this->assertSame(CarbonImmutable::parse('2026-10-20T04:34:56Z')->getTimestamp(), (int) $epoch);
    }

    public function test_the_same_batch_twice_creates_no_duplicates(): void
    {
        $queue = $this->clientQueue();

        $this->sync($queue)->assertOk();
        // The response was lost, so the client sends the whole queue again.
        $this->sync($queue)
            ->assertOk()
            ->assertJsonPath('acknowledged', array_column($queue, 'id'))
            ->assertJsonPath('rejected', []);

        $this->assertDatabaseCount('sync_events', count($queue));
    }

    public function test_a_retry_with_new_events_stores_only_the_new_ones(): void
    {
        $first = $this->clientQueue();
        $this->sync($first)->assertOk();

        $more = [$this->event('hearts', ['hearts' => 3]), $this->event('hearts', ['hearts' => 2])];
        $this->sync([...$first, ...$more])
            ->assertOk()
            ->assertJsonPath('acknowledged', array_column([...$first, ...$more], 'id'));

        $this->assertDatabaseCount('sync_events', count($first) + 2);
    }

    public function test_a_duplicate_inside_one_batch_is_stored_once(): void
    {
        $event = $this->event('hearts', ['hearts' => 3]);

        $this->sync([$event, $event])
            ->assertOk()
            ->assertJsonPath('acknowledged', [$event['id'], $event['id']]);

        $this->assertDatabaseCount('sync_events', 1);
    }

    public function test_uppercase_ids_match_the_stored_lowercase_uuid(): void
    {
        $id = (string) Str::uuid();
        $this->sync([$this->event('hearts', ['hearts' => 3], $id)])->assertOk();

        $upper = strtoupper($id);
        $this->sync([$this->event('hearts', ['hearts' => 3], $upper)])
            ->assertOk()
            ->assertJsonPath('acknowledged', [$upper]);

        $this->assertDatabaseCount('sync_events', 1);
    }

    public function test_bad_events_are_rejected_one_by_one_and_the_rest_are_stored(): void
    {
        $good = $this->event('hearts', ['hearts' => 3]);
        $alsoGood = $this->event('chest', ['level' => 1, 'coins' => 15]);
        $batch = [
            $good,
            $this->event('hearts', ['hearts' => 3], id: 'not-a-uuid'),
            $this->event('dance_party', ['hearts' => 3]),
            ['id' => (string) Str::uuid(), 'type' => 'hearts', 'payload' => ['hearts' => 3]],
            $this->event('hearts', ['hearts' => 3], deviceTime: '2026-10-20 04:34:56'),
            $this->event('hearts', [1, 2, 3]),
            'just a string',
            $alsoGood,
        ];

        $response = $this->sync($batch)
            ->assertOk()
            ->assertJsonPath('acknowledged', [$good['id'], $alsoGood['id']]);

        $rejected = $response->json('rejected');
        $this->assertSame([1, 2, 3, 4, 5, 6], array_column($rejected, 'index'));
        $this->assertSame(['invalid'], array_unique(array_column($rejected, 'reason')));
        $this->assertSame('not-a-uuid', $rejected[0]['id']);
        $this->assertArrayHasKey('id', $rejected[0]['errors']);
        $this->assertArrayHasKey('type', $rejected[1]['errors']);
        $this->assertArrayHasKey('device_time', $rejected[2]['errors']);
        $this->assertArrayHasKey('device_time', $rejected[3]['errors']);
        $this->assertArrayHasKey('payload', $rejected[4]['errors']);
        $this->assertNull($rejected[5]['id']);

        $this->assertDatabaseCount('sync_events', 2);
    }

    public function test_an_id_already_stored_for_another_student_is_rejected(): void
    {
        $other = Student::factory()->create();
        $event = $this->event('hearts', ['hearts' => 3]);
        Sanctum::actingAs($other->user);
        $this->sync([$event])->assertOk();

        Sanctum::actingAs($this->student->user);
        $this->sync([$event])
            ->assertOk()
            ->assertJsonPath('acknowledged', [])
            ->assertJsonPath('rejected', [['index' => 0, 'id' => $event['id'], 'reason' => 'id_conflict']]);

        $this->assertSame([$other->id], SyncEvent::pluck('student_id')->all());
    }

    public function test_payload_strings_are_stored_exactly_as_sent(): void
    {
        // Laravel trims strings and turns "" into null by default; not for research data.
        $payload = ['item_id' => 'v2-01', 'answer' => '  cat ', 'note' => '', 'word' => 'bahay ñ'];

        $this->sync([$this->event('response', $payload)])->assertOk();

        $this->assertSame($payload['answer'], SyncEvent::sole()->payload['answer']);
        $this->assertEquals($payload, SyncEvent::sole()->payload);
    }

    public function test_an_empty_payload_is_stored_as_a_json_object(): void
    {
        $this->sync([$this->event('hearts', [])])->assertOk();

        $this->assertSame('object', DB::selectOne('select jsonb_typeof(payload) as t from sync_events')->t);
    }

    public function test_a_nul_character_rejects_that_event_instead_of_failing_the_batch(): void
    {
        $good = $this->event('hearts', ['hearts' => 3]);

        $this->sync([$this->event('response', ['answer' => "a\0b"]), $good])
            ->assertOk()
            ->assertJsonPath('acknowledged', [$good['id']])
            ->assertJsonPath('rejected.0.index', 0);

        $this->assertDatabaseCount('sync_events', 1);
    }

    public function test_oversized_payloads_are_rejected(): void
    {
        config(['reading_racoon.sync.max_payload_bytes' => 64]);

        $this->sync([$this->event('response', ['answer' => str_repeat('a', 100)])])
            ->assertOk()
            ->assertJsonPath('acknowledged', [])
            ->assertJsonPath('rejected.0.reason', 'invalid');
    }

    public function test_the_batch_envelope_is_validated(): void
    {
        config(['reading_racoon.sync.max_batch' => 2]);
        $three = [$this->event('hearts', []), $this->event('hearts', []), $this->event('hearts', [])];

        $this->sync($three)->assertUnprocessable()->assertJsonValidationErrors(['events']);
        $this->postJson('/api/sync', [])->assertUnprocessable()->assertJsonValidationErrors(['events']);
        $this->postJson('/api/sync', ['events' => ['a' => $this->event('hearts', [])]])
            ->assertUnprocessable()->assertJsonValidationErrors(['events']);

        $this->sync([])->assertOk()->assertJsonPath('acknowledged', []);
        $this->assertDatabaseCount('sync_events', 0);
    }
}
