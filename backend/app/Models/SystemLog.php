<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * What the system saw: sign-ins, failed sign-ins, access decisions, sync
 * problems, server errors (FR-08 "retrieve system logs for anomaly monitoring").
 * `anomaly` marks rows the admin portal highlights.
 */
class SystemLog extends Model
{
    public const UPDATED_AT = null;

    /** Failed sign-ins from one IP within this many minutes ... */
    public const BURST_MINUTES = 15;

    /** ... reaching this count are an anomaly. */
    public const BURST_COUNT = 5;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'context' => 'array',
            'anomaly' => 'boolean',
            'created_at' => 'datetime',
        ];
    }

    /**
     * @param  array<string, mixed>  $context  never names or codes in clear: use student codes
     */
    public static function record(string $event, string $level = 'info', array $context = [], bool $anomaly = false, ?int $userId = null): self
    {
        $request = app()->runningInConsole() && ! app()->runningUnitTests() ? null : request();

        return static::create([
            'level' => $level,
            'event' => $event,
            'user_id' => $userId,
            'ip' => $request?->ip(),
            'context' => $context,
            'anomaly' => $anomaly,
        ]);
    }

    /**
     * A failed sign-in. Becomes an anomaly when the same IP failed
     * BURST_COUNT times within BURST_MINUTES (brute force, FR-08).
     *
     * @param  array<string, mixed>  $context
     */
    public static function failedLogin(string $event, array $context = []): self
    {
        $ip = request()->ip();
        $recent = static::query()
            ->where('event', $event)
            ->where('ip', $ip)
            ->where('created_at', '>=', now()->subMinutes(self::BURST_MINUTES))
            ->count();

        return static::record($event, 'warning', $context, $recent + 1 >= self::BURST_COUNT);
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
