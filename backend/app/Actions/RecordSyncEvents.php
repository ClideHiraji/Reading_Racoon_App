<?php

namespace App\Actions;

use App\Enums\SyncEventType;
use App\Models\Student;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use stdClass;

/**
 * Stores a batch of queued client events idempotently (FR-11,
 * docs/knowledge/03-architecture.md "Offline and sync", D-008).
 *
 * - Each event is checked on its own, so one bad event never blocks the queue.
 * - Inserts use ON CONFLICT DO NOTHING on the client UUID: a retried batch
 *   (or the same event twice in one batch) is stored once and acknowledged
 *   again. The first copy wins.
 * - An id already stored for another student is rejected as `id_conflict`
 *   instead of being acknowledged for the wrong learner.
 */
final class RecordSyncEvents
{
    /** ISO 8601 with a required offset, e.g. 2026-10-20T04:34:56Z (Godot's UTC time + "Z"). */
    private const DEVICE_TIME = '/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$/';

    /**
     * @param  array<int, mixed>  $events  [{id, type, payload, device_time}, ...] in queue order
     * @return array{
     *     acknowledged: list<string>,
     *     rejected: list<array{index: int, id: string|null, reason: string, errors?: array<string, list<string>>}>
     * }
     */
    public function handle(Student $student, array $events): array
    {
        $rows = [];      // lowercase uuid => row to insert (first copy wins)
        $accepted = [];  // batch index => [lowercase uuid, id as the client sent it]
        $rejected = [];

        foreach (array_values($events) as $index => $event) {
            $errors = $this->errors($event, $payloadJson);
            if ($errors !== []) {
                $rejected[] = [
                    'index' => $index,
                    'id' => is_array($event) && is_string($event['id'] ?? null) ? $event['id'] : null,
                    'reason' => 'invalid',
                    'errors' => $errors,
                ];

                continue;
            }

            $uuid = strtolower($event['id']);
            $rows[$uuid] ??= [
                'uuid' => $uuid,
                'student_id' => $student->id,
                'type' => $event['type'],
                'payload' => $payloadJson,
                'device_time' => CarbonImmutable::parse($event['device_time'])->utc()->format('Y-m-d H:i:s.uP'),
            ];
            $accepted[$index] = [$uuid, $event['id']];
        }

        foreach (array_chunk(array_values($rows), 500) as $chunk) {
            DB::table('sync_events')->insertOrIgnore($chunk);
        }

        $owners = $rows === [] ? collect() : DB::table('sync_events')
            ->whereIn('uuid', array_keys($rows))
            ->pluck('student_id', 'uuid');

        $acknowledged = [];
        foreach ($accepted as $index => [$uuid, $id]) {
            $owner = $owners[$uuid] ?? null;
            if ($owner === null) {
                // Not stored (deleted meanwhile): neither acknowledged nor rejected,
                // so the client keeps it and retries.
                continue;
            }
            if ((int) $owner === $student->id) {
                $acknowledged[] = $id;
            } else {
                $rejected[] = ['index' => $index, 'id' => $id, 'reason' => 'id_conflict'];
            }
        }

        usort($rejected, fn (array $a, array $b) => $a['index'] <=> $b['index']);

        return ['acknowledged' => $acknowledged, 'rejected' => $rejected];
    }

    /**
     * Validation errors for one event (empty when valid). On success
     * $payloadJson holds the payload encoded for the jsonb column.
     *
     * @return array<string, list<string>>
     */
    private function errors(mixed $event, ?string &$payloadJson): array
    {
        $payloadJson = null;
        if (! is_array($event)) {
            return ['event' => ['Each event must be a JSON object.']];
        }

        $validator = Validator::make($event, [
            'id' => ['required', 'string', 'uuid'],
            'type' => ['required', 'string', Rule::enum(SyncEventType::class)],
            'payload' => ['present', 'array'],
            'device_time' => ['required', 'string', 'regex:'.self::DEVICE_TIME, 'date'],
        ]);
        if ($validator->fails()) {
            return $validator->errors()->toArray();
        }

        $payload = $event['payload'];
        if ($payload !== [] && array_is_list($payload)) {
            return ['payload' => ['The payload must be a JSON object.']];
        }
        // PostgreSQL jsonb rejects \u0000, which would fail the whole batch.
        if (self::containsNul($payload)) {
            return ['payload' => ['The payload must not contain NUL characters.']];
        }

        // An empty payload decodes to [], which would be stored as a JSON array.
        $json = json_encode($payload === [] ? new stdClass : $payload,
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION);
        $max = config('reading_racoon.sync.max_payload_bytes');
        if ($json === false || strlen($json) > $max) {
            return ['payload' => ["The payload must be valid JSON of at most {$max} bytes."]];
        }

        $payloadJson = $json;

        return [];
    }

    /**
     * @param  array<array-key, mixed>  $data
     */
    private static function containsNul(array $data): bool
    {
        foreach ($data as $key => $value) {
            if (str_contains((string) $key, "\0")
                || (is_string($value) && str_contains($value, "\0"))
                || (is_array($value) && self::containsNul($value))) {
                return true;
            }
        }

        return false;
    }
}
