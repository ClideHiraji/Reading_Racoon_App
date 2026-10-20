<?php

namespace App\Http\Middleware;

use App\Enums\UserRole;
use App\Models\AuditLog;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Admin pages need an admin signed in on the `admin` guard with a TOTP code
 * verified in this session, active within the idle timeout. Anything else is
 * a plain 404 (never 403, never a redirect to the sign-in page, D-012).
 * Every page an admin opens is written to the audit log (FR-22).
 */
class AuthenticateAdmin
{
    /**
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = Auth::guard('admin')->user();
        $session = $request->session();
        $lastSeen = (int) $session->get('admin.last_seen', 0);

        if ($user === null || $user->role !== UserRole::Admin || ! $session->has('admin.2fa_at')) {
            abort(404);
        }
        if (now()->getTimestamp() - $lastSeen > config('admin.idle_minutes') * 60) {
            AuditLog::record($user, 'admin.session_expired');
            Auth::guard('admin')->logout();
            $session->forget(['admin.2fa_at', 'admin.last_seen']);
            abort(404);
        }
        $session->put('admin.last_seen', now()->getTimestamp());

        if ($request->isMethod('GET')) {
            AuditLog::record($user, 'admin.view', null, array_filter([
                'page' => $request->route()?->getName(),
                'query' => $request->query() ?: null,
            ]));
        }

        return $next($request);
    }
}
