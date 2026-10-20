<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Minutes a student played on one local date (FR-12). Projection of the synced
 * "usage" events, rebuilt by App\Actions\ReplayStudentEvents. `minutes` counts
 * toward the daily cap; `class_minutes` were played in the class window.
 */
class DailyUsage extends Model
{
    protected $table = 'daily_usage';

    public $incrementing = false;

    protected $primaryKey = null;

    protected $fillable = ['date', 'minutes', 'class_minutes'];

    protected function casts(): array
    {
        return [
            'date' => 'date:Y-m-d',
            'minutes' => 'integer',
            'class_minutes' => 'integer',
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
