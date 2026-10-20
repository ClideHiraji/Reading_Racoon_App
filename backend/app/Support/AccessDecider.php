<?php

namespace App\Support;

use App\Enums\AccessStatus;
use App\Models\AccessSchedule;
use Carbon\CarbonImmutable;

/**
 * Today's access decision for a student (FR-12, docs/knowledge/06-game-design.md
 * "Time-restricted access"), evaluated in the school's time zone.
 *
 * - Weekday class window: allowed (everything), counting down to the end of class.
 * - Weekday after-school window: play within the daily cap (after_school),
 *   or daily_limit once the cap is used.
 * - Any other weekday time: class_lock.
 * - Weekend: weekend_lock, unless the teacher opened weekends; then the same
 *   daily cap applies all day.
 * Minutes played in the class window never count toward the cap.
 */
final class AccessDecider
{
    /**
     * @return array{status: AccessStatus, minutes_left: int, window: ?string, opens_at: ?string}
     */
    public function decide(AccessSchedule $schedule, int $usedMinutes, CarbonImmutable $now): array
    {
        $local = $now->setTimezone(config('reading_racoon.access.timezone'));
        $capLeft = max(0, $schedule->daily_minutes - $usedMinutes);

        if ($local->isWeekend()) {
            if (! $schedule->weekends_open) {
                return $this->locked(AccessStatus::WeekendLock, $schedule, $local);
            }
            if ($capLeft === 0) {
                return $this->locked(AccessStatus::DailyLimit, $schedule, $local, skipToday: true);
            }

            return $this->open(AccessStatus::AfterSchool, min($capLeft, self::minutesUntil($local, $local->addDay()->startOfDay())), 'weekend');
        }

        [$classStart, $classEnd] = $schedule->window('class', $local);
        if ($local->greaterThanOrEqualTo($classStart) && $local->lessThan($classEnd)) {
            return $this->open(AccessStatus::Allowed, self::minutesUntil($local, $classEnd), 'class');
        }

        [$afterStart, $afterEnd] = $schedule->window('after_school', $local);
        if ($local->greaterThanOrEqualTo($afterStart) && $local->lessThan($afterEnd)) {
            if ($capLeft === 0) {
                return $this->locked(AccessStatus::DailyLimit, $schedule, $local, skipAfterSchoolToday: true);
            }

            return $this->open(AccessStatus::AfterSchool, min($capLeft, self::minutesUntil($local, $afterEnd)), 'after_school');
        }

        return $this->locked(AccessStatus::ClassLock, $schedule, $local);
    }

    /**
     * @return array{status: AccessStatus, minutes_left: int, window: ?string, opens_at: ?string}
     */
    private function open(AccessStatus $status, int $minutesLeft, string $window): array
    {
        return ['status' => $status, 'minutes_left' => max(0, $minutesLeft), 'window' => $window, 'opens_at' => null];
    }

    /**
     * @return array{status: AccessStatus, minutes_left: int, window: ?string, opens_at: ?string}
     */
    private function locked(AccessStatus $status, AccessSchedule $schedule, CarbonImmutable $local, bool $skipToday = false, bool $skipAfterSchoolToday = false): array
    {
        return [
            'status' => $status,
            'minutes_left' => 0,
            'window' => null,
            'opens_at' => $this->nextOpening($schedule, $local, $skipToday, $skipAfterSchoolToday)?->utc()->toIso8601ZuluString(),
        ];
    }

    /** The next time play opens, looking a week ahead (holidays aren't modelled yet). */
    private function nextOpening(AccessSchedule $schedule, CarbonImmutable $local, bool $skipToday, bool $skipAfterSchoolToday): ?CarbonImmutable
    {
        for ($i = 0; $i <= 7; $i++) {
            if ($i === 0 && $skipToday) {
                continue;
            }
            $day = $local->startOfDay()->addDays($i);
            if ($day->isWeekend()) {
                $starts = $schedule->weekends_open ? [$day] : [];
            } else {
                $starts = [$schedule->window('class', $day)[0]];
                if (! ($i === 0 && $skipAfterSchoolToday)) {
                    $starts[] = $schedule->window('after_school', $day)[0];
                }
            }
            foreach ($starts as $start) {
                if ($start->greaterThan($local)) {
                    return $start;
                }
            }
        }

        return null;
    }

    private static function minutesUntil(CarbonImmutable $from, CarbonImmutable $to): int
    {
        return (int) ceil(($to->getTimestamp() - $from->getTimestamp()) / 60);
    }
}
