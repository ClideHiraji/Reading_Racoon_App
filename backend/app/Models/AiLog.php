<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One LLM call (FR-21, MLDLC Stage 6): what was injected into the prompt, the
 * reply, and whether it was used. `status` is ok (used), invalid (failed the
 * checks against the facts), blocked (empty or safety-filtered) or error
 * (HTTP error or timeout). Read by the admin portal's AI log.
 */
class AiLog extends Model
{
    public const UPDATED_AT = null;

    public const TEACHER_REPORT = 'teacher_report';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'input' => 'array',
            'latency_ms' => 'integer',
            'prompt_tokens' => 'integer',
            'completion_tokens' => 'integer',
            'created_at' => 'datetime',
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
