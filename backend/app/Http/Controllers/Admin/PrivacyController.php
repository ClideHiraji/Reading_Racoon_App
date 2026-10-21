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
use App\Support\AdminPortal;
use App\Support\LlmClient;
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
        $consented = Student::whereNotNull('consent_recorded_at')->count();
        $admins = User::where('role', UserRole::Admin)->get();
        $inactiveSince = now()->subDays(180);
        $inactive = Student::whereDoesntHave('syncEvents', fn ($q) => $q->where('received_at', '>=', $inactiveSince))
            ->where('created_at', '<', $inactiveSince)->count();
        $staleTokens = DB::table('personal_access_tokens')
            ->where(fn ($q) => $q->where('last_used_at', '<', now()->subDays(90))
                ->orWhere(fn ($w) => $w->whereNull('last_used_at')->where('created_at', '<', now()->subDays(90))))
            ->count();
        $trigger = DB::table('pg_trigger')->where('tgname', 'audit_logs_no_update_or_delete')->exists();
        $aiCalls = AiLog::where('created_at', '>=', now()->subDays(30))->count();
        // Consent cleared after a call: their earlier rows are listed here so the admin can review them.
        $aiUnconsented = AiLog::where('created_at', '>=', now()->subDays(30))
            ->whereHas('student', fn ($q) => $q->whereNull('consent_recorded_at'))->count();

        $checks = [
            ['Parental consent on file', $students === 0 ? 'ok' : ($consented === $students ? 'ok' : 'warn'),
                "{$consented} of {$students} learners. Research exports include consented learners only."],
            ['Every admin has TOTP 2FA', $admins->every(fn ($a) => filled($a->two_factor_secret)) ? 'ok' : 'fail',
                $admins->count().' admin account(s); created only with php artisan admin:create.'],
            ['Admin portal path', AdminPortal::path() !== null ? 'ok' : 'fail', 'Secret prefix of at least '.config('admin.min_path_length').' characters from .env.'],
            ['Admin IP allowlist', config('admin.allowed_ips') !== [] ? 'ok' : 'warn',
                config('admin.allowed_ips') !== [] ? count(config('admin.allowed_ips')).' entr(ies).' : 'Not set: any IP that knows the path reaches the sign-in form.'],
            ['Debug mode off', config('app.debug') ? 'fail' : 'ok', 'APP_DEBUG must be false on the server (debug pages show internals).'],
            ['HTTPS', str_starts_with((string) config('app.url'), 'https://') ? 'ok' : 'warn', 'APP_URL is '.config('app.url').'.'],
            ['Audit log is append-only', $trigger ? 'ok' : 'fail', 'PostgreSQL trigger refuses UPDATE and DELETE on audit_logs.'],
            ['Inactive learners', $inactive === 0 ? 'ok' : 'warn', "{$inactive} learner(s) with no sync for 180 days: candidates for deletion."],
            ['Unused game tokens', $staleTokens === 0 ? 'ok' : 'warn', "{$staleTokens} Sanctum token(s) unused for 90 days."],
            ['Third-party AI processing', LlmClient::enabled() ? 'warn' : 'ok', LlmClient::enabled()
                ? 'Gemini ('.LlmClient::model().') is on. Only learners with parental consent are sent, as student code and scores (no names or dates); '
                    .$aiCalls.' call(s) in the last 30 days, '.$aiUnconsented.' for learners without consent now. Use paid (billing-enabled) terms (docs/knowledge/08-ai-integration.md, D-018).'
                : 'The AI is off (LLM_* not set in .env); reports use the template and nothing leaves the server.'],
        ];

        return view('admin.privacy', [
            'checks' => $checks,
            'inventory' => [
                ['Learner first name or nickname', 'users.name (students)', Student::count(), 'Shown to the learner\'s own teacher only.'],
                ['Pseudonymous student code', 'students.code', $students, 'Used in exports, logs and AI prompts instead of names.'],
                ['Login code', 'users.login_code_hash', $students, 'SHA-256 hash only; the code is shown once.'],
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
