<?php

/*
|--------------------------------------------------------------------------
| Hidden admin portal (FR-08, FR-22, D-012)
|--------------------------------------------------------------------------
|
| The portal has no public entrance. Its routes exist only under a secret
| path prefix from .env, every refused request gets the site's ordinary 404,
| sign-in needs a password plus a TOTP code, and admins are created only
| with `php artisan admin:create`. Never put a real ADMIN_PATH in code,
| docs or git.
|
*/

return [

    // Secret URL prefix, e.g. https://host/<ADMIN_PATH>. At least 32 characters
    // of letters, digits, "-" or "_". Empty or too short = the portal is off.
    // Generate one with: php -r "echo bin2hex(random_bytes(24)), PHP_EOL;"
    'path' => env('ADMIN_PATH', ''),

    'min_path_length' => 32,

    // Optional comma-separated IPs or CIDR ranges (e.g. "203.0.113.7,10.0.0.0/24").
    // Checked before anything else. Empty = any IP (the secret path, password
    // and TOTP still apply). Behind a reverse proxy, configure trusted proxies
    // so the client IP is right.
    'allowed_ips' => array_values(array_filter(array_map('trim', explode(',', (string) env('ADMIN_ALLOWED_IPS', ''))))),

    // An admin session idle this long is signed out.
    'idle_minutes' => (int) env('ADMIN_IDLE_MINUTES', 30),

    // Failed sign-ins allowed per IP and per email before the form answers 404
    // for `login_decay_minutes`.
    'login_max_attempts' => 5,
    'login_decay_minutes' => 15,

    // TOTP codes accepted this many 30-second steps before/after now.
    'totp_window' => 1,

    // Name shown in the authenticator app.
    'totp_issuer' => env('APP_NAME', 'Reading Racoon').' Admin',

];
