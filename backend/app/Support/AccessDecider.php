<?php

namespace App\Support;

use App\Enums\AccessStatus;
use App\Models\AccessSchedule;
use Carbon\CarbonImmutable;

/**
 * Today's play decision for a student, in the school's time zone.
 * Must match the game's reading-racoon/scripts/core/access_policy.gd.
 *
 * - Weekday class window: allowed (everything), counting down to the end of class.
 * - Weekday after-school window: play up to the daily cap (after_school),
 *   then daily_limit once it's used.
 * - Any other weekday time: class_lock.
 * - Weekend: weekend_lock, unless the teacher opened weekends; then the daily cap applies all day.
 * - Night (before day_start or from day_end): sleeping.
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

        $closedWeekend = $local->isWeekend() && ! $schedule->weekends_open;
        if (! $closedWeekend) {
            [$dayStart, $dayEnd] = $schedule->window('day', $local);
            if ($local->lessThan($dayStart) || $local->greaterThanOrEqualTo($dayEnd)) {
                return $this->locked(AccessStatus::Sleeping, $schedule, $local);
            }
        }

        if ($local->isWeekend()) {
            if ($closedWeekend) {
                return $this->locked(AccessStatus::WeekendLock, $schedule, $local);
            }
            if ($capLeft === 0) {
                return $this->locked(AccessStatus::DailyLimit, $schedule, $local, skipToday: true);
            }

            return $this->open(AccessStatus::AfterSchool, min($capLeft, self::minutesUntil($local, $schedule->window('day', $local)[1])), 'weekend');
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
                $starts = $schedule->weekends_open ? [$schedule->window('day', $day)[0]] : [];
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
