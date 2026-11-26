<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * After-school minutes a student played on one local date; the daily cap counts these.
 * Built from the synced "usage" events by App\Actions\ReplayStudentEvents.
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
