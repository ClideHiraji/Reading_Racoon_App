<?php

namespace App\Http\Controllers\Admin;

use App\Enums\RegistrationStatus;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Section;
use App\Models\Student;
use App\Models\SystemLog;
use App\Models\TeacherRegistration;
use App\Support\PrivacyChecks;
use Illuminate\View\View;

/**
 * Admin overview: what needs a decision and what looks unusual.
 */
class DashboardController extends Controller
{
    public function __invoke(): View
    {
        // The IT office looks in about once a week, so alerts cover 7 days.
        $since = now()->subDays(7);

        return view('admin.dashboard', [
            'pending' => TeacherRegistration::where('status', RegistrationStatus::Pending)->count(),
            'teachers' => TeacherRegistration::where('status', RegistrationStatus::Approved)->count(),
            'sections' => Section::count(),
            'students' => Student::count(),
            'anomalies7d' => SystemLog::where('anomaly', true)->where('created_at', '>=', $since)->count(),
            'failedLogins7d' => SystemLog::whereIn('event', ['auth.failed', 'admin.login_failed'])->where('created_at', '>=', $since)->count(),
            'errors7d' => SystemLog::whereIn('level', ['error', 'critical'])->where('created_at', '>=', $since)->count(),
            'recentAnomalies' => SystemLog::where('anomaly', true)->latest('id')->limit(8)->get(),
            // Decisions and changes only: page views (admin.view, section.view, ...) would bury them.
            'recentAudit' => AuditLog::where('action', 'not like', '%.view')->where('action', 'not like', '%.login%')
                ->where('action', 'not like', '%.logout')->latest('id')->limit(8)->get(),
            // Privacy and security checks that aren't ok, worst first.
            'checks' => array_values(array_filter(PrivacyChecks::run(), fn ($c) => $c[1] !== 'ok')),
        ]);
    }
}
