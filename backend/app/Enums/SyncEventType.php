<?php

namespace App\Enums;

/**
 * Event types the game client queues for POST /api/sync (FR-11). Payloads are
 * built in reading-racoon/scripts/core/lesson_session.gd and
 * reading-racoon/scripts/autoload/game_state.gd.
 */
enum SyncEventType: string
{
    // {item_id, skill, level, answer, correct, response_ms, rescue}
    case Response = 'response';
    // {skill, level, p, posterior, attempts, mastered} after each BKT update (FR-03)
    case BktState = 'bkt_state';
    // {hearts} (FR-13)
    case Hearts = 'hearts';
    // {skill, level}: Racoon's Rescue started (D-004)
    case RescueStart = 'rescue_start';
    // {skill, correct, full}
    case RescueEnd = 'rescue_end';
    // {to_level} (FR-04)
    case LevelUp = 'level_up';
    // {type, skill, level, ...}: teacher intervention flag (FR-17)
    case Flag = 'flag';
    // {level, node, correct, total, stars} (FR-15)
    case LessonEnd = 'lesson_end';
    // {level, coins}: treasure chest opened on the path (D-007)
    case Chest = 'chest';
}
