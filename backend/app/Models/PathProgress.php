<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Highest unlocked map level and the path state per world.
 */
class PathProgress extends Model
{
    protected $table = 'path_progress';

    protected $primaryKey = 'student_id';

    public $incrementing = false;

    protected $fillable = ['highest_unlocked', 'worlds'];

    protected function casts(): array
    {
        return [
            'highest_unlocked' => 'integer',
            'worlds' => 'array',
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
