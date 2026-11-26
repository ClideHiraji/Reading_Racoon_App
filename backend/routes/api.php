<?php

use App\Http\Controllers\Api\AccessStatusController;
use App\Http\Controllers\Api\ConfigController;
use App\Http\Controllers\Api\ContentController;
use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\LoginController;
use App\Http\Controllers\Api\StudentMeController;
use App\Http\Controllers\Api\SyncController;
use Illuminate\Support\Facades\Route;

// API surface: docs/knowledge/03-architecture.md. Contract: backend/README.md.

Route::post('/auth/login', LoginController::class)->middleware('throttle:login');
Route::get('/config', ConfigController::class)->middleware('throttle:api');
Route::get('/health', HealthController::class)->middleware('throttle:api');

Route::middleware(['auth:sanctum', 'role:student'])->group(function () {
    Route::post('/sync', SyncController::class)->middleware('throttle:sync');
    Route::middleware('throttle:api')->group(function () {
        Route::get('/student/me', StudentMeController::class);
        Route::get('/access/student/status', AccessStatusController::class);
        Route::get('/content/manifest', [ContentController::class, 'manifest']);
        Route::get('/content/files/{file}', [ContentController::class, 'file'])->whereUuid('file');
    });
});
