<?php

namespace App\Enums;

/**
 * Event types the game client queues for POST /api/sync (FR-11). Payloads are
 * built in reading-racoon/scripts/core/lesson_session.gd,
 * reading-racoon/scripts/core/assessment_session.gd and
 * reading-racoon/scripts/autoload/game_state.gd. A type missing here is
 * rejected as `invalid`, so add each new `queue_event()` type to this list.
 */
enum SyncEventType: string
{
    // Lesson and assessment (lesson_session.gd, assessment_session.gd)

    // {item_id, skill, level, answer, correct, response_ms, rescue, num_choices, low_pl}
    // in a lesson; {item_id, skill, level, answer, correct, response_ms, assessment} in
    // the pre/post-test (FR-02, FR-10)
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
    // {type, skill, level, ...}: teacher intervention flag (FR-17); also
    // {type: clock_jump, from, to} when the device clock went backwards
    case Flag = 'flag';
    // {level, node, correct, total, stars, second_try} (FR-15)
    case LessonEnd = 'lesson_end';
    // {start_level}: where the pre-test placed the child (FR-02)
    case Placement = 'placement';
    // {kind: pre|post, scores, correct, total}: a finished pre/post-test (FR-02, FR-10)
    case Assessment = 'assessment';

    // Rewards and the Closet (game_state.gd)

    // {level, coins}: treasure chest opened on the path (D-007)
    case Chest = 'chest';
    // {item, price, coins_left}: bought in the shop (FR-07)
    case Purchase = 'purchase';
    // {equipped}: slot => item id after Racoon's outfit changed (FR-07)
    case Outfit = 'outfit';
    // {item, tier}: a Closet item earned by reaching its goal (D-026)
    case ItemEarned = 'item_earned';
    // {id, group}: a sticker added to the collection
    case Sticker = 'sticker';
    // {date, goal, all_done}: a daily goal reached
    case Goal = 'goal';

    // Free play (game_state.gd)

    // {id, first, questions_right, questions_total, seconds}: a Library book read
    case Book = 'book';
    // {id, first, check_right, seconds}: a Watch & Listen video or song finished
    case Media = 'media';
    // {game, correct, total, seconds}: a Practice game finished
    case Practice = 'practice';
    // {word, lang, from}: a word added to the child's word collection
    case Word = 'word';

    // Access and screen time (game_state.gd)

    // {status, time}: a section was closed by the schedule or free-play limit (FR-12, D-015)
    case Access = 'access';
    // {date, minutes, free_minutes}: today's play minutes, about once a minute (FR-12)
    case Usage = 'usage';
}
