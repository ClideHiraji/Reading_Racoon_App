# Reading Racoon backend (Laravel API)

The server for the Reading Racoon game: **Laravel 12 (PHP 8.2+) + PostgreSQL 16+ + Sanctum**, custom-coded as the professor requires ([D-001](../brain/decisions/D-001%20Backend%20Laravel%20+%20PostgreSQL.md)). It receives the events the Godot client in [`reading-racoon/`](../reading-racoon/) queues offline, and serves remote config.

Spec: [`docs/knowledge/03-architecture.md`](../docs/knowledge/03-architecture.md) (API, offline sync) and [`04-data-model.md`](../docs/knowledge/04-data-model.md). Sync contract decision: [D-008](../brain/decisions/D-008%20Offline%20sync%20contract.md).

> Composer picked Laravel 12 because XAMPP ships PHP 8.2; Laravel 13 needs PHP 8.3+.

## Set up on Windows (XAMPP PHP + PostgreSQL)

1. **Enable PostgreSQL in PHP.** In `C:\xampp\php\php.ini`, remove the `;` in front of `extension=pdo_pgsql` and `extension=pgsql`. Check with `php -m` (both should be listed). XAMPP already ships the DLLs and `libpq.dll`.
2. **Install PostgreSQL** (16, 17 or 18; the dev PC runs 18.6). The installer asks for a password for the `postgres` superuser: write it down. Only *PostgreSQL Server* and *Command Line Tools* are needed; skip Stack Builder.
   ```bash
   winget install --id PostgreSQL.PostgreSQL.18 -e --interactive
   ```
   Check it with `"/c/Program Files/PostgreSQL/18/bin/pg_isready.exe" -h 127.0.0.1` (should say `accepting connections`). Lost the `postgres` password? See [Reset a lost postgres password](../brain/learnings/Reset%20a%20lost%20postgres%20password.md).
3. **Create the app role and the two databases** (the test database is wiped by every test run). `createuser -P` asks for the new role's password (it goes in `.env` next); every command then asks for the `postgres` password. Nothing ends up in your shell history.
   ```bash
   "/c/Program Files/PostgreSQL/18/bin/createuser.exe" -h 127.0.0.1 -U postgres -P reading_racoon
   "/c/Program Files/PostgreSQL/18/bin/createdb.exe" -h 127.0.0.1 -U postgres -O reading_racoon reading_racoon
   "/c/Program Files/PostgreSQL/18/bin/createdb.exe" -h 127.0.0.1 -U postgres -O reading_racoon reading_racoon_test
   ```
4. **Configure and migrate** (from `backend/`):
   ```bash
   composer install
   cp .env.example .env
   php artisan key:generate
   ```
   Put the role's password in `.env` as `DB_PASSWORD=...` (never commit `.env`), then:
   ```bash
   php artisan migrate --seed
   ```
   The seeder creates the section "Grade 1 - Demo" with students Ana and Ben and **prints their login codes once** (only hashes are stored).
