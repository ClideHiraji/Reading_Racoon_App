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
 * Admin overview (FR-08): what needs a decision and what looks unusual.
 */
class DashboardController extends Controller
{
    public function __invoke(): View
    {
        $since = now()->subDay();

        return view('admin.dashboard', [
            'pending' => TeacherRegistration::where('status', RegistrationStatus::Pending)->count(),
            'teachers' => TeacherRegistration::where('status', RegistrationStatus::Approved)->count(),
            'sections' => Section::count(),
            'students' => Student::count(),
            'anomalies24h' => SystemLog::where('anomaly', true)->where('created_at', '>=', $since)->count(),
            'failedLogins24h' => SystemLog::whereIn('event', ['auth.failed', 'admin.login_failed'])->where('created_at', '>=', $since)->count(),
            'errors24h' => SystemLog::whereIn('level', ['error', 'critical'])->where('created_at', '>=', $since)->count(),
            'recentAnomalies' => SystemLog::where('anomaly', true)->latest('id')->limit(8)->get(),
            // Decisions and changes only: page views (admin.view, section.view, ...) would bury them.
            'recentAudit' => AuditLog::where('action', 'not like', '%.view')->latest('id')->limit(8)->get(),
            // Privacy and security checks that aren't ok, worst first (FR-22).
            'checks' => array_values(array_filter(PrivacyChecks::run(), fn ($c) => $c[1] !== 'ok')),
        ]);
    }
}
