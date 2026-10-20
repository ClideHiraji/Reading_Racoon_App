<?php

namespace App\Models;

use App\Enums\SyncEventType;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One gameplay event uploaded by the client (FR-11). `uuid` is the client's
 * event id (its idempotency key); `id` is the server's arrival order.
 * Rows are written in bulk by App\Actions\RecordSyncEvents.
 */
class SyncEvent extends Model
{
    public $timestamps = false;

    protected function casts(): array
    {
        return [
            'type' => SyncEventType::class,
            'payload' => 'array',
            'device_time' => 'datetime',
            'received_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<Student, $this>
     */
    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }
}
