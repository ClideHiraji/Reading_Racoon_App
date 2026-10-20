<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A teacher alert (FR-17). The id is the UUID of the client's "flag" sync
 * event when the device raised it.
 */
class InterventionFlag extends Model
{
    use HasUuids;

    protected $fillable = ['id', 'type', 'sub_skill', 'level', 'details', 'status', 'raised_at', 'resolved_at'];

    protected function casts(): array
    {
        return [
            'level' => 'integer',
            'details' => 'array',
            'raised_at' => 'datetime',
            'resolved_at' => 'datetime',
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
