<?php

namespace App\Support;

use Illuminate\Contracts\Debug\ExceptionHandler;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\IpUtils;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * Helpers for the hidden admin portal (FR-08, FR-22, D-013).
 */
final class AdminPortal
{
    /** The secret path prefix, or null when it's unset or too weak (portal off). */
    public static function path(): ?string
    {
        $path = trim((string) config('admin.path'), '/');

        return strlen($path) >= (int) config('admin.min_path_length') && preg_match('/^[A-Za-z0-9_-]+$/', $path) === 1
            ? $path
            : null;
    }

    /** ADMIN_ALLOWED_IPS is empty, or the client IP is in it (IPs or CIDR ranges). */
    public static function ipAllowed(Request $request): bool
    {
        $allowed = config('admin.allowed_ips', []);

        return $allowed === [] || IpUtils::checkIp((string) $request->ip(), $allowed);
    }

    /**
     * Exactly what the router answers for a URL that matches no route: the same
     * exception, message and rendering, and no session cookie. A refused admin
     * request can't be told apart from a typo.
     */
    public static function notFound(Request $request): Response
    {
        return app(ExceptionHandler::class)->render(
            $request,
            new NotFoundHttpException("The route {$request->path()} could not be found.")
        );
    }
}
