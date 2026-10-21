<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * The AI-written summary paragraphs for one exact set of report facts
 * (FR-05, D-018), written by App\Jobs\WriteAiReport. `paragraphs` is null when
 * the AI output failed every check and the template was used instead.
 */
class AiReport extends Model
{
    public $timestamps = false;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'paragraphs' => 'array',
            'generated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<Student, $this>
     */
    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }

    /**
     * @return BelongsTo<AiLog, $this>
     */
    public function aiLog(): BelongsTo
    {
        return $this->belongsTo(AiLog::class);
    }
}
