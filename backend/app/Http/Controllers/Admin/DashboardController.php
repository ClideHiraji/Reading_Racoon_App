<?php

namespace App\Http\Controllers\Admin;

use App\Enums\RegistrationStatus;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Section;
use App\Models\Student;
use App\Models\SystemLog;
use App\Models\TeacherRegistration;
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
            'recentAudit' => AuditLog::where('action', '!=', 'admin.view')->latest('id')->limit(8)->get(),
        ]);
    }
}
