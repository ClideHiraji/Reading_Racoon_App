<?php

use App\Http\Controllers\Api\AccessStatusController;
use App\Http\Controllers\Api\ConfigController;
use App\Http\Controllers\Api\LoginController;
use App\Http\Controllers\Api\StudentMeController;
use App\Http\Controllers\Api\SyncController;
use Illuminate\Support\Facades\Route;

// API surface: docs/knowledge/03-architecture.md. Contract: backend/README.md.

Route::post('/auth/login', LoginController::class)->middleware('throttle:login');   // FR-01
Route::get('/config', ConfigController::class)->middleware('throttle:api');         // FR-19

Route::middleware(['auth:sanctum', 'role:student'])->group(function () {
    Route::post('/sync', SyncController::class)->middleware('throttle:sync');        // FR-11
    Route::middleware('throttle:api')->group(function () {
        Route::get('/student/me', StudentMeController::class);                       // FR-03, FR-07
        Route::get('/access/student/status', AccessStatusController::class);         // FR-12
    });
});
