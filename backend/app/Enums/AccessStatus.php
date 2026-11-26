<?php

namespace App\Enums;

/**
 * Today's play decision for a student.
 */
enum AccessStatus: string
{
    // Class window: everything, including the pre/post-test.
    case Allowed = 'allowed';
    // After-school window, or a weekend the teacher opened: play within the daily cap.
    case AfterSchool = 'after_school';
    // A weekday outside both windows: "Come back during Reading time".
    case ClassLock = 'class_lock';
    // The daily cap is used up: "Great work today! See you tomorrow".
    case DailyLimit = 'daily_limit';
    // A weekend the teacher hasn't opened: "Game is sleeping".
    case WeekendLock = 'weekend_lock';
    // Night, outside day_start..day_end: everything sleeps.
    case Sleeping = 'sleeping';

    public function canPlay(): bool
    {
        return $this === self::Allowed || $this === self::AfterSchool;
    }
}
