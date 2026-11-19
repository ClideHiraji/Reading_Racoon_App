<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * One admin or teacher action (FR-08, FR-22, NFR-04). The table is
 * append-only: a PostgreSQL trigger refuses UPDATE and DELETE.
 */
class AuditLog extends Model
{
    public const UPDATED_AT = null;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'details' => 'array',
            'created_at' => 'datetime',
        ];
    }

    /**
     * Writes one entry. $subject is a model (stored as its type and key) or a
     * [type, id] pair, e.g. ['student', 'RR-7K2M9Q'] so the entry still makes
     * sense after the student is removed.
     *
     * @param  Model|array{0: string, 1: string|int}|null  $subject
     * @param  array<string, mixed>  $details
     */
    public static function record(?User $actor, string $action, Model|array|null $subject = null, array $details = []): self
    {
        [$type, $id] = match (true) {
            $subject instanceof Model => [strtolower(class_basename($subject)), $subject->getKey()],
            is_array($subject) => $subject,
            default => [null, null],
        };
        $request = app()->runningInConsole() && ! app()->runningUnitTests() ? null : request();

        return static::create([
            'actor_id' => $actor?->id,
            'actor_role' => $actor?->role?->value,
            'actor_label' => $actor?->email ?? $actor?->name,
            'action' => $action,
            'subject_type' => $type,
            'subject_id' => $id === null ? null : (string) $id,
            'details' => $details,
            'ip' => $request?->ip(),
            'user_agent' => $request === null ? null : substr((string) $request->userAgent(), 0, 255),
        ]);
    }
}
