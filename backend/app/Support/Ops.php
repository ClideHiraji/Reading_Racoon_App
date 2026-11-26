<?php

namespace App\Support;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * Health checks for running the server on one laptop: is the database up, is the queue
 * worker keeping up, is the scheduler alive, when did the last backup finish.
 * Used by GET /api/health and `php artisan app:preflight`.
 */
final class Ops
{
    /** A job waiting longer than this means the queue worker is down or stuck. */
    public const QUEUE_LAG_LIMIT = 300;

    /** The scheduler beats every minute; this long without a beat means it stopped. */
    public const SCHEDULER_LIMIT = 180;

    public static function beat(string $what): void
    {
        Cache::forever("ops:beat:{$what}", now()->getTimestamp());
    }

    /** Seconds since the last beat, or null if there never was one. */
    public static function sinceBeat(string $what): ?int
    {
        $at = Cache::get("ops:beat:{$what}");

        return is_numeric($at) ? max(0, now()->getTimestamp() - (int) $at) : null;
    }

    public static function databaseUp(): bool
    {
        try {
            DB::select('select 1');

            return true;
        } catch (Throwable) {
            return false;
        }
    }

    /**
     * How long the oldest job that is ready to run has been waiting (0 when the
     * queue is empty), or null when the queue isn't the database driver.
     */
    public static function queueLag(): ?int
    {
        if (config('queue.default') !== 'database') {
            return null;
        }
        $now = now()->getTimestamp();
        $oldest = DB::table(config('queue.connections.database.table', 'jobs'))
            ->whereNull('reserved_at')
            ->where('available_at', '<=', $now)
            ->min('available_at');

        return $oldest === null ? 0 : max(0, $now - (int) $oldest);
    }

    /** @return array{path: string, at: int, bytes: int}|null the newest finished dump */
    public static function latestBackup(): ?array
    {
        $files = glob(rtrim((string) config('reading_racoon.backup.path'), '/\\').DIRECTORY_SEPARATOR.'reading_racoon-*.dump') ?: [];
        $latest = null;
        foreach ($files as $file) {
            $at = (int) filemtime($file);
            if ($latest === null || $at > $latest['at']) {
                $latest = ['path' => $file, 'at' => $at, 'bytes' => (int) filesize($file)];
            }
        }

        return $latest;
    }
}
