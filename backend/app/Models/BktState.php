<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * BKT state of one (sub-skill, level) for one student: 14 per student (D-003).
 * FR-03, FR-04.
 */
class BktState extends Model
{
    protected $fillable = ['sub_skill', 'level', 'p_mastery', 'attempts', 'mastered_at', 'review'];

    protected function casts(): array
    {
        return [
            'level' => 'integer',
            'p_mastery' => 'float',
            'attempts' => 'integer',
            'mastered_at' => 'datetime',
            'review' => 'boolean',
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
