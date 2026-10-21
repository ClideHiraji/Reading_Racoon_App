<?php

namespace App\Http\Controllers\Teacher;

use App\Enums\RegistrationStatus;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\SystemLog;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

/**
 * Teacher sign-in with email and password (FR-01). Only teachers whose
 * registration an admin approved get in (FR-08). Admin accounts can't sign in
 * here: they get the same "wrong credentials" answer as anyone else (D-013).
 */
class LoginController extends Controller
{
    private const MAX_ATTEMPTS = 5;

    public function create(): View|RedirectResponse
    {
        return Auth::check() ? redirect()->route('teacher.home') : view('auth.login');
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
        ]);
        $email = strtolower($data['email']);
        $key = 'teacher-login:'.Str::transliterate($email).'|'.$request->ip();

        if (RateLimiter::tooManyAttempts($key, self::MAX_ATTEMPTS)) {
            $seconds = RateLimiter::availableIn($key);
            throw ValidationException::withMessages(['email' => __('auth.throttle', ['seconds' => $seconds, 'minutes' => ceil($seconds / 60)])]);
        }

        $user = User::where('email', $email)->where('role', UserRole::Teacher)->with('registration')->first();
        if ($user === null || ! Hash::check($data['password'], (string) $user->password)) {
            RateLimiter::hit($key, 60);
            SystemLog::failedLogin('auth.failed', ['email' => $email]);
            throw ValidationException::withMessages(['email' => __('auth.failed')]);
        }
        RateLimiter::clear($key);

        $status = $user->registration?->status;
        if ($status !== RegistrationStatus::Approved) {
            throw ValidationException::withMessages(['email' => $status === RegistrationStatus::Denied
                ? 'Your registration was not approved. Please contact your school\'s system administrator.'
                : 'Your registration is waiting for approval. You can sign in once it is approved.']);
        }

        Auth::login($user, $request->boolean('remember'));
        $request->session()->regenerate();
        $user->forceFill(['last_login_at' => now(), 'last_login_ip' => $request->ip()])->save();
        AuditLog::record($user, 'teacher.login');

        return redirect()->intended(route('teacher.home'));
    }

    public function destroy(Request $request): RedirectResponse
    {
        if ($user = $request->user()) {
            AuditLog::record($user, 'teacher.logout');
        }
        Auth::guard('web')->logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }
}
