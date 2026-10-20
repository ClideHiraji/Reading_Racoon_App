<?php

use App\Http\Controllers\Teacher\LoginController;
use App\Http\Controllers\Teacher\RegisterController;
use App\Http\Controllers\Teacher\ReportController;
use App\Http\Controllers\Teacher\RosterController;
use App\Http\Controllers\Teacher\ScheduleController;
use App\Http\Controllers\Teacher\SectionController;
use App\Http\Controllers\Teacher\StudentController;
use Illuminate\Support\Facades\Route;

// Teacher web pages (FR-06, FR-08, FR-12, FR-16, FR-17, FR-18). The admin
// portal is NOT here: it lives under a secret path from .env (routes/admin.php, D-012).

Route::redirect('/', '/login');

Route::middleware('guest')->group(function () {
    Route::get('/login', [LoginController::class, 'create'])->name('login');
    Route::post('/login', [LoginController::class, 'store'])->middleware('throttle:teacher-login');
    Route::get('/register', [RegisterController::class, 'create'])->name('register');
    Route::post('/register', [RegisterController::class, 'store'])->middleware('throttle:teacher-register');
    Route::get('/register/sent', [RegisterController::class, 'pending'])->name('register.pending');
});

Route::post('/logout', [LoginController::class, 'destroy'])->middleware('auth')->name('logout');

Route::middleware(['auth', 'teacher'])->prefix('teacher')->name('teacher.')->group(function () {
    Route::get('/', [SectionController::class, 'index'])->name('home');
    Route::post('/sections', [SectionController::class, 'store'])->name('sections.store');

    Route::middleware('can:view,section')->group(function () {
        Route::get('/sections/{section}', [SectionController::class, 'show'])->name('sections.show');
        Route::get('/sections/{section}/schedule', [ScheduleController::class, 'edit'])->name('schedule.edit');
        Route::put('/sections/{section}/schedule', [ScheduleController::class, 'update'])->name('schedule.update');
        Route::post('/sections/{section}/students', [RosterController::class, 'store'])->name('students.store');
    });

    Route::middleware('can:view,student')->group(function () {
        Route::get('/students/{student}', [StudentController::class, 'show'])->name('students.show');
        Route::get('/students/{student}/report', [ReportController::class, 'show'])->name('students.report');
        Route::get('/students/{student}/report.pdf', [ReportController::class, 'pdf'])->name('students.report.pdf');
        Route::post('/students/{student}/code', [RosterController::class, 'newCode'])->name('students.code');
        Route::post('/students/{student}/consent', [RosterController::class, 'consent'])->name('students.consent');
        Route::delete('/students/{student}', [RosterController::class, 'destroy'])->name('students.destroy');
    });

    Route::post('/flags/{flag}/resolve', [StudentController::class, 'resolveFlag'])
        ->middleware('can:update,flag')->name('flags.resolve');
});
