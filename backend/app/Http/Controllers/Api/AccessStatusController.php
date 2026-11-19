<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AccessSchedule;
use App\Models\DailyUsage;
use App\Models\SystemLog;
use App\Support\AccessDecider;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * GET /api/access/student/status (FR-12, docs/knowledge/06-game-design.md):
 * the section's schedule and today's decision. The game calls it at login and
 * at every screen transition, shows the raccoon lock screen when play isn't
 * allowed, and caches `schedule` + `server_time` for offline play (open issue 10).
 * Every decision is written to the system log.
 */
class AccessStatusController extends Controller
{
    public function __invoke(Request $request, AccessDecider $decider): JsonResponse
    {
        $student = $request->user()->student;
        abort_if($student === null, 403);

        $now = CarbonImmutable::now()->utc();
        $today = $now->setTimezone(config('reading_racoon.access.timezone'))->toDateString();
        $schedule = AccessSchedule::forSection($student->section_id);
        $used = (int) DailyUsage::where('student_id', $student->id)->whereDate('date', $today)->value('minutes');

        $decision = $decider->decide($schedule, $used, $now);

        SystemLog::record('access.check', 'info', [
            'student' => $student->code,
            'status' => $decision['status']->value,
            'minutes_left' => $decision['minutes_left'],
        ], userId: $request->user()->id);

        return response()->json([
            'status' => $decision['status']->value,
            'minutes_left' => $decision['minutes_left'],
            'server_time' => $now->toIso8601ZuluString(),
            'window' => $decision['window'],
            'opens_at' => $decision['opens_at'],
            'used_minutes' => $used,
            'schedule' => $schedule->toApi(),
        ]);
    }
}
