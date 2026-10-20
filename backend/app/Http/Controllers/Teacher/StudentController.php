<?php

namespace App\Http\Controllers\Teacher;

use App\Actions\ReplayStudentEvents;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\InterventionFlag;
use App\Models\Student;
use App\Support\SectionStats;
use App\Support\SkillCatalog;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * Student profile (FR-06, FR-17): BKT chart over time, the 14 states,
 * session history, Racoon's Rescue outcomes, flags and play time.
 */
class StudentController extends Controller
{
    public function show(Request $request, Student $student, ReplayStudentEvents $replayer): View
    {
        $student->load(['user', 'section', 'bktStates', 'wallet', 'pathProgress', 'items']);
        $replay = $replayer->replay($student);
        AuditLog::record($request->user(), 'student.view', ['student', $student->code]);

        // One dataset per sub-skill: P(L) of the state each answer updated, by answer number.
        $series = [];
        foreach ($replay->history as $i => $h) {
            $series[$h['skill']][] = ['x' => $i + 1, 'y' => round($h['p'], 4), 'level' => $h['level'],
                'correct' => $h['correct'], 'pre' => $h['assessment'] === 'pre'];
        }

        return view('teacher.student', [
            'student' => $student,
            'replay' => $replay,
            'series' => $series,
            'band' => SectionStats::band($student),
            'states' => $student->bktStates->sortBy(fn ($s) => [array_search($s->sub_skill, SkillCatalog::skills(), true), $s->level]),
            'flags' => $student->interventionFlags()->orderByDesc('raised_at')->get(),
            'usage' => $student->dailyUsage()->orderByDesc('date')->limit(14)->get(),
            'timezone' => config('reading_racoon.access.timezone'),
        ]);
    }

    public function resolveFlag(Request $request, InterventionFlag $flag): RedirectResponse
    {
        $flag->forceFill(['status' => 'resolved', 'resolved_at' => now(), 'resolved_by' => $request->user()->id])->save();
        AuditLog::record($request->user(), 'flag.resolve', ['intervention_flag', $flag->id],
            ['student' => $flag->student->code, 'type' => $flag->type]);

        return back()->with('status', 'Flag marked as resolved.');
    }
}
