<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

/**
 * GET /api/config: remote config the game caches on the device (FR-19),
 * replacing Firebase Remote Config (D-001). Public: it holds no secrets and
 * the client may need it before a student signs in.
 */
class ConfigController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $bkt = config('reading_racoon.bkt');

        return response()->json([
            'content_version' => config('reading_racoon.content_version'),
            // Lets the client measure its clock offset (open issue 10).
            'server_time' => now()->utc()->toIso8601ZuluString(),
            'bkt' => [
                'version' => $bkt['version'],
                'mastery_p' => $bkt['mastery_p'],
                'mastery_min_attempts' => $bkt['mastery_min_attempts'],
                'hint_p' => $bkt['hint_p'],
                'demote_cap' => $bkt['demote_cap'],
                'skills' => $bkt['skills'],
            ],
            'sync' => [
                'max_batch' => config('reading_racoon.sync.max_batch'),
            ],
        ]);
    }
}
