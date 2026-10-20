<?php

namespace App\Http\Controllers\Admin;

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
use Illuminate\View\View;
use PragmaRX\Google2FA\Google2FA;
use Throwable;

/**
 * Admin sign-in (FR-01, FR-08, D-013): email + password + TOTP code in one form,
 * one generic error for any wrong factor, a used code can't be replayed, and
 * after 5 failures per IP or per email the form answers 404 for 15 minutes.
 */
class LoginController extends Controller
{
    /** Hash checked when the email is unknown, so both cases take about as long. */
    private const DUMMY_HASH = '$2y$12$Q6r0bYzv0bJm0Wl2r8m7ZeVx1mEw1H8c2bY6Zl6Jq7Wc6oGJm8eSa';

    public function create(Request $request): View|RedirectResponse
    {
        if (Auth::guard('admin')->check() && $request->session()->has('admin.2fa_at')) {
            return redirect()->route('admin.dashboard');
        }

        return view('admin.login');
    }

    public function store(Request $request, Google2FA $google2fa): RedirectResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'max:255'],
            'password' => ['required', 'string', 'max:1000'],
            'code' => ['required', 'string', 'max:12'],
        ]);
        $email = strtolower(trim($data['email']));
        $keys = ['admin-login:ip:'.$request->ip(), 'admin-login:email:'.hash('sha256', $email)];
        $max = config('admin.login_max_attempts');

        foreach ($keys as $key) {
            if (RateLimiter::tooManyAttempts($key, $max)) {
                SystemLog::record('admin.login_throttled', 'warning', ['email' => $email], anomaly: true);
                abort(429); // concealed as 404 by ConcealAdminPortal
            }
        }

        $user = User::where('email', $email)->where('role', UserRole::Admin)->first();
        $passwordOk = Hash::check($data['password'], $user?->password ?? self::DUMMY_HASH);
        $step = false;
        if ($user !== null && $passwordOk && $user->two_factor_secret) {
            try {
                // Old step 0 instead of null makes the library return the matched step.
                $step = $google2fa->verifyKeyNewer($user->two_factor_secret, preg_replace('/\s+/', '', $data['code']),
                    $user->two_factor_last_step ?? 0, config('admin.totp_window'));
            } catch (Throwable) {
                $step = false;
            }
        }

        if ($user === null || ! $passwordOk || ! is_int($step)) {
            foreach ($keys as $key) {
                RateLimiter::hit($key, config('admin.login_decay_minutes') * 60);
            }
            SystemLog::failedLogin('admin.login_failed', [
                'email' => $email,
                'failed' => $user === null ? 'account' : (! $passwordOk ? 'password' : 'totp'),
            ]);

            return redirect()->route('admin.login')->withInput(['email' => $email])->withErrors(['email' => 'These credentials do not match.']);
        }

        foreach ($keys as $key) {
            RateLimiter::clear($key);
        }
        $user->forceFill(['two_factor_last_step' => $step, 'last_login_at' => now(), 'last_login_ip' => $request->ip()])->save();
        Auth::guard('admin')->login($user);
        $request->session()->regenerate();
        $request->session()->put(['admin.2fa_at' => now()->getTimestamp(), 'admin.last_seen' => now()->getTimestamp()]);
        AuditLog::record($user, 'admin.login');

        return redirect()->route('admin.dashboard');
    }

    public function destroy(Request $request): RedirectResponse
    {
        AuditLog::record(Auth::guard('admin')->user(), 'admin.logout');
        Auth::guard('admin')->logout();
        $request->session()->forget(['admin.2fa_at', 'admin.last_seen']);
        $request->session()->regenerate(true);
        $request->session()->regenerateToken();

        return redirect()->route('admin.login');
    }
}
