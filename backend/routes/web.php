<?php

use App\Http\Controllers\Teacher\ContentController;
use App\Http\Controllers\Teacher\LoginController;
use App\Http\Controllers\Teacher\RegisterController;
use App\Http\Controllers\Teacher\ReportController;
use App\Http\Controllers\Teacher\RosterController;
use App\Http\Controllers\Teacher\ScheduleController;
use App\Http\Controllers\Teacher\SectionController;
use App\Http\Controllers\Teacher\StudentController;
use Illuminate\Support\Facades\Route;

// Teacher web pages (FR-06, FR-08, FR-12, FR-16, FR-17, FR-18). The admin
// portal is NOT here: it lives under a secret path from .env (routes/admin.php, D-013).

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
    Route::post('/flags/{flag}/reopen', [StudentController::class, 'reopenFlag'])
        ->middleware('can:update,flag')->name('flags.reopen');
    // Several flags at once (one skill-level, or "Close all that look better"); each is checked against the policy.
    Route::post('/flags/resolve', [StudentController::class, 'resolveFlags'])->name('flags.resolve-many');
    Route::post('/flags/reopen', [StudentController::class, 'reopenFlags'])->name('flags.reopen-many');

    // Library & Videos (D-019): openly licensed books and Ogg videos for the game.
    Route::get('/content', [ContentController::class, 'index'])->name('content.index');
    Route::get('/content/books/new', [ContentController::class, 'createBook'])->name('content.books.create');
    Route::post('/content/books', [ContentController::class, 'storeBook'])->name('content.books.store');
    Route::get('/content/videos/new', [ContentController::class, 'createVideo'])->name('content.videos.create');
    Route::post('/content/videos', [ContentController::class, 'storeVideo'])->name('content.videos.store');
    Route::middleware('can:update,item')->group(function () {
        Route::get('/content/{item}/edit', [ContentController::class, 'edit'])->name('content.edit');
        Route::put('/content/{item}', [ContentController::class, 'update'])->name('content.update');
        Route::put('/content/{item}/sections', [ContentController::class, 'assign'])->name('content.assign');
        Route::post('/content/{item}/publish', [ContentController::class, 'publish'])->name('content.publish');
        Route::delete('/content/{item}', [ContentController::class, 'destroy'])->name('content.destroy');
        Route::get('/content/{item}/files/{file}', [ContentController::class, 'file'])->whereUuid('file')->name('content.file');
    });
});
