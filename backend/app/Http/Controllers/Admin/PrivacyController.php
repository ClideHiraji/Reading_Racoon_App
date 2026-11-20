<?php

namespace App\Http\Controllers\Admin;

use App\Enums\RegistrationStatus;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Models\AiLog;
use App\Models\AiReport;
use App\Models\AuditLog;
use App\Models\Section;
use App\Models\Student;
use App\Models\User;
use App\Support\PrivacyChecks;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

/**
 * Data-privacy audit under RA 10173, the Data Privacy Act of 2012 (FR-22, NFR-04):
 * consent coverage, what personal data is stored, who accessed learner data,
 * retention candidates and security settings. Each check is ok, warn or fail.
 */
class PrivacyController extends Controller
{
    public function __invoke(): View
    {
        $students = Student::count();
        $admins = User::where('role', UserRole::Admin)->get();
        $checks = PrivacyChecks::run();

        return view('admin.privacy', [
            'checks' => $checks,
            'inventory' => [
                ['Learner first name or nickname', 'users.name (students)', Student::count(), 'Shown to the learner\'s own teacher only.'],
                ['Pseudonymous student code', 'students.code', $students, 'Used in exports, logs and AI prompts instead of names.'],
                ['Login code', 'users.login_code_hash', $students, 'Keyed HMAC-SHA256 hash only (D-036); the code is shown once.'],
                ['Gameplay events', 'sync_events', DB::table('sync_events')->count(), 'Answers, scores, play minutes; no free text, age or gender.'],
                ['AI calls', 'ai_logs', AiLog::count(), 'Student code and scores sent to Gemini, with the reply (FR-21). Consented learners only; deleted with the learner.'],
                ['AI report paragraphs', 'ai_reports', AiReport::count(), 'Gemini\'s summary text per set of numbers; deleted with the learner.'],
                ['Teacher name and email', 'users (teachers)', User::where('role', UserRole::Teacher)->count(), 'Needed to sign in and approve accounts.'],
                ['Admin name and email', 'users (admins)', $admins->count(), 'TOTP secret encrypted with APP_KEY.'],
            ],
            'sections' => Section::withCount(['students', 'students as consented_count' => fn ($q) => $q->whereNotNull('consent_recorded_at')])
                ->with('teacher')->orderBy('name')->get(),
            'access' => AuditLog::whereIn('action', ['student.view', 'report.view', 'report.pdf', 'section.view', 'export.students', 'export.bkt_history'])
                ->where('created_at', '>=', now()->subDays(30))
                ->selectRaw('actor_label, actor_role, action, count(*) as n, max(created_at) as last_at')
                ->groupBy('actor_label', 'actor_role', 'action')->orderBy('actor_label')->get(),
            'pendingTeachers' => User::whereHas('registration', fn ($q) => $q->where('status', RegistrationStatus::Pending))->count(),
            'orphanSections' => Section::whereNull('teacher_id')->count(),
            'oldestEvent' => DB::table('sync_events')->min('received_at'),
        ]);
    }
}
