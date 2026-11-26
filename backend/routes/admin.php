<?php

use App\Http\Controllers\Admin\ContentController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\ExportController;
use App\Http\Controllers\Admin\LogController;
use App\Http\Controllers\Admin\LoginController;
use App\Http\Controllers\Admin\PrivacyController;
use App\Http\Controllers\Admin\RegistrationController;
use Illuminate\Support\Facades\Route;

// Hidden admin portal. bootstrap/app.php loads it under the secret ADMIN_PATH prefix with
// the `admin` middleware group, and only when ADMIN_PATH is set and long enough.
// Never link to these routes.

Route::get('/', [LoginController::class, 'create'])->name('login');
Route::post('/', [LoginController::class, 'store']);

Route::middleware('admin.auth')->group(function () {
    Route::get('/home', DashboardController::class)->name('dashboard');
    Route::post('/logout', [LoginController::class, 'destroy'])->name('logout');

    Route::get('/registrations', [RegistrationController::class, 'index'])->name('registrations');
    Route::post('/registrations/{registration}/approve', [RegistrationController::class, 'approve'])->name('registrations.approve');
    Route::post('/registrations/{registration}/deny', [RegistrationController::class, 'deny'])->name('registrations.deny');

    Route::get('/logs', [LogController::class, 'index'])->name('logs');
    Route::get('/privacy', PrivacyController::class)->name('privacy');

    Route::get('/content', [ContentController::class, 'index'])->name('content');
    Route::post('/content/{item}/unpublish', [ContentController::class, 'unpublish'])->name('content.unpublish');
    Route::get('/content/{item}/files/{file}', [ContentController::class, 'file'])->whereUuid('file')->name('content.file');

    Route::get('/export', [ExportController::class, 'index'])->name('export');
    Route::get('/export/students.csv', [ExportController::class, 'students'])->name('export.students');
    Route::get('/export/bkt-history.csv', [ExportController::class, 'bktHistory'])->name('export.history');
});

// Anything else under the prefix, with any HTTP method, is the ordinary 404.
// Without this, a wrong method on a real route would answer 405 and reveal it.
Route::any('{any?}', fn () => abort(404))->where('any', '.*');
