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
    ],

];
