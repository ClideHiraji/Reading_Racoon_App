<?php

// The teacher and admin pages live in backend/frontend, not Laravel's usual resources/views.
// After changing this, run "php artisan config:cache" on the server or every page 404s.
return [
    'paths' => [base_path('frontend')],
];
