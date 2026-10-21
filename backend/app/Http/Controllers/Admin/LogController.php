<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\SystemLog;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Validator;
use Illuminate\View\View;

/**
 * System and audit logs with filters and anomaly highlighting (FR-08, FR-22).
 */
class LogController extends Controller
{
    /** Audit actions that change or move learner data: highlighted for review. */
    public const SENSITIVE_ACTIONS = [
        'student.remove', 'student.new_code', 'student.consent_cleared', 'registration.approve',
        'registration.deny', 'export.students', 'export.bkt_history', 'admin.session_expired',
    ];

    public function index(Request $request): View
    {
        // Bad filter values are dropped, not answered with a redirect.
        $filters = Validator::make($request->query(), [
            'kind' => ['nullable', 'in:system,audit'],
            'level' => ['nullable', 'in:info,warning,error,critical'],
            'event' => ['nullable', 'string', 'max:64'],
            'anomaly' => ['nullable', 'boolean'],
            'from' => ['nullable', 'date_format:Y-m-d'],
            'to' => ['nullable', 'date_format:Y-m-d'],
            'q' => ['nullable', 'string', 'max:100'],
        ])->valid();
        $kind = $filters['kind'] ?? 'system';
        $tz = config('reading_racoon.access.timezone');
        $range = fn ($query) => $query
            ->when($filters['from'] ?? null, fn ($q, $d) => $q->where('created_at', '>=', Carbon::parse($d, $tz)->startOfDay()->utc()))
            ->when($filters['to'] ?? null, fn ($q, $d) => $q->where('created_at', '<', Carbon::parse($d, $tz)->addDay()->startOfDay()->utc()));

        if ($kind === 'audit') {
            $logs = $range(AuditLog::query())
                ->when($filters['event'] ?? null, fn ($q, $e) => $q->where('action', $e))
                ->when($filters['anomaly'] ?? false, fn ($q) => $q->whereIn('action', self::SENSITIVE_ACTIONS))
                ->when($filters['q'] ?? null, fn ($q, $s) => $q->where(fn ($w) => $w->where('actor_label', 'ilike', "%{$s}%")
                    ->orWhere('subject_id', 'ilike', "%{$s}%")->orWhere('ip', $s)))
                ->latest('id')->paginate(50)->withQueryString();
            $events = AuditLog::distinct()->orderBy('action')->pluck('action');
        } else {
            $logs = $range(SystemLog::query())
                ->when($filters['level'] ?? null, fn ($q, $l) => $q->where('level', $l))
                ->when($filters['event'] ?? null, fn ($q, $e) => $q->where('event', $e))
                ->when($filters['anomaly'] ?? false, fn ($q) => $q->where('anomaly', true))
                ->when($filters['q'] ?? null, fn ($q, $s) => $q->where(fn ($w) => $w->where('ip', $s)
                    ->orWhereRaw('context::text ilike ?', ["%{$s}%"])))
                ->latest('id')->paginate(50)->withQueryString();
            $events = SystemLog::distinct()->orderBy('event')->pluck('event');
        }

        return view('admin.logs', [
            'kind' => $kind,
            'logs' => $logs,
            'events' => $events,
            'filters' => $filters,
            'timezone' => $tz,
            'sensitive' => self::SENSITIVE_ACTIONS,
            'anomalyDays' => SystemLog::where('anomaly', true)->where('created_at', '>=', now()->subDays(13)->startOfDay())
                ->selectRaw("to_char(created_at at time zone ?, 'YYYY-MM-DD') as day, count(*) as n", [$tz])
                ->groupBy('day')->pluck('n', 'day'),
        ]);
    }
}
