<?php

namespace App\Http\Controllers\Teacher;

use App\Actions\ReplayStudentEvents;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\InterventionFlag;
use App\Models\Student;
use App\Support\SectionStats;
use App\Support\SkillCatalog;
use App\Support\SkillHistory;
use Illuminate\Database\Eloquent\Collection;
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

        // One line per (sub-skill, level) state: P(L) after each answer, by answer number.
        $series = [];
        foreach ($replay->history as $i => $h) {
            $series["{$h['skill']}:{$h['level']}"][] = ['x' => $i + 1, 'y' => round($h['p'], 4), 'level' => $h['level'], 'correct' => $h['correct']];
        }

        // Previous / next learner in the section, by name, for moving through a class.
        $siblings = $student->section->students()->with('user')->get()
            ->sortBy(fn (Student $s) => mb_strtolower($s->displayName()))->values();
        $index = $siblings->search(fn (Student $s) => $s->is($student));

        return view('teacher.student', [
            'student' => $student,
            'replay' => $replay,
            'series' => $series,
            'histories' => SkillHistory::build($replay->history),
            'previous' => $index > 0 ? $siblings[$index - 1] : null,
            'next' => $siblings[$index + 1] ?? null,
            'lastPlayed' => $student->syncEvents()->max('device_time'),
            // The server's own clock: tells "hasn't played" from "hasn't synced" (D-037).
            'lastSynced' => $student->syncEvents()->max('received_at'),
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

        return $this->backTo($request)->with('status', 'Resolved: '.$this->describe($flag).'.')->with('undo_flag', $flag->id);
    }

    /**
     * Resolves several flags at once (FR-17, D-037): one skill-level's flags,
     * or every flag in a section that looks better. Only the teacher's own
     * flags are touched; anything else is ignored.
     */
    public function resolveFlags(Request $request): RedirectResponse
    {
        $flags = $this->ownFlags($request, 'open');
        foreach ($flags as $flag) {
            $flag->forceFill(['status' => 'resolved', 'resolved_at' => now(), 'resolved_by' => $request->user()->id])->save();
            AuditLog::record($request->user(), 'flag.resolve', ['intervention_flag', $flag->id],
                ['student' => $flag->student->code, 'type' => $flag->type, 'bulk' => true]);
        }
        $children = $flags->pluck('student_id')->unique()->count();
        $message = match (true) {
            $flags->isEmpty() => 'Nothing to resolve: those flags were already closed.',
            $children === 1 => 'Resolved: '.$flags->map(fn ($f) => $this->describe($f))->unique()->join('; ').'.',
            default => "Closed {$flags->count()} flags for {$children} children.",
        };

        return $this->backTo($request)->with('status', $message)->with('undo_flags', $flags->pluck('id')->all());
    }

    /** Undo of a bulk resolve: the flags are open again. */
    public function reopenFlags(Request $request): RedirectResponse
    {
        $flags = $this->ownFlags($request, 'resolved');
        foreach ($flags as $flag) {
            $flag->forceFill(['status' => 'open', 'resolved_at' => null, 'resolved_by' => null])->save();
            AuditLog::record($request->user(), 'flag.reopen', ['intervention_flag', $flag->id],
                ['student' => $flag->student->code, 'type' => $flag->type, 'bulk' => true]);
        }

        return $this->backTo($request)->with('status', $flags->count() === 1 ? 'Flag opened again.' : "{$flags->count()} flags opened again.");
    }

    /** @return Collection<int, InterventionFlag> the teacher's own flags among the posted ids */
    private function ownFlags(Request $request, string $status): Collection
    {
        $ids = array_slice(array_values(array_filter((array) $request->input('ids', []), 'is_string')), 0, 500);

        return InterventionFlag::with('student.user', 'student.section')->whereIn('id', $ids)->where('status', $status)->get()
            ->filter(fn (InterventionFlag $flag) => $request->user()->can('update', $flag))->values();
    }

    /** "Jasmine: Keeps missing a skill, Phonics L1" for flash messages. */
    private function describe(InterventionFlag $flag): string
    {
        $label = SectionStats::FLAG_STYLES[$flag->type][2] ?? str_replace('_', ' ', $flag->type);

        return $flag->student->displayName().': '.$label
            .($flag->sub_skill ? ', '.SkillCatalog::label($flag->sub_skill) : '').($flag->level ? ' L'.$flag->level : '');
    }

    /** Back to the page the teacher came from, at the part they were working in. */
    private function backTo(Request $request): RedirectResponse
    {
        $anchor = in_array($request->input('anchor'), ['needs-help', 'looks-better', 'flags'], true) ? '#'.$request->input('anchor') : '';

        return redirect()->to(strtok(url()->previous(), '#').$anchor);
    }

    /** Undo of "Mark resolved" (FR-17): the flag is open again. */
    public function reopenFlag(Request $request, InterventionFlag $flag): RedirectResponse
    {
        $flag->forceFill(['status' => 'open', 'resolved_at' => null, 'resolved_by' => null])->save();
        AuditLog::record($request->user(), 'flag.reopen', ['intervention_flag', $flag->id],
            ['student' => $flag->student->code, 'type' => $flag->type]);

        return $this->backTo($request)->with('status', 'Flag opened again.');
    }
}
