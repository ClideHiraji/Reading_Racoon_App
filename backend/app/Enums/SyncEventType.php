<?php

namespace App\Enums;

/**
 * Event types the game client queues for POST /api/sync (FR-11). Payloads are
 * built in reading-racoon/scripts/core/lesson_session.gd and
 * reading-racoon/scripts/autoload/game_state.gd. App\Support\StudentReplay
 * documents which fields the server-side replay reads.
 */
enum SyncEventType: string
{
    // {item_id, skill, level, answer, correct, response_ms, rescue, num_choices?, assessment?: pre|post}
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
    // {type, skill, level, ...}: teacher intervention flag (FR-17); type clock_jump {from, to} is an admin anomaly
    case Flag = 'flag';
    // {level, node, correct, total, stars, ended_early?} (FR-15)
    case LessonEnd = 'lesson_end';
    // {level, coins}: treasure chest opened on the path (D-007)
    case Chest = 'chest';
    // {start_level}: pre-test placement done by StudentModel.place() (FR-02)
    case Placement = 'placement';
    // {kind: pre|post, scores: {skill: {correct, total}}, correct, total}: raw test scores (FR-02, FR-10)
    case Assessment = 'assessment';
    // {date, minutes}: after-school minutes played that day so far (FR-12)
    case Usage = 'usage';
    // {item, price, coins_left}: raccoon shop purchase (FR-07)
    case Purchase = 'purchase';
    // {equipped: {slot: item}}: what the raccoon wears now (FR-07)
    case Outfit = 'outfit';
    // {status, time}: the device showed a lock screen (FR-12), for the admin logs
    case Access = 'access';
}
