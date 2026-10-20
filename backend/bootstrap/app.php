<?php

use App\Http\Middleware\EnsureUserHasRole;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'role' => EnsureUserHasRole::class,
        ]);

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
    })->create();
