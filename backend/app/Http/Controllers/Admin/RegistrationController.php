<?php

namespace App\Http\Controllers\Admin;

use App\Enums\RegistrationStatus;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\TeacherRegistration;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

/**
 * Approve or deny teacher registrations (FR-08). Denying an approved teacher
 * revokes access: their next request signs them out.
 */
class RegistrationController extends Controller
{
    public function index(Request $request): View
    {
        $status = RegistrationStatus::tryFrom((string) $request->query('status'))?->value ?? 'pending';

        return view('admin.registrations', [
            'status' => $status,
            'registrations' => TeacherRegistration::with(['user.sections', 'reviewer'])
                ->where('status', $status)->orderBy($status === 'pending' ? 'created_at' : 'reviewed_at', $status === 'pending' ? 'asc' : 'desc')
                ->paginate(25)->withQueryString(),
            'counts' => TeacherRegistration::selectRaw('status, count(*) as n')->groupBy('status')->pluck('n', 'status'),
        ]);
    }

    public function approve(Request $request, TeacherRegistration $registration): RedirectResponse
    {
        return $this->decide($request, $registration, RegistrationStatus::Approved);
    }

    public function deny(Request $request, TeacherRegistration $registration): RedirectResponse
    {
        return $this->decide($request, $registration, RegistrationStatus::Denied);
    }

    private function decide(Request $request, TeacherRegistration $registration, RegistrationStatus $status): RedirectResponse
    {
        $note = $request->validate(['note' => ['nullable', 'string', 'max:500']])['note'] ?? null;
        $admin = Auth::guard('admin')->user();
        $from = $registration->status;

        $registration->forceFill([
            'status' => $status,
            'reviewed_by' => $admin->id,
            'reviewed_at' => now(),
            'review_note' => $note,
        ])->save();
        AuditLog::record($admin, $status === RegistrationStatus::Approved ? 'registration.approve' : 'registration.deny',
            $registration, ['teacher' => $registration->user->email, 'from' => $from->value, 'note' => $note]);

        return back()->with('status', "{$registration->user->name} is now {$status->value}.");
    }
}
