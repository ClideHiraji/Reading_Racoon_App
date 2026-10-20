<?php

use App\Http\Middleware\AuthenticateAdmin;
use App\Http\Middleware\ConcealAdminPortal;
use App\Http\Middleware\EnsureApprovedTeacher;
use App\Http\Middleware\EnsureUserHasRole;
use App\Models\SystemLog;
use App\Support\AdminPortal;
use Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Foundation\Http\Middleware\ValidateCsrfToken;
use Illuminate\Http\Request;
use Illuminate\Routing\Middleware\SubstituteBindings;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\Support\Facades\Route;
use Illuminate\View\Middleware\ShareErrorsFromSession;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
        // The hidden admin portal exists only under the secret ADMIN_PATH from
        // .env, and not at all while it is unset or too short (D-012).
        then: function () {
            if ($path = AdminPortal::path()) {
                Route::prefix($path)->middleware('admin')->name('admin.')->group(base_path('routes/admin.php'));
            }
        },
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'role' => EnsureUserHasRole::class,
            'teacher' => EnsureApprovedTeacher::class,
            'admin.auth' => AuthenticateAdmin::class,
        ]);

        // Like the "web" group, but ConcealAdminPortal runs first: the IP
        // allowlist comes before the session, and every refusal becomes the
        // site's ordinary 404 without a session cookie.
        $middleware->group('admin', [
            ConcealAdminPortal::class,
            EncryptCookies::class,
            AddQueuedCookiesToResponse::class,
            StartSession::class,
            ShareErrorsFromSession::class,
            ValidateCsrfToken::class,
            SubstituteBindings::class,
        ]);

        // API guests get a JSON 401, never a redirect to a "login" web page
        // (which doesn't exist, so it was a 500 for clients without an Accept header).
        $middleware->redirectGuestsTo(
            fn (Request $request) => $request->is('api/*') ? null : route('login')
        );
        $middleware->redirectUsersTo(fn () => route('teacher.home'));

        // Synced payloads are research data: store them exactly as the device sent them.
        $isSync = fn (Request $request) => $request->is('api/sync');
        $middleware->trimStrings(except: [$isSync]);
        $middleware->convertEmptyStringsToNull(except: [$isSync]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // The Godot client may not send "Accept: application/json"; answer API
        // routes with JSON anyway (401/403/422 instead of HTML or a redirect).
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson()
        );

        // Server errors appear in the admin portal's system log as anomalies (FR-08).
        $exceptions->report(function (Throwable $e) {
            try {
                SystemLog::record('server.error', 'error', [
                    'exception' => $e::class,
                    'message' => mb_substr($e->getMessage(), 0, 300),
                    'at' => basename($e->getFile()).':'.$e->getLine(),
                ], anomaly: true);
            } catch (Throwable) {
                // The database may be what failed; the file log still has it.
            }
        });
    })->create();
