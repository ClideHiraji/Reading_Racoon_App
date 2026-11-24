<?php

namespace App\Support;

use App\Enums\UserRole;
use App\Models\AiLog;
use App\Models\Student;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * The RA 10173 privacy and security checks (FR-22, NFR-04), each ok, warn or
 * fail. The privacy audit lists them; the admin overview raises any that
 * aren't ok, worst first.
 */
final class PrivacyChecks
{
    public const ORDER = ['fail' => 0, 'warn' => 1, 'ok' => 2];

    /** @return list<array{0: string, 1: string, 2: string}> [name, status, detail], worst first */
    public static function run(): array
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
                $admins->count().' '.Str::plural('admin account', $admins->count()).'; created only with php artisan admin:create.'],
            ['Admin portal path', AdminPortal::path() !== null ? 'ok' : 'fail', 'Secret prefix of at least '.config('admin.min_path_length').' characters from .env.'],
            ['Admin IP allowlist', config('admin.allowed_ips') !== [] ? 'ok' : 'warn',
                config('admin.allowed_ips') !== [] ? count(config('admin.allowed_ips')).' '.Str::plural('entry', count(config('admin.allowed_ips'))).'.' : 'Not set: any IP that knows the path reaches the sign-in form.'],
            ['Debug mode off', config('app.debug') ? 'fail' : 'ok', 'APP_DEBUG must be false on the server (debug pages show internals).'],
            ['HTTPS', str_starts_with((string) config('app.url'), 'https://') ? 'ok' : 'warn', 'APP_URL is '.config('app.url').'.'],
            ['Audit log is append-only', $trigger ? 'ok' : 'fail', 'PostgreSQL trigger refuses UPDATE and DELETE on audit_logs.'],
            ['Inactive learners', $inactive === 0 ? 'ok' : 'warn', $inactive.' '.Str::plural('learner', $inactive).' with no sync for 180 days: candidates for deletion.'],
            ['Unused game tokens', $staleTokens === 0 ? 'ok' : 'warn', $staleTokens.' game sign-in '.Str::plural('token', $staleTokens).' unused for 90 days.'],
            ['Third-party AI processing', LlmClient::enabled() ? 'warn' : 'ok', LlmClient::enabled()
                ? 'Gemini ('.LlmClient::model().') is on. Only learners with parental consent are sent, as student code and scores (no names or dates); '
                    .$aiCalls.' '.Str::plural('call', $aiCalls).' in the last 30 days, '.$aiUnconsented.' for learners without consent now. Use paid (billing-enabled) terms (docs/knowledge/08-ai-integration.md, D-018).'
                : 'The AI is off (LLM_* not set in .env); reports use the template and nothing leaves the server.'],
        ];

        usort($checks, fn ($a, $b) => self::ORDER[$a[1]] <=> self::ORDER[$b[1]]);

        return $checks;
    }
}
