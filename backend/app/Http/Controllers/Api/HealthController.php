<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\Ops;
use Illuminate\Http\JsonResponse;

/**
 * GET /api/health: for an outside uptime monitor (NFR-02, D-036,
 * docs/deploy/home-server.md). 200 while the database answers; 503 when it
 * doesn't, so the monitor alerts. `degraded` means the API works but the
 * queue worker or the scheduler has stopped (the teacher dashboard then goes
 * stale and backups stop). Public, so it says nothing more than that.
 *
 * Laravel's own /up only proves PHP runs; this also proves the data path.
 */
class HealthController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $db = Ops::databaseUp();
        $lag = $db ? Ops::queueLag() : null;
        // The beat lives in the cache, which is the database: don't ask it when that's down.
        $scheduler = $db ? Ops::sinceBeat('scheduler') : null;

        $workerOk = $lag === null || $lag <= Ops::QUEUE_LAG_LIMIT;
        $schedulerOk = $scheduler !== null && $scheduler <= Ops::SCHEDULER_LIMIT;

        return response()->json([
            'status' => ! $db ? 'down' : ($workerOk && $schedulerOk ? 'ok' : 'degraded'),
            'database' => $db,
            'queue_worker' => $db ? $workerOk : null,
            'scheduler' => $schedulerOk,
            'server_time' => now()->utc()->toIso8601ZuluString(),
        ], $db ? 200 : 503)->header('Cache-Control', 'no-store');
    }
}
