<?php

namespace App\Http\Middleware;

use App\Enums\UserRole;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Role gate for API routes (FR-01), e.g. ->middleware('role:student').
 * Runs after auth:sanctum.
 */
class EnsureUserHasRole
{
    /**
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $role = $request->user()?->role;
        abort_unless($role instanceof UserRole && in_array($role->value, $roles, true), 403);

        return $next($request);
    }
}
