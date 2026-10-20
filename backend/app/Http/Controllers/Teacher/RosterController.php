<?php

namespace App\Http\Controllers\Teacher;

use App\Actions\EnrollStudent;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Section;
use App\Models\Student;
use App\Models\User;
use App\Support\LoginCode;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

/**
 * Roster management (FR-16): add learners with a generated login code, give a
 * learner a new code, record parental consent, remove a learner. Login codes
 * are shown once and only their hash is stored (open issue 9).
 */
class RosterController extends Controller
{
    public function store(Request $request, Section $section, EnrollStudent $enroll): RedirectResponse
    {
        $data = $request->validate(['name' => ['required', 'string', 'max:50']]);

        ['student' => $student, 'login_code' => $code] = $enroll->handle($section, trim($data['name']));
        AuditLog::record($request->user(), 'student.add', ['student', $student->code], ['section_id' => $section->id]);

        return redirect()->route('teacher.sections.show', $section)
            ->with('new_code', ['name' => $student->user->name, 'student_code' => $student->code, 'login_code' => $code]);
    }

    public function newCode(Request $request, Student $student): RedirectResponse
    {
        do {
            $code = LoginCode::generate();
        } while (User::where('login_code_hash', LoginCode::hash($code))->exists());

        $student->user->forceFill(['login_code_hash' => LoginCode::hash($code)])->save();
        // The old code stops working; so do tablets still signed in with it.
        $student->user->tokens()->delete();
        AuditLog::record($request->user(), 'student.new_code', ['student', $student->code]);

        return back()->with('new_code', ['name' => $student->user->name, 'student_code' => $student->code, 'login_code' => LoginCode::format($code)]);
    }

    public function consent(Request $request, Student $student): RedirectResponse
    {
        $given = $request->boolean('consent');
        $student->forceFill([
            'consent_recorded_at' => $given ? now() : null,
            'consent_recorded_by' => $given ? $request->user()->id : null,
        ])->save();
        AuditLog::record($request->user(), $given ? 'student.consent_recorded' : 'student.consent_cleared', ['student', $student->code]);

        return back()->with('status', $given
            ? "Parental consent recorded for {$student->displayName()}."
            : "Consent record cleared for {$student->displayName()}.");
    }

    public function destroy(Request $request, Student $student): RedirectResponse
    {
        $section = $student->section;
        $name = $student->displayName();
        AuditLog::record($request->user(), 'student.remove', ['student', $student->code], ['section_id' => $section->id]);
        // Deleting the user cascades to the student, their BKT states, events and flags (RA 10173).
        $student->user->delete();

        return redirect()->route('teacher.sections.show', $section)->with('status', "{$name} was removed and their data deleted.");
    }
}
