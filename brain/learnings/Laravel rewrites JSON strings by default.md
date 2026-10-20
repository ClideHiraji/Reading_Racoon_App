---
type: learning
date: 2026-10-20
tags: [learning, laravel, sync]
---

# Laravel rewrites JSON strings by default

What happened: Laravel's global `TrimStrings` and `ConvertEmptyStringsToNull` middleware also rewrite JSON request bodies, deep inside nested objects. A synced answer `"  cat "` would be saved as `"cat"`, and `""` as `null`. Separately, PostgreSQL `jsonb` rejects the `\u0000` character, so one such string fails the whole insert.

**So:** for endpoints that store raw data (`/api/sync`), skip both middlewares in `bootstrap/app.php` (`$middleware->trimStrings(except: [fn ($r) => $r->is('api/sync')])`, same for `convertEmptyStringsToNull`), and reject NUL characters per event before inserting.

Related: [[D-008 Offline sync contract]]
