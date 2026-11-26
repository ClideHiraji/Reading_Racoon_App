<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Teacher web pages: the signed-in user must be a teacher whose sign-up is (still) approved.
 * If an admin revokes a teacher, their access ends on the next request. Runs after `auth`.
 */
class EnsureApprovedTeacher
{
    /**
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->user()?->isApprovedTeacher()) {
            Auth::guard('web')->logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return redirect()->route('login')->withErrors(['email' => 'Please sign in with an approved teacher account.']);
        }

        return $next($request);
    }
}
