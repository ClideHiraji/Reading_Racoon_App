<?php

namespace App\Http\Middleware;

use App\Models\SystemLog;
use App\Support\AdminPortal;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * First middleware of every admin route (D-013):
 * 1. ADMIN_ALLOWED_IPS is checked before anything else (no session, no DB user lookup).
 * 2. Any refusal from further in (401, 403, 404, 405, 419, 429) is replaced by
 *    the site's ordinary 404, built fresh so no session cookie leaks out.
 * 3. Real admin pages get noindex, no-referrer (the secret path must never
 *    travel in a Referer header) and no-store.
 */
class ConcealAdminPortal
{
    private const REFUSALS = [401, 403, 404, 405, 419, 429];

    /**
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (! AdminPortal::ipAllowed($request)) {
            // Someone outside the allowlist knows the secret path: worth a look.
            SystemLog::record('admin.ip_blocked', 'critical', ['path_length' => strlen($request->path())], anomaly: true);

            return AdminPortal::notFound($request);
        }

        $response = $next($request);
        if (in_array($response->getStatusCode(), self::REFUSALS, true)) {
            return AdminPortal::notFound($request);
        }

        $response->headers->set('X-Robots-Tag', 'noindex, nofollow, noarchive');
        $response->headers->set('Referrer-Policy', 'no-referrer');
        $response->headers->set('Cache-Control', 'no-store, private');
        $response->headers->set('X-Frame-Options', 'DENY');
        $response->headers->set('X-Content-Type-Options', 'nosniff');

        return $response;
    }
}
