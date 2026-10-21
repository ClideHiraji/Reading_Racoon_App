<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A raccoon customisation the student owns (FR-07). Projection of the synced
 * "purchase" and "outfit" events, rebuilt by App\Actions\ReplayStudentEvents.
 */
class StudentItem extends Model
{
    public $incrementing = false;

    protected $primaryKey = null;

    protected $fillable = ['item_id', 'slot', 'equipped', 'cost', 'acquired_at'];

    protected function casts(): array
    {
        return [
            'equipped' => 'boolean',
            'cost' => 'integer',
            'acquired_at' => 'datetime',
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
