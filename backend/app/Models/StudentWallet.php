<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * XP and coin balance (FR-07, FR-15).
 */
class StudentWallet extends Model
{
    protected $primaryKey = 'student_id';

    public $incrementing = false;

    protected $fillable = ['xp', 'coins'];

    protected function casts(): array
    {
        return [
            'xp' => 'integer',
            'coins' => 'integer',
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