5. **Run it:** `php artisan serve` (http://127.0.0.1:8000). An Android phone on the same Wi-Fi needs `php artisan serve --host=0.0.0.0` and the PC's LAN address.

## Test

```bash
php artisan test
```

Tests run on the `reading_racoon_test` PostgreSQL database (`phpunit.xml`), never SQLite. `tests/Unit` and `tests/Feature/Api/ConfigTest.php` don't touch the database. All 34 pass on PostgreSQL 18.6.

`php artisan db:show` needs PHP's `intl` extension for its size column (`extension=intl` in `php.ini`); the app itself doesn't.

## API v1

All bodies are JSON. Errors are JSON too, even without an `Accept: application/json` header: `401` no/bad token, `403` wrong role, `422` validation (`{"message", "errors": {field: [...]}}`), `429` rate limit.

### `POST /api/auth/login` (FR-01)

**Temporary student login by code** until open issue 9 picks the real method. Codes look like `K7PM-3QXA`: 8 characters without 0/O/1/I/L; case, spaces and dashes are ignored. Limit: 60 attempts per minute per IP (a whole class shares the school's address).

```json
{"login_code": "K7PM-3QXA", "device_name": "Tablet 3"}
```
`200`:
```json
{
  "token": "1|Xy...",
  "token_type": "Bearer",
  "user": {"id": 1, "role": "student", "name": "Ana"},
  "student": {"id": 1, "section_id": 1}
}
```
Wrong or malformed code: `422` with `errors.login_code`. Send the token as `Authorization: Bearer <token>`. Tokens don't expire yet.

### `GET /api/config` (FR-19)

Public. The client caches it and re-downloads content when `content_version` is newer than its own.

```json
{
  "content_version": 1,
  "server_time": "2026-10-20T04:35:00Z",
  "bkt": {
    "version": 1,
    "mastery_p": 0.95,
    "mastery_min_attempts": 5,
    "hint_p": 0.3,
    "demote_cap": 0.7,
    "skills": {
      "phonological_awareness": {"levels": [1, 2], "l0": 0.2, "t": 0.15, "g": 0.2, "s": 0.1},
      "phonics": {"levels": [1, 3], "l0": 0.25, "t": 0.18, "g": 0.2, "s": 0.1},
      "vocabulary": {"levels": [2, 4], "l0": 0.3, "t": 0.2, "g": 0.25, "s": 0.12},
      "fluency": {"levels": [3, 5], "l0": 0.15, "t": 0.12, "g": 0.15, "s": 0.08},
      "literal_comprehension": {"levels": [3, 5], "l0": 0.2, "t": 0.15, "g": 0.2, "s": 0.1}
    }
  },
  "sync": {"max_batch": 500}
}
```
Values live in [`config/reading_racoon.php`](config/reading_racoon.php) (`CONTENT_VERSION` in `.env`). They mirror `reading-racoon/scripts/core/skill_catalog.gd` and `student_model.gd`.

### `POST /api/sync` (FR-11)

Student token only. Send the lines of `user://event_queue.jsonl` in queue order, at most `max_batch` per request:

```json
{"events": [
  {"id": "6f1c3d5e-6a2b-4c8d-9e0f-112233445566", "type": "response",
   "payload": {"item_id": "pa1-01", "skill": "phonological_awareness", "level": 1, "answer": "hat",
               "correct": true, "response_ms": 2350, "rescue": false},
   "device_time": "2026-10-20T04:34:56Z"}
]}
```
- `id`: the client's UUID, the idempotency key. `type`: `response`, `bkt_state`, `hearts`, `rescue_start`, `rescue_end`, `level_up`, `flag`, `lesson_end` or `chest`. `payload`: a JSON object, stored as-is (max 8 KB). `device_time`: ISO 8601 with `Z` or an offset.

`200`:
```json
{
  "acknowledged": ["6f1c3d5e-6a2b-4c8d-9e0f-112233445566"],
  "rejected": [{"index": 3, "id": "not-a-uuid", "reason": "invalid", "errors": {"id": ["The id field must be a valid UUID."]}}],
  "server_time": "2026-10-20T04:35:00Z"
}
```
**What the client does with it:**
- Delete every `acknowledged` id from the queue. An event the server already had is acknowledged again, so resending a whole batch after a lost response is safe and never duplicates.
- Delete every `rejected` id too (it will never be accepted); keep a local copy for debugging. `reason` is `invalid` (see `errors`) or `id_conflict` (that UUID belongs to another student).
- Keep anything in neither list and retry later.
- A `422` means the envelope itself is wrong (no `events` list, or too many events): fix the request, don't drop events.

The server stores the raw events only. Replaying them through server-side BKT and filling `bkt_states`, `intervention_flags`, `student_wallets` and `path_progress` is the next slice.

## Database

| Table | Holds | Keys |
|---|---|---|
| `users` | All roles (`role`), email + password for staff, `login_code_hash` for students | bigint |
| `sections`, `students` | Class sections and their learners | bigint |
| `bkt_states` | 14 per student: `(sub_skill, level)`, `p_mastery`, `attempts`, `mastered_at`, `review` | unique per student |
| `path_progress` | `highest_unlocked` map level and the path's `worlds` (jsonb) | `student_id` |
| `student_wallets` | `xp`, `coins` | `student_id` |
| `intervention_flags` | Teacher alerts with `open`/`resolved` status | uuid (raised offline) |
| `sync_events` | Raw client events: `uuid` (unique), `type`, `payload` jsonb, `device_time`, `received_at` | bigint `id` = arrival order |

All times are `timestamptz`; the connection runs in UTC. `App\Actions\EnrollStudent` creates a student with their login code, 14 BKT states at P(L0), wallet and path.

## Layout

| Path | What |
|---|---|
| `app/Http/Controllers/Api/` | `LoginController`, `ConfigController`, `SyncController` |
| `app/Actions/` | `EnrollStudent`, `RecordSyncEvents` |
| `app/Support/` | `LoginCode`, `SkillCatalog` |
| `app/Enums/` | `UserRole`, `SyncEventType` |
| `config/reading_racoon.php` | BKT parameters, thresholds, content version, sync limits |
| `database/migrations/` | Schema (PostgreSQL only) |
| `tests/` | PHPUnit feature and unit tests |
