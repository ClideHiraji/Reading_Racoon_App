<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\StudentItem;
use App\Support\SkillCatalog;
use App\Support\StudentReplay;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * GET /api/student/me: the official (server-replayed) state of the signed-in
 * student (FR-03, FR-07, FR-11, D-011). `model` has exactly the shape of the
 * client's StudentModel.to_dict(), so the game adopts it with from_dict():
 * the server wins on conflict (D-008).
 */
class StudentMeController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $student = $request->user()->student;
        abort_if($student === null, 403);
        $student->load(['section', 'bktStates', 'wallet', 'pathProgress', 'items']);

        $states = [];
        foreach ($student->bktStates as $st) {
            $states[StudentReplay::key($st->sub_skill, $st->level)] = [
                'p' => $st->p_mastery,
                'attempts' => $st->attempts,
                'mastered' => $st->mastered_at !== null,
                'review' => $st->review,
            ];
        }
        $highest = $student->pathProgress?->highest_unlocked ?? 1;
        $equipped = $student->items->where('equipped', true)
            ->mapWithKeys(fn (StudentItem $item) => [$item->slot ?? $item->item_id => $item->item_id]);

        return response()->json([
            'student' => [
                'id' => $student->id,
                'code' => $student->code,
                'name' => $student->user->name,
                'section' => ['id' => $student->section->id, 'name' => $student->section->name],
            ],
            'model' => ['states' => (object) $states, 'highest_unlocked' => $highest],
            'aral_band' => SkillCatalog::level($highest)['band'],
            'wallet' => ['xp' => $student->wallet?->xp ?? 0, 'coins' => $student->wallet?->coins ?? 0],
            'path' => ['worlds' => (object) ($student->pathProgress?->worlds ?? [])],
            'items' => $student->items->sortBy('acquired_at')->values()->map(fn (StudentItem $item) => [
                'item_id' => $item->item_id,
                'slot' => $item->slot,
                'equipped' => $item->equipped,
            ]),
            'equipped' => (object) $equipped->all(),
            'bkt_version' => config('reading_racoon.bkt.version'),
            'server_time' => now()->utc()->toIso8601ZuluString(),
        ]);
    }
}
