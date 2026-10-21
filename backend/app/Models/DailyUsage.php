<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * After-school minutes a student played on one local date (FR-12): the daily
 * cap counts these. Projection of the synced "usage" events, rebuilt by
 * App\Actions\ReplayStudentEvents.
 */
class DailyUsage extends Model
{
    protected $table = 'daily_usage';

    public $incrementing = false;

    protected $primaryKey = null;

    protected $fillable = ['date', 'minutes'];

    protected function casts(): array
    {
        return [
            'date' => 'date:Y-m-d',
            'minutes' => 'integer',
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
