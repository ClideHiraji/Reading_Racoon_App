<?php

namespace App\Http\Controllers\Api;

use App\Actions\RecordSyncEvents;
use App\Http\Controllers\Controller;
use App\Http\Requests\SyncRequest;
use App\Jobs\ReplayStudent;
use App\Jobs\WriteAiReport;
use App\Models\SystemLog;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Throwable;

/**
 * POST /api/sync: uploads a batch of the game's offline event queue.
 *
 * The game removes every id in `acknowledged` (stored now or earlier) and every id in
 * `rejected` (will never be accepted; it keeps a local copy for debugging) from its queue.
 * Anything else stays queued and is sent again.
 *
 * After storing, a queued job (App\Jobs\ReplayStudent, a few seconds later) replays the
 * student's events through BKT and updates the official state; the game reads it from
 * /api/student/me.
 */
class SyncController extends Controller
{
    public function __invoke(SyncRequest $request, RecordSyncEvents $record): JsonResponse
    {
        $student = $request->user()->student;
        abort_if($student === null, 403);

        // The acknowledgement depends on one thing only: the events are saved in sync_events.
        // Everything after this is best-effort and must never turn a saved batch into an error
        // the device would retry forever.
        $events = $request->validated('events');
        $result = $record->handle($student, $events);

        if ($result['acknowledged'] !== []) {
            // Server BKT replay, in a queued job.
            ReplayStudent::after($student);
        }
        try {
            if ($result['stored'] !== []) {
                // The Gemini teacher report, a few minutes later.
                WriteAiReport::queueFor($student, afterSync: true);
            }
            $this->logNewEvents($student->code, $result['stored'], $request->user()->id);
            $this->logAnomalies($student->code, $events, $result['rejected']);
        } catch (Throwable $e) {
            report($e);
        }

        return response()->json([
            'acknowledged' => $result['acknowledged'],
            'rejected' => $result['rejected'],
            'server_time' => now()->utc()->toIso8601ZuluString(),
        ]);
    }

    /**
     * Events for the admin logs, written once when first stored: lock screens the device
     * showed while offline, and device clocks that jumped backwards.
     *
     * @param  list<array{uuid: string, type: string, payload: string}>  $stored
     */
    private function logNewEvents(?string $code, array $stored, int $userId): void
    {
        foreach ($stored as $event) {
            $payload = json_decode($event['payload'], true) ?: [];
            if ($event['type'] === 'access') {
                SystemLog::record('access.device', 'info', [
                    'student' => $code, 'status' => $payload['status'] ?? null, 'device_time' => $payload['time'] ?? null,
                ], userId: $userId);
            } elseif ($event['type'] === 'flag' && ($payload['type'] ?? null) === 'clock_jump') {
                SystemLog::record('sync.clock_jump', 'warning', [
                    'student' => $code, 'from' => $payload['from'] ?? null, 'to' => $payload['to'] ?? null,
                ], anomaly: true, userId: $userId);
            }
        }
    }

    /**
     * System log entries for the admin portal: rejected events, UUIDs owned by another student,
     * and device clocks running ahead of the server.
     *
     * @param  array<int, mixed>  $events
     * @param  list<array{reason: string}>  $rejected
     */
    private function logAnomalies(?string $code, array $events, array $rejected): void
    {
        $conflicts = count(array_filter($rejected, fn (array $r) => $r['reason'] === 'id_conflict'));
        if ($conflicts > 0) {
            SystemLog::record('sync.id_conflict', 'warning', ['student' => $code, 'events' => $conflicts], anomaly: true);
        }
        if (count($rejected) > $conflicts) {
            SystemLog::record('sync.rejected', 'warning', ['student' => $code, 'events' => count($rejected) - $conflicts]);
        }

        $limit = now()->addMinutes(config('reading_racoon.sync.clock_ahead_minutes'));
        $ahead = 0;
        foreach ($events as $event) {
            try {
                if (is_array($event) && is_string($event['device_time'] ?? null)
                    && CarbonImmutable::parse($event['device_time'])->greaterThan($limit)) {
                    $ahead++;
                }
            } catch (Throwable) {
                // Malformed times were already rejected by RecordSyncEvents.
            }
        }
        if ($ahead > 0) {
            SystemLog::record('sync.clock_ahead', 'warning', ['student' => $code, 'events' => $ahead], anomaly: true);
        }
    }
}
