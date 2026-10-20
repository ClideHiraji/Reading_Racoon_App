<?php

namespace App\Http\Controllers\Api;

use App\Actions\RecordSyncEvents;
use App\Http\Controllers\Controller;
use App\Http\Requests\SyncRequest;
use Illuminate\Http\JsonResponse;

/**
 * POST /api/sync: batch upload of the client's offline event queue (FR-11).
 *
 * The client removes every id in `acknowledged` (stored now or earlier) and
 * every id in `rejected` (will never be accepted; keep a local copy for
 * debugging) from its queue. Anything else stays queued and is retried.
 */
class SyncController extends Controller
{
    public function __invoke(SyncRequest $request, RecordSyncEvents $record): JsonResponse
    {
        $student = $request->user()->student;
        abort_if($student === null, 403);

        $result = $record->handle($student, $request->validated('events'));

        return response()->json([
            ...$result,
            'server_time' => now()->utc()->toIso8601ZuluString(),
        ]);
    }
}
