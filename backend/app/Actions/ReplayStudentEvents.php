<?php

namespace App\Actions;

use App\Models\AccessSchedule;
use App\Models\Student;
use App\Support\StudentReplay;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use stdClass;

/**
 * Server-side BKT authority (FR-03, FR-11, D-008, D-010): replays every stored
 * event of one student through App\Support\StudentReplay and writes the result
 * over the projections: bkt_states, path_progress, student_wallets,
 * intervention_flags, student_items and daily_usage. The server wins on
 * conflict; the client adopts it from GET /api/student/me.
 *
 * A full replay (not incremental) keeps it simple and lets new BKT parameters
 * be applied to old answers. A whole study is ~1,500 events per student, which
 * replays in milliseconds.
 */
final class ReplayStudentEvents
{
    /** Replays and stores the official state. */
    public function handle(Student $student): StudentReplay
    {
        return DB::transaction(function () use ($student) {
            // Two syncs from the same student must not interleave their writes.
            DB::table('students')->where('id', $student->id)->lockForUpdate()->value('id');

            $replay = $this->replay($student);
            $this->store($student, $replay);

            return $replay;
        });
    }

    /** Replays without writing anything (profile chart, reports, research export). */
    public function replay(Student $student): StudentReplay
    {
        $schedule = AccessSchedule::forSection($student->section_id);
        $replay = new StudentReplay(fn (CarbonImmutable $time) => $schedule->inClassWindow($time));

        return $replay->run(
            DB::table('sync_events')
                ->where('student_id', $student->id)
                ->select(['id', 'uuid', 'type', 'payload', 'device_time'])
                ->lazyById(1000)
        );
    }

    private function store(Student $student, StudentReplay $replay): void
    {
        $now = now();
        $id = $student->id;

        $rows = [];
        foreach ($replay->states as $key => $st) {
            [$skill, $level] = explode(':', $key);
            $rows[] = [
                'student_id' => $id, 'sub_skill' => $skill, 'level' => (int) $level,
                'p_mastery' => $st['p'], 'attempts' => $st['attempts'],
                'mastered_at' => $st['mastered_at'], 'review' => $st['review'],
                'created_at' => $now, 'updated_at' => $now,
            ];
        }
        DB::table('bkt_states')->upsert($rows, ['student_id', 'sub_skill', 'level'],
            ['p_mastery', 'attempts', 'mastered_at', 'review', 'updated_at']);

        DB::table('path_progress')->upsert([[
            'student_id' => $id,
            'highest_unlocked' => $replay->highestUnlocked,
            // Always a JSON object, like PathProgress.worlds in the client.
            'worlds' => json_encode($replay->worlds === [] ? new stdClass : $replay->worlds),
            'created_at' => $now, 'updated_at' => $now,
        ]], ['student_id'], ['highest_unlocked', 'worlds', 'updated_at']);

        DB::table('student_wallets')->upsert([[
            'student_id' => $id, 'xp' => $replay->xp, 'coins' => $replay->coins,
            'created_at' => $now, 'updated_at' => $now,
        ]], ['student_id'], ['xp', 'coins', 'updated_at']);

        // New flags only: a flag the teacher already resolved stays resolved.
        $flags = [];
        foreach ($replay->flags as $uuid => $flag) {
            $flags[] = [
                'id' => $uuid, 'student_id' => $id, 'type' => $flag['type'],
                'sub_skill' => $flag['sub_skill'], 'level' => $flag['level'],
                'details' => json_encode($flag['details'] === [] ? new stdClass : $flag['details']),
                'status' => 'open', 'raised_at' => $flag['raised_at'],
                'created_at' => $now, 'updated_at' => $now,
            ];
        }
        foreach (array_chunk($flags, 500) as $chunk) {
            DB::table('intervention_flags')->insertOrIgnore($chunk);
        }

        DB::table('student_items')->where('student_id', $id)
            ->whereNotIn('item_id', array_keys($replay->items))->delete();
        $items = [];
        foreach ($replay->items as $itemId => $item) {
            $items[] = [
                'student_id' => $id, 'item_id' => $itemId, 'slot' => $item['slot'],
                'equipped' => in_array($itemId, $replay->equipped, true), 'cost' => $item['cost'],
                'acquired_at' => $item['acquired_at'], 'created_at' => $now, 'updated_at' => $now,
            ];
        }
        if ($items !== []) {
            DB::table('student_items')->upsert($items, ['student_id', 'item_id'],
                ['slot', 'equipped', 'cost', 'acquired_at', 'updated_at']);
        }

        $usage = [];
        foreach ($replay->usage as $date => $day) {
            $usage[] = [
                'student_id' => $id, 'date' => $date, 'minutes' => $day['minutes'],
                'class_minutes' => $day['class_minutes'], 'created_at' => $now, 'updated_at' => $now,
            ];
        }
        if ($usage !== []) {
            DB::table('daily_usage')->upsert($usage, ['student_id', 'date'], ['minutes', 'class_minutes', 'updated_at']);
        }
    }
}
