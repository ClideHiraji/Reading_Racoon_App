<?php

namespace App\Enums;

/**
 * Today's access decision for a student (FR-12, docs/knowledge/06-game-design.md).
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

    public function canPlay(): bool
    {
        return $this === self::Allowed || $this === self::AfterSchool;
    }
}
