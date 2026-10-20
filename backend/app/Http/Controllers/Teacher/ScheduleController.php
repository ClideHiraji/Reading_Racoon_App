<?php

namespace App\Http\Controllers\Teacher;

use App\Http\Controllers\Controller;
use App\Models\AccessSchedule;
use App\Models\AuditLog;
use App\Models\Section;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Validator;
use Illuminate\View\View;

/**
 * Schedule editor for a section (FR-12): class window, after-school window,
 * daily after-school minutes and the weekend toggle. The game reads it from
 * GET /api/access/student/status.
 */
class ScheduleController extends Controller
{
    public function edit(Section $section): View
    {
        return view('teacher.schedule', [
            'section' => $section,
            'schedule' => AccessSchedule::forSection($section->id),
            'timezone' => config('reading_racoon.access.timezone'),
        ]);
    }

    public function update(Request $request, Section $section): RedirectResponse
    {
        $time = ['required', 'date_format:H:i'];
        $validator = validator($request->all(), [
            'class_start' => $time,
            'class_end' => [...$time, 'after:class_start'],
            'after_school_start' => $time,
            'after_school_end' => [...$time, 'after:after_school_start'],
            'daily_minutes' => ['required', 'integer', 'between:0,240'],
        ], [
            'class_end.after' => 'The class must end after it starts.',
            'after_school_end.after' => 'The after-school window must end after it starts.',
        ]);
        $validator->after(function (Validator $v) use ($request) {
            if ($v->errors()->isNotEmpty()) {
                return;
            }
            $overlap = $request->input('class_start') < $request->input('after_school_end')
                && $request->input('after_school_start') < $request->input('class_end');
            if ($overlap) {
                $v->errors()->add('after_school_start', 'The class and after-school windows must not overlap.');
            }
        });
        $data = $validator->validate();

        $schedule = AccessSchedule::forSection($section->id);
        $schedule->fill([...$data, 'weekends_open' => $request->boolean('weekends_open')]);
        $schedule->updated_by = $request->user()->id;
        $schedule->save();
        AuditLog::record($request->user(), 'schedule.update', $section, $schedule->toApi());

        return redirect()->route('teacher.sections.show', $section)->with('status', 'Play schedule saved. Tablets pick it up at their next access check.');
    }
}
