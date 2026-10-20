<?php

namespace App\Http\Controllers\Api;

use App\Actions\RecordSyncEvents;
use App\Actions\ReplayStudentEvents;
use App\Http\Controllers\Controller;
use App\Http\Requests\SyncRequest;
use App\Models\SystemLog;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Throwable;

/**
 * POST /api/sync: batch upload of the client's offline event queue (FR-11).
 *
 * The client removes every id in `acknowledged` (stored now or earlier) and
 * every id in `rejected` (will never be accepted; keep a local copy for
 * debugging) from its queue. Anything else stays queued and is retried.
 *
 * After storing, the server replays the student's events through BKT and
 * updates the official state (D-010); the client reads it from /api/student/me.
 */
class SyncController extends Controller
{
    public function __invoke(SyncRequest $request, RecordSyncEvents $record, ReplayStudentEvents $replay): JsonResponse
    {
        $student = $request->user()->student;
        abort_if($student === null, 403);

        $events = $request->validated('events');
        $result = $record->handle($student, $events);

        if ($result['acknowledged'] !== []) {
            $replay->handle($student);
        }
        $this->logAnomalies($student->code, $events, $result['rejected']);

        return response()->json([
            ...$result,
            'server_time' => now()->utc()->toIso8601ZuluString(),
        ]);
    }

    /**
     * System log entries for the admin portal (FR-08): rejected events, UUIDs
     * owned by another student, and device clocks running ahead of the server.
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
