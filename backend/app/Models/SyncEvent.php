<?php

namespace App\Models;

use App\Enums\SyncEventType;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One game event uploaded by the device. `uuid` is the game's event id (so a repeat
 * isn't stored twice); `id` is the server's arrival order.
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
