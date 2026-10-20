<?php

use App\Http\Controllers\Api\ConfigController;
use App\Http\Controllers\Api\LoginController;
use App\Http\Controllers\Api\SyncController;
use Illuminate\Support\Facades\Route;

// API surface: docs/knowledge/03-architecture.md. Contract: backend/README.md.

Route::post('/auth/login', LoginController::class)->middleware('throttle:login');   // FR-01
Route::get('/config', ConfigController::class)->middleware('throttle:api');         // FR-19

Route::middleware(['auth:sanctum', 'role:student'])->group(function () {
    Route::post('/sync', SyncController::class)->middleware('throttle:sync');        // FR-11
});
