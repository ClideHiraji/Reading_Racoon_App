<?php

namespace App\Models;

use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A section's play windows (FR-12, docs/knowledge/06-game-design.md). Times are
 * wall-clock times in the school's time zone (reading_racoon.access.timezone).
 * A section without a row uses config reading_racoon.access.defaults.
 */
class AccessSchedule extends Model
{
    protected $primaryKey = 'section_id';

    public $incrementing = false;

    protected $fillable = ['class_start', 'class_end', 'after_school_start', 'after_school_end', 'daily_minutes', 'weekends_open'];

    protected function casts(): array
    {
        return [
            'daily_minutes' => 'integer',
            'weekends_open' => 'boolean',
        ];
    }

    /** The section's schedule, or an unsaved one holding the defaults. */
    public static function forSection(int $sectionId): self
    {
        $schedule = static::find($sectionId);
        if ($schedule === null) {
            $schedule = new static(config('reading_racoon.access.defaults'));
            $schedule->section_id = $sectionId;
        }

        return $schedule;
    }

    /**
     * @return BelongsTo<Section, $this>
     */
    public function section(): BelongsTo
    {
        return $this->belongsTo(Section::class);
    }

    /** "07:30:00" from PostgreSQL, "07:30" from config → "07:30". */
    public function hm(string $column): string
    {
        return substr((string) $this->getAttribute($column), 0, 5);
    }

    /**
     * The window [start, end) on the local day of $local.
     *
     * @return array{0: CarbonImmutable, 1: CarbonImmutable}
     */
    public function window(string $name, CarbonImmutable $local): array
    {
        return [$local->setTimeFromTimeString($this->hm("{$name}_start")),
            $local->setTimeFromTimeString($this->hm("{$name}_end"))];
    }

    /**
     * The schedule as the game receives it in GET /api/access/student/status.
     *
     * @return array{class_start: string, class_end: string, after_school_start: string, after_school_end: string, daily_minutes: int, weekends_open: bool, timezone: string}
     */
    public function toApi(): array
    {
        return [
            'class_start' => $this->hm('class_start'),
            'class_end' => $this->hm('class_end'),
            'after_school_start' => $this->hm('after_school_start'),
            'after_school_end' => $this->hm('after_school_end'),
            'daily_minutes' => $this->daily_minutes,
            'weekends_open' => $this->weekends_open,
            'timezone' => config('reading_racoon.access.timezone'),
        ];
    }
}
