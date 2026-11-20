<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Vite;
use Symfony\Component\HttpFoundation\Response;

/**
 * Browser hardening headers on every response (NFR-04, D-036), for the teacher
 * dashboard, the admin portal and the API once the server is on the internet.
 *
 * - A Content-Security-Policy with a per-request nonce: only scripts from this
 *   site and inline blocks that carry the nonce may run. Charts are drawn on
 *   the server (D-037), so no page loads a script from another host.
 * - HSTS only on https requests (the tunnel's X-Forwarded-Proto, see
 *   config/trustedproxy.php), so plain-http local development keeps working.
 * - A header a route already set (the admin portal's stricter no-referrer,
 *   for one) is never overwritten.
 */
class SecurityHeaders
{
    /**
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $nonce = Vite::useCspNonce();

        $response = $next($request);

        $headers = [
            'X-Content-Type-Options' => 'nosniff',
            'X-Frame-Options' => 'DENY',
            'Referrer-Policy' => 'strict-origin-when-cross-origin',
            'Permissions-Policy' => 'camera=(), microphone=(), geolocation=(), payment=(), usb=()',
            'Cross-Origin-Opener-Policy' => 'same-origin',
            'Content-Security-Policy' => implode('; ', [
                "default-src 'self'",
                "script-src 'self' 'nonce-{$nonce}'",
                // Blade views use style attributes; styles can't run code.
                "style-src 'self' 'unsafe-inline'",
                "img-src 'self' data: blob:",
                "media-src 'self' blob:",
                "font-src 'self' data:",
                "connect-src 'self'",
                "object-src 'none'",
                "base-uri 'self'",
                "form-action 'self'",
                "frame-ancestors 'none'",
            ]),
        ];
        if ($request->isSecure()) {
            $headers['Strict-Transport-Security'] = 'max-age='.(int) config('reading_racoon.security.hsts_seconds');
        }

        foreach ($headers as $name => $value) {
            if (! $response->headers->has($name)) {
                $response->headers->set($name, $value);
            }
        }
        // PHP itself adds X-Powered-By with its exact version (expose_php);
        // php.ini expose_php=Off is the real fix (docs/deploy/home-server.md).
        $response->headers->remove('X-Powered-By');
        if (! headers_sent()) {
            header_remove('X-Powered-By');
        }

        return $response;
    }
}
