<?php

/*
|--------------------------------------------------------------------------
| Reading Racoon settings
|--------------------------------------------------------------------------
|
| Sent to the game by GET /api/config, so thresholds can change without a new APK.
| The BKT values must match the game's SkillCatalog and StudentModel
| (reading-racoon/scripts/core/) and docs/knowledge/05-bkt-engine.md.
|
*/

return [

    // Version of the game content package. The game downloads its content again
    // when this is newer than its saved copy.
    'content_version' => (int) env('CONTENT_VERSION', 1),

    // The game offers the post-test only while this is true.
    // Turn it on at the end of the evaluation period.
    'post_test_open' => (bool) env('POST_TEST_OPEN', false),

    'bkt' => [
        // Bump when any value below changes, e.g. after EM recalibration
        // (the versioned bkt_parameters table replaces this file later).
        'version' => 1,

        // A skill level is mastered at P(L) >= 0.95 with >= 5 tries.
        'mastery_p' => 0.95,
        'mastery_min_attempts' => 5,

        // Racoon's hint only after a wrong answer that leaves P(L) below this.
        'hint_p' => 0.30,

        // A failed rescue caps the lower skill level's P(L) here.
        'demote_cap' => 0.70,

        // Level range per sub-skill (14 states in total) and P(L0) start, P(T) learn,
        // P(G) guess, P(S) slip, from the thesis tables.
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
        // (someone may be moving the clock to get round the schedule).
        'clock_ahead_minutes' => 5,

        // The server replay runs in a queued job this many seconds after a sync, not inside the
        // request: a device uploading a backlog in many batches costs one replay, and a replay
        // error never blocks the acknowledgement the device needs to empty its queue.
        'replay_delay_seconds' => (int) env('SYNC_REPLAY_DELAY_SECONDS', 5),
    ],

    // Rewards the server works out again when it replays lesson_end and chest events.
    // Must match LessonSession and PathProgress in the game.
    'rewards' => [
        'xp_per_correct' => 10,
        'coins_per_star' => 5,
        'level_up_coins' => 20,
        'chest_coins' => 15,
        'lessons_per_world' => 5,
    ],

    // Raccoon shop, must match reading-racoon/scripts/core/wardrobe.gd:
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

    // Map levels: world name, level name and the ARAL band teachers see
    // (see docs/knowledge/05-bkt-engine.md).
    'levels' => [
        1 => ['world' => 'Agusan River', 'name' => 'Foundational', 'band' => 'ARAL Basic'],
        2 => ['world' => 'Mango Grove', 'name' => 'Emerging', 'band' => 'ARAL Basic / Plus'],
        3 => ['world' => 'Bahay Kubo Village', 'name' => 'Developing', 'band' => 'ARAL Plus'],
        4 => ['world' => 'Balangay Bay', 'name' => 'Approaching', 'band' => 'Approaching Proficient'],
        5 => ['world' => 'Mount Mayapay', 'name' => 'Proficient', 'band' => 'Grade-Level Proficient'],
    ],

    // Teacher-picked Library books and Watch & Listen videos. The game shows them as
    // "From your teacher". Only openly licensed material; files are private and reached
    // only through the API.
    'content' => [
        'languages' => ['en' => 'English', 'fil' => 'Filipino', 'bis' => 'Bisaya'],
        'levels' => ['easy', 'medium', 'hard'],
        // Paper-cut scenes the game can draw.
        'scenes' => ['river', 'grove', 'village', 'bay', 'mountain', 'home'],
        'licences' => ['CC BY 4.0', 'CC BY-SA 4.0', 'CC BY-NC 4.0', 'CC BY-NC-SA 4.0', 'CC BY 3.0', 'CC0 1.0', 'Public domain'],
        // Picture names the game has icons for (reading-racoon/assets/icons).
        'pictures' => ['ant', 'apple', 'bag', 'ball', 'banana', 'bear', 'bee', 'boat', 'bolt', 'book', 'box', 'bulb', 'bus',
            'butterfly', 'cake', 'car', 'cat', 'check', 'chest', 'chest_open', 'cloud', 'coins', 'crown', 'dog', 'ear',
            'elephant', 'fish', 'fox', 'frog', 'gift', 'goat', 'grapes', 'hand', 'hat', 'heart', 'heart_plus', 'hen',
            'house', 'hut', 'lock', 'moon', 'mountain', 'mouse', 'night', 'palm', 'pear', 'pencil', 'rabbit', 'raccoon',
            'repeat', 'scissors', 'snake', 'sparkles', 'speaker', 'star', 'stories', 'sun', 'talk', 'tree', 'trophy', 'waves'],
        'max_pages' => 12,
        'max_video_mb' => (int) env('CONTENT_MAX_VIDEO_MB', 50),
        'max_image_kb' => 2048,
        // Laravel's private "local" disk (storage/app/private): never web-served.
        'disk' => 'local',
    ],

    // The Gemini teacher report (see docs/knowledge/08-ai-integration.md).
    // Only for learners with parental consent on file, and only while services.llm is set.
    'ai_report' => [
        // Thesis prompt design (MLDLC Stage 3): temperature 0.3, ~250 tokens of text.
        'temperature' => 0.3,
        // The prompt asks for at most max_words; the checks refuse replies 20% longer.
        // max_tokens leaves headroom over the thesis's 250 for thinking tokens.
        'max_words' => 150,
        'max_tokens' => (int) env('LLM_REPORT_MAX_TOKENS', 600),
        // Per call, and calls per report (1 + 2 retries); then the template is used.
        'timeout_seconds' => 30,
        'attempts' => 3,
        // Wait this long after a sync before writing, so one play session
        // (several syncs) gives one report.
        'delay_minutes' => (int) env('LLM_REPORT_DELAY_MINUTES', 10),
    ],

    // Sub-skill names teachers see (MATATAG competency areas).
    'skill_labels' => [
        'phonological_awareness' => 'Phonological Awareness',
        'phonics' => 'Phonics',
        'vocabulary' => 'Vocabulary',
        'fluency' => 'Reading Fluency',
        'literal_comprehension' => 'Literal Comprehension',
    ],

    // Play-time limits. A section without its own schedule uses these defaults.
    'access' => [
        'timezone' => env('SCHOOL_TIMEZONE', 'Asia/Manila'),
        'defaults' => [
            'class_start' => '07:30',
            'class_end' => '08:30',
            'after_school_start' => '15:00',
            'after_school_end' => '17:00',
            'daily_minutes' => 30,
            'weekends_open' => false,
            // Free-play minutes for Practice, Library and Watch & Listen outside the class window,
            // and the hours the game is awake.
            'free_play_minutes' => 45,
            'day_start' => '06:00',
            'day_end' => '21:00',
        ],
    ],

    // Internet hosting from the home laptop (see docs/deploy/home-server.md).
    'security' => [
        // Strict-Transport-Security max-age on https responses (180 days).
        'hsts_seconds' => (int) (env('HSTS_SECONDS') ?: 15552000),
        // Secret for the login-code HMAC. Empty: derived from APP_KEY. Changing
        // it (or APP_KEY while this is empty) invalidates every login code.
        'login_code_key' => env('LOGIN_CODE_KEY', ''),
    ],

    // How long rows stay in the admin system log. Anomalies and warnings are kept longer
    // than routine info lines (access checks). The audit log is never pruned.
    'logs' => [
        'system_info_days' => (int) (env('SYSTEM_LOG_INFO_DAYS') ?: 90),
        'system_anomaly_days' => (int) (env('SYSTEM_LOG_ANOMALY_DAYS') ?: 365),
    ],

    // Nightly PostgreSQL backup (`php artisan app:backup`, scheduled in routes/console.php).
    'backup' => [
        // Folder for the dumps. Keep it off the system drive if you can.
        'path' => env('BACKUP_PATH') ?: storage_path('app/backups'),
        // Optional second copy, e.g. a Google Drive or USB folder (off-site copy).
        'copy_to' => env('BACKUP_COPY_TO', ''),
        // How many dumps to keep in each folder.
        'keep' => (int) env('BACKUP_KEEP') ?: 14,
        // pg_dump / pg_restore, by full path if they aren't on PATH, e.g.
        // C:\Program Files\PostgreSQL\18\bin\pg_dump.exe
        'pg_dump' => env('BACKUP_PG_DUMP') ?: 'pg_dump',
        'pg_restore' => env('BACKUP_PG_RESTORE') ?: 'pg_restore',
        'timeout_seconds' => 900,
    ],
];
