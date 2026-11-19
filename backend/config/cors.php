<?php

/*
|--------------------------------------------------------------------------
| Cross-origin requests (NFR-04, D-036)
|--------------------------------------------------------------------------
|
| The game is a native app (Android, Windows), so it needs no CORS at all,
| and the teacher and admin pages are same-origin. Laravel's built-in
| default would let any website's scripts call the API ("*"); here no other
| origin may, unless CORS_ALLOWED_ORIGINS names one (a future web build).
|
*/

return [
    'paths' => ['api/*'],
    'allowed_methods' => ['GET', 'POST'],
    'allowed_origins' => array_values(array_filter(array_map('trim',
        explode(',', (string) env('CORS_ALLOWED_ORIGINS', ''))))),
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['Accept', 'Authorization', 'Content-Type', 'If-None-Match', 'Range'],
    'exposed_headers' => ['ETag', 'Retry-After', 'X-Content-SHA256'],
    'max_age' => 3600,
    'supports_credentials' => false,
];
