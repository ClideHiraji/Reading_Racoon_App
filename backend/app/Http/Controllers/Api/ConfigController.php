<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

/**
 * GET /api/config: settings the game saves on the device.
 * Public: it holds no secrets, and the game may need it before a student signs in.
 */
class ConfigController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $bkt = config('reading_racoon.bkt');

        return response()->json([
            'content_version' => config('reading_racoon.content_version'),
            // The game shows the post-test only while this is true.
            'post_test_open' => config('reading_racoon.post_test_open'),
            // Lets the game work out how far its clock is off.
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
