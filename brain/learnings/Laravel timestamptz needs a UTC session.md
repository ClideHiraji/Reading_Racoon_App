---
type: learning
date: 2026-10-20
tags: [learning, laravel, postgresql]
---

# Laravel timestamptz needs a UTC session

What happened: Eloquent writes dates as `Y-m-d H:i:s` with no offset. PostgreSQL reads such a value for a `timestamptz` column in the *session* time zone, which defaults to the server's (e.g., Asia/Manila). The app runs in UTC, so every saved time would be 8 hours off.

**So:** set `'timezone' => 'UTC'` on the `pgsql` connection in `config/database.php` (Laravel runs `set time zone 'UTC'` on connect). When writing times yourself, include the offset (`Y-m-d H:i:s.uP`). Also note Laravel's `timestampTz()` defaults to precision 0 (whole seconds, rounded); pass `6` where sub-seconds matter.

Related: [[D-008 Offline sync contract]], [[D-001 Backend Laravel + PostgreSQL]]
