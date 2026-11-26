<?php

namespace App\Jobs;

use App\Actions\ReplayStudentEvents;
use App\Models\Student;
use App\Models\SystemLog;
use App\Support\Ops;
use Illuminate\Contracts\Queue\ShouldBeUniqueUntilProcessing;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Throwable;

/**
 * Replays one learner's synced events into the official state, outside the request.
 *
 * POST /api/sync acknowledges events as soon as they're stored, then queues this job a few
 * seconds later. While one is waiting, more syncs from the same learner don't queue another
 * (unique until processing), so a device uploading 5,000 events in 50 batches costs one replay,
 * not 50. Once the job starts, the lock is released: a sync during the replay queues the next
 * one, so no stored event is ever left out.
 *
 * A failure is retried with a wait and never touches the device's queue, which only waits
 * for the acknowledgement.
 */
final class ReplayStudent implements ShouldBeUniqueUntilProcessing, ShouldQueue
{
    use Queueable;

    public int $tries = 5;

    public int $timeout = 120;

    /** A lock left by a lost job expires after ten minutes. */
    public int $uniqueFor = 600;

    public function __construct(public readonly int $studentId) {}

    public function uniqueId(): string
    {
        return (string) $this->studentId;
    }

    /** @return list<int> seconds between attempts */
    public function backoff(): array
    {
        return [10, 60, 300, 900];
    }

    /**
     * Queues a replay for after the sync burst; never throws into the sync request.
     * If the queue worker has stopped (a job has waited longer than Ops::QUEUE_LAG_LIMIT),
     * the replay runs right here instead, so the official state never goes stale.
     */
    public static function after(Student $student): void
    {
        try {
            $lag = Ops::queueLag();
            if ($lag !== null && $lag > Ops::QUEUE_LAG_LIMIT) {
                app(ReplayStudentEvents::class)->handle($student);

                return;
            }
            self::dispatch($student->id)
                ->delay(now()->addSeconds(config('reading_racoon.sync.replay_delay_seconds')));
        } catch (Throwable $e) {
            // With the "sync" queue (tests, a dev server without a worker) the
            // replay runs right here; its failure must not cost the device its
            // acknowledgement. The next sync tries again.
            report($e);
        }
    }

    public function handle(ReplayStudentEvents $replay): void
    {
        $student = Student::find($this->studentId);
        if ($student !== null) {
            $replay->handle($student);
        }
    }

    public function failed(?Throwable $e): void
    {
        try {
            SystemLog::record('sync.replay_failed', 'error', [
                'student_id' => $this->studentId,
                'exception' => $e ? $e::class : null,
                'message' => $e ? mb_substr($e->getMessage(), 0, 300) : null,
            ], anomaly: true);
        } catch (Throwable) {
            // The database may be what failed; the file log has the exception.
        }
    }
}
