<?php

/*
|--------------------------------------------------------------------------
| Reading Racoon settings
|--------------------------------------------------------------------------
|
| Served to the game by GET /api/config (FR-19) so thresholds can change
| without a new APK. The BKT values mirror the client's SkillCatalog and
| StudentModel (reading-racoon/scripts/core/) and docs/knowledge/05-bkt-engine.md.
|
*/

return [

    // Version of the game content package. The client re-downloads its
    // content when this is newer than its cached copy (FR-11).
    'content_version' => (int) env('CONTENT_VERSION', 1),

    // The game offers the post-test (FR-10) only while this is true. Turn it on
    // at the end of the evaluation period.
    'post_test_open' => (bool) env('POST_TEST_OPEN', false),

    'bkt' => [
        // Bump when any value below changes, e.g. after EM recalibration
        // (the versioned bkt_parameters table replaces this file later).
        'version' => 1,

        // A skill-level is mastered at P(L) >= 0.95 with >= 5 attempts (FR-04, D-003).
        'mastery_p' => 0.95,
        'mastery_min_attempts' => 5,

        // Raccoon hint only after a wrong answer that leaves P(L) below this (FR-14, D-003).
        'hint_p' => 0.30,

        // A failed Heart Recovery caps the lower skill-level's P(L) here (D-004).
        'demote_cap' => 0.70,

        // Level range per sub-skill (thesis Table 3.7, 14 states in total) and
        // P(L0) prior, P(T) learn, P(G) guess, P(S) slip (thesis Table 3.5). FR-03, FR-09.
        'skills' => [
            'phonological_awareness' => ['levels' => [1, 2], 'l0' => 0.20, 't' => 0.15, 'g' => 0.20, 's' => 0.10],
            'phonics' => ['levels' => [1, 3], 'l0' => 0.25, 't' => 0.18, 'g' => 0.20, 's' => 0.10],
            'vocabulary' => ['levels' => [2, 4], 'l0' => 0.30, 't' => 0.20, 'g' => 0.25, 's' => 0.12],
            'fluency' => ['levels' => [3, 5], 'l0' => 0.15, 't' => 0.12, 'g' => 0.15, 's' => 0.08],
            'literal_comprehension' => ['levels' => [3, 5], 'l0' => 0.20, 't' => 0.15, 'g' => 0.20, 's' => 0.10],
        ],
    ],

    'sync' => [
        // Most events accepted in one POST /api/sync; the client sends its queue in batches.
        'max_batch' => 500,

        // Largest JSON payload accepted for one event. Real payloads are under 300 bytes.
        'max_payload_bytes' => 8192,

        // A device clock this far ahead of the server is logged as an anomaly
        // (someone may be moving the clock to get round the schedule, open issue 10).
        'clock_ahead_minutes' => 5,
    ],

    // Rewards the server recomputes when it replays lesson_end and chest events
    // (FR-07, FR-15). Mirror LessonSession and PathProgress in the client.
    'rewards' => [
        'xp_per_correct' => 10,
        'coins_per_star' => 5,
        'level_up_coins' => 20,
        'chest_coins' => 15,
        'lessons_per_world' => 5,
    ],

    // Raccoon shop (FR-07), mirroring reading-racoon/scripts/core/wardrobe.gd:
    // id => slot and price. Starter items are owned and worn from the start.
    'shop' => [
        'starter' => ['scarf_teal'],
        'items' => [
            'cap' => ['slot' => 'hat', 'price' => 30],
            'party_hat' => ['slot' => 'hat', 'price' => 40],
            'flower_crown' => ['slot' => 'hat', 'price' => 50],
            'salakot' => ['slot' => 'hat', 'price' => 60],
            'gold_crown' => ['slot' => 'hat', 'price' => 120],
            'scarf_teal' => ['slot' => 'neck', 'price' => 0],
            'scarf_coral' => ['slot' => 'neck', 'price' => 25],
            'scarf_mango' => ['slot' => 'neck', 'price' => 25],
            'bow_tie' => ['slot' => 'neck', 'price' => 35],
            'lei' => ['slot' => 'neck', 'price' => 45],
            'round_glasses' => ['slot' => 'eyes', 'price' => 40],
            'sunglasses' => ['slot' => 'eyes', 'price' => 50],
            'star_glasses' => ['slot' => 'eyes', 'price' => 60],
            'pin_star' => ['slot' => 'badge', 'price' => 20],
            'pin_heart' => ['slot' => 'badge', 'price' => 20],
            'pin_book' => ['slot' => 'badge', 'price' => 30],
        ],
    ],

    // Map levels: world name (D-009), level name and the ARAL band teachers see
    // (docs/knowledge/05-bkt-engine.md, replaces thesis Table 3.6).
    'levels' => [
        1 => ['world' => 'Agusan River', 'name' => 'Foundational', 'band' => 'ARAL Basic'],
        2 => ['world' => 'Mango Grove', 'name' => 'Emerging', 'band' => 'ARAL Basic / Plus'],
        3 => ['world' => 'Bahay Kubo Village', 'name' => 'Developing', 'band' => 'ARAL Plus'],
        4 => ['world' => 'Balangay Bay', 'name' => 'Approaching', 'band' => 'Approaching Proficient'],
        5 => ['world' => 'Mount Mayapay', 'name' => 'Proficient', 'band' => 'Grade-Level Proficient'],
    ],

    // Teacher-facing sub-skill names (MATATAG competency areas, FR-09).
    'skill_labels' => [
        'phonological_awareness' => 'Phonological Awareness',
        'phonics' => 'Phonics',
        'vocabulary' => 'Vocabulary',
        'fluency' => 'Reading Fluency',
        'literal_comprehension' => 'Literal Comprehension',
    ],

    // Time-restricted access (FR-12, docs/knowledge/06-game-design.md). A section
    // without its own schedule uses these defaults.
    'access' => [
        'timezone' => env('SCHOOL_TIMEZONE', 'Asia/Manila'),
        'defaults' => [
            'class_start' => '07:30',
            'class_end' => '08:30',
            'after_school_start' => '15:00',
            'after_school_end' => '17:00',
            'daily_minutes' => 30,
            'weekends_open' => false,
        ],
    ],

];
