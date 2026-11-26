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
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * The class list: add learners with a new login code, give a learner a new code, record
 * parental consent, remove a learner. Login codes are shown once and only their hash is kept:
 * right after adding learners or making a new code, the class page shows them as printable
 * cut-out cards, and never again.
 */
class RosterController extends Controller
{
    /** Most learners added in one go (a big class plus a few spares). */
    public const MAX_NAMES = 60;

    /**
     * Adds one learner (`name`) or a whole class (`names`, one per line).
     * All or nothing: a bad line adds nobody, so no half class has codes
     * nobody saw.
     */
    public function store(Request $request, Section $section, EnrollStudent $enroll): RedirectResponse
    {
        $names = collect(preg_split('/\R/', (string) $request->input('names', $request->input('name', ''))))
            ->map(fn (string $name) => trim($name))
            ->filter(fn (string $name) => $name !== '')
            ->values();
        Validator::make(['names' => $names->all()], [
            'names' => ['required', 'array', 'max:'.self::MAX_NAMES],
            'names.*' => ['string', 'max:50'],
        ], [
            'names.required' => 'Type at least one first name.',
            'names.max' => 'Add at most '.self::MAX_NAMES.' learners at a time.',
            'names.*.max' => 'Each name can be at most 50 characters (":input" is longer).',
        ])->validate();

        $cards = DB::transaction(fn () => $names->map(function (string $name) use ($enroll, $section, $request) {
            ['student' => $student, 'login_code' => $code] = $enroll->handle($section, $name);
            AuditLog::record($request->user(), 'student.add', ['student', $student->code], ['section_id' => $section->id]);

            return ['name' => $student->user->name, 'login_code' => $code];
        })->all());

        return redirect()->route('teacher.sections.show', $section)->with('login_cards', $cards);
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

        return back()->with('login_cards', [['name' => $student->user->name, 'login_code' => LoginCode::format($code)]]);
    }

    public function consent(Request $request, Student $student): RedirectResponse
    {
        $given = $request->boolean('consent');
        $student->forceFill([
            'consent_recorded_at' => $given ? now() : null,
            'consent_recorded_by' => $given ? $request->user()->id : null,
        ])->save();
        AuditLog::record($request->user(), $given ? 'student.consent_recorded' : 'student.consent_cleared', ['student', $student->code]);

        // Recording is one tap on the class page, so it comes with an Undo.
        return $given
            ? back()->with('status', "Parental consent recorded for {$student->displayName()}.")->with('undo_consent', $student->id)
            : back()->with('status', "Consent record cleared for {$student->displayName()}.");
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
