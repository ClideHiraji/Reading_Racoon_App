<?php

use App\Models\SystemLog;
use App\Support\Ops;
use Illuminate\Support\Facades\Schedule;

// Scheduled upkeep for the home server (see docs/deploy/home-server.md).
// Windows runs `php artisan schedule:work` as a startup task. Every job below is fine
// with a missed night (laptop off) and just runs the next one.

// Proves the scheduler is alive (`app:preflight`, GET /api/health).
Schedule::call(fn () => Ops::beat('scheduler'))->everyMinute()->name('scheduler-heartbeat');

// Nightly PostgreSQL dump, checked with pg_restore, copied off the laptop when
// BACKUP_COPY_TO is set, oldest dumps pruned.
Schedule::command('app:backup')->dailyAt('02:30')->withoutOverlapping(60);

// Retention: routine system-log rows, expired device tokens, old failed jobs.
Schedule::command('model:prune', ['--model' => [SystemLog::class]])->dailyAt('03:10');
Schedule::command('sanctum:prune-expired', ['--hours' => 24])->dailyAt('03:20');
Schedule::command('queue:prune-failed', ['--hours' => 24 * 30])->dailyAt('03:30');
