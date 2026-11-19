---
type: learning
date: 2026-11-19
status: confirmed
tags: [learning, laravel, apache, windows, performance]
---

# Laravel needs config cache under threaded Apache

On Windows, Apache runs PHP (mod_php, thread-safe build) in threads of one process. Laravel loads `.env` into the environment on every request, and that isn't thread-safe: in a load test (150 requests at once) 4 of 300 failed with `SQLSTATE[08006] fe_sendauth: no password supplied`, because a request read the environment while another was loading it.

**Fix:** `php artisan config:cache` (and again after every `.env` change). Cached config never reads `.env`. `php artisan app:preflight` fails a production box without it.

**Also on XAMPP:** OPcache is off by default (`;zend_extension=opcache` in `php.ini`). Every request recompiled Laravel: `GET /api/config` took 290 ms, 75 ms with OPcache. A PostgreSQL connection costs about 50 ms on Windows (a process per connection), which is most of what's left.

**Careful when testing:** `config:cache` with `DB_DATABASE=reading_racoon_test` points every artisan command (and the test suite) at the test database until `php artisan optimize:clear`. And `php artisan serve` strips variables that are in `.env` from its child process, so `DB_DATABASE=... php artisan serve` still uses the `.env` database; start `php -S` from `public/` instead.

Seen while load-testing [[D-036 Internet hosting from the home laptop]].
