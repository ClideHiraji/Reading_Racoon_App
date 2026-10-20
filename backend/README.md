# Reading Racoon backend (Laravel API + teacher and admin web)

The server for the Reading Racoon game: **Laravel 12 (PHP 8.2+) + PostgreSQL 16+ + Sanctum**, custom-coded as the professor requires ([D-001](../brain/decisions/D-001%20Backend%20Laravel%20+%20PostgreSQL.md)). It:

- receives the events the Godot client in [`reading-racoon/`](../reading-racoon/) queues offline, **replays them through server-side BKT** and serves the official state back ([D-008](../brain/decisions/D-008%20Offline%20sync%20contract.md), [D-011](../brain/decisions/D-011%20Server-side%20BKT%20replay.md));
- decides when a learner may play ([D-014](../brain/decisions/D-014%20Time-restricted%20access%20rules.md));
- hosts the **teacher dashboard** as server-rendered web pages ([D-012](../brain/decisions/D-012%20Teacher%20web%20dashboard.md));
- hosts a **hidden admin portal** that has no public entrance ([D-013](../brain/decisions/D-013%20Hidden%20admin%20portal.md)).

Spec: [`docs/knowledge/03-architecture.md`](../docs/knowledge/03-architecture.md) (API, offline sync), [`04-data-model.md`](../docs/knowledge/04-data-model.md), [`05-bkt-engine.md`](../docs/knowledge/05-bkt-engine.md), [`06-game-design.md`](../docs/knowledge/06-game-design.md).

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
   The seeder creates an approved demo teacher `teacher@demo.test` who owns the section "Grade 1 - Demo" with students Ana and Ben, and **prints the teacher's random password and the students' login codes once** (only hashes are stored). It never creates an admin.
5. **Run it:** `php artisan serve` (http://127.0.0.1:8000). Teachers sign in at `/login`. An Android phone on the same Wi-Fi needs `php artisan serve --host=0.0.0.0` and the PC's LAN address.

## Hidden admin portal: set up

The admin portal is **not public** ([D-013](../brain/decisions/D-013%20Hidden%20admin%20portal.md)). It exists only under a secret URL prefix, refuses everything else with the site's ordinary 404, and needs a password **and** a 6-digit authenticator code.

1. **Choose a secret path.** Generate a random value of at least 32 characters and put it in `.env` (never in code, docs, chats, issues or git):
   ```bash
   php -r "echo bin2hex(random_bytes(24)), PHP_EOL;"
   ```
   ```env
   ADMIN_PATH=<paste the value here>
   ```
   While `ADMIN_PATH` is empty or shorter than 32 characters, the portal doesn't exist at all. After changing it, run `php artisan config:clear` (and `php artisan route:clear` if routes were cached). The sign-in page is then `https://<host>/<ADMIN_PATH>`. Bookmark it on the admin's own computer only.
2. **Optional: limit it to known IPs.** `ADMIN_ALLOWED_IPS=203.0.113.7,10.0.0.0/24` (IPs or CIDR ranges). Requests from anywhere else get a 404 before anything else runs, and the attempt is logged as an anomaly. Behind a reverse proxy, configure Laravel's trusted proxies first so the real client IP is seen.
3. **Create an admin** (there is no admin registration page):
   ```bash
   php artisan admin:create admin@school.example --name="IT Office"
   ```
   It asks for a password twice (at least 12 characters with letters and numbers; not shown on screen).
4. **Enrol two-factor sign-in.** `admin:create` prints a setup key and an `otpauth://` link **once**, in the terminal only. In an authenticator app (Google Authenticator, Microsoft Authenticator, Aegis, 2FAS, ...) choose *Add account > Enter a setup key*, type the key, choose *time-based*. Add `--qr` to also draw a QR code in the terminal to scan instead. Don't screenshot or store the key anywhere else.
5. **Sign in** at `/<ADMIN_PATH>` with email, password and the current 6-digit code.

Lost phone? `php artisan admin:reset-2fa admin@school.example` prints a new key; the old authenticator entry stops working. Every admin creation and reset is in the audit log.

How the portal stays hidden:
- Its routes are registered only under `ADMIN_PATH`. A guessed URL, a refused request (not signed in, no 2FA, wrong IP, expired session, wrong HTTP method, too many attempts) and a missing page all return **the same 404 page, without a session cookie**. Never a 403, never a redirect to a sign-in page.
- Five failed sign-ins per IP or per email lock the form into a 404 for 15 minutes. A used code can't be replayed. Idle sessions end after `ADMIN_IDLE_MINUTES` (30).
- Admin pages send `X-Robots-Tag: noindex`, `Referrer-Policy: no-referrer` and `Cache-Control: no-store`, load nothing from other hosts, and nothing links to them. `robots.txt` doesn't mention them (that would reveal the path).
- Teachers and admins use separate session guards: a teacher account can't open the portal and an admin account can't use the teacher sign-in.
- **On the server set `APP_DEBUG=false`**: debug pages would show internals.

## Gemini teacher report: set up (FR-05, FR-21)

The report's two summary paragraphs are written by Gemini; the lists and the table under them come from the numbers ([D-015](../brain/decisions/D-015%20Gemini%20teacher%20report.md)). It stays off, and every report uses the template, until all three `LLM_*` values are set.

1. **API key** from Google AI Studio, created under the **billing-enabled** Google Cloud project that holds the AI Pro credits (paid terms only: free-tier prompts may be used by Google, [D-002](../brain/decisions/D-002%20AI%20model%20Gemini.md)). Set a budget alert on the billing account.
2. **`.env`** (never commit it):
   ```env
   LLM_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai/
   LLM_API_KEY=<your key>
   LLM_MODEL=<exact Flash or Flash-Lite model id from Google's model list, not a "latest" alias>
   # Optional:
   LLM_REASONING_EFFORT=     # e.g. none or low to limit "thinking"; allowed values depend on the model
   LLM_REPORT_MAX_TOKENS=600
   LLM_REPORT_DELAY_MINUTES=10
   ```
   Then `php artisan config:clear` and `php artisan migrate`.
3. **Run a queue worker** (reports are written in the background): `php artisan queue:work` on the server, or `composer dev` locally, which already runs one.
4. **Check it** without playing: record parental consent for a learner who has played, then
   ```bash
   php artisan report:write RR-XXXXXX
   ```
   It prints the paragraphs, or why the replies were refused. Add `--force` to write again for the same numbers.

How it behaves:
- A sync that stores new events queues a report for **10 minutes later**; syncs in between don't queue another, so one play session gives one report. Opening a report that has no AI version for the current numbers also queues one.
- **Only learners with parental consent on file** are sent, as student code and numbers (no names, ages or dates). Others always get the template.
- Every reply is checked against the numbers before it's shown: two plain paragraphs of 40–180 words, no other learner's code, every number found in the facts, every sub-skill that needs support named. Up to 3 calls (timeouts, 429 and 5xx are retried; a bad key isn't), then the template, and an `ai.report_fallback` warning in the system log.
- Every call is in `ai_logs` (the injected JSON, the reply, status, reason, latency, tokens) and in the admin portal under **Logs > AI calls**. Removing a learner deletes their AI rows.
- The report footer says whether the paragraphs come from the template or from the AI model. While a new version is being written, the template shows.

## Test

```bash
php artisan test
```

Tests run on the `reading_racoon_test` PostgreSQL database (`phpunit.xml`), never SQLite. Admin tests boot the app with a random `ADMIN_PATH` that exists only for that test. Gemini is always faked (`Http::fake`); `phpunit.xml` forces `LLM_API_KEY` empty so a real key in `.env` is never used. **All 139 pass on PostgreSQL 18.6.**

`php artisan db:show` needs PHP's `intl` extension for its size column (`extension=intl` in `php.ini`); the app itself doesn't.

## Teacher web pages (FR-06, FR-08, FR-12, FR-16 to FR-18)

| Page | What |
|---|---|
| `/register` | Teacher self-registration (name, email, school, first section, password). Pending until an admin approves it. |
| `/login` | Email + password. Only approved teachers get in; 5 misses per email lock it for a minute. A teacher revoked by an admin is signed out on their next click. |
| `/teacher/sections/{id}` | Class dashboard: mastery per sub-skill, ARAL band counts (from each learner's highest unlocked map level), colour-coded open intervention flags (red: rescue limit, orange: failed Heart Recovery, amber: P(L) < 0.30 after 5+ answers), the roster with add/remove, new login code, parental consent. |
| `/teacher/students/{id}` | BKT chart over time (one line per sub-skill and level), the 14 skill-levels, lessons and Racoon's Rescue history, flags, play time. |
| `/teacher/sections/{id}/schedule` | Class window, after-school window, daily after-school minutes, weekends on/off. |
| `/teacher/students/{id}/report` (+ `.pdf`) | Diagnostic summary with PDF export (dompdf): two paragraphs written by Gemini once a checked version exists for the current numbers, otherwise by the template; the lists and table always come from the numbers ([D-015](../brain/decisions/D-015%20Gemini%20teacher%20report.md)). |

Teachers only ever see their own sections: another teacher's section, learner or flag answers 404. Charts use Chart.js 4.4.1 from jsDelivr; without internet the tables under the charts still show every number. Every teacher action is written to the audit log.

## Admin portal pages (FR-08, FR-22)

| Page | What |
|---|---|
| Overview | Waiting registrations, anomalies, failed sign-ins and server errors in the last 24 h. |
| Registrations | Approve, deny or revoke teachers, with an optional note. |
| Logs | System log (sign-ins, access decisions, sync problems, device lock screens, clock jumps, AI fallbacks, server errors), audit log (every admin and teacher action) and AI calls (every Gemini call with its input JSON, reply, status and latency, FR-21), filtered by event, level or status, date and text. Anomalies, sensitive actions and failed AI calls are highlighted. |
| Privacy audit | RA 10173 checks: consent coverage, 2FA on every admin, portal path, IP allowlist, debug mode, HTTPS, append-only audit log, inactive learners, unused tokens, third-party AI; the personal data stored; who opened learner data in the last 30 days. |
| Research export | `students.csv` (levels, accuracy, pre/post-test scores per sub-skill, final P(L) of the 14 skill-levels) and `bkt-history.csv` (every replayed answer). **Consented learners only, student codes only, never names.** |

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
Wrong or malformed code: `422` with `errors.login_code`. Send the token as `Authorization: Bearer <token>`. Tokens don't expire yet. A teacher's "New code" deletes the learner's tokens.

### `GET /api/config` (FR-19)

Public. The client caches it and re-downloads content when `content_version` is newer than its own.

```json
{
  "content_version": 1,
  "post_test_open": false,
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
Values live in [`config/reading_racoon.php`](config/reading_racoon.php) (`CONTENT_VERSION` and `POST_TEST_OPEN` in `.env`). They mirror `reading-racoon/scripts/core/skill_catalog.gd` and `student_model.gd`. `post_test_open` tells the game to offer the post-test (FR-10); turn it on at the end of the evaluation period.

### `POST /api/sync` (FR-11)

Student token only. Send the lines of `user://event_queue.jsonl` in queue order, at most `max_batch` per request:

```json
{"events": [
  {"id": "6f1c3d5e-6a2b-4c8d-9e0f-112233445566", "type": "response",
   "payload": {"item_id": "pa1-01", "skill": "phonological_awareness", "level": 1, "answer": "hat",
               "correct": true, "response_ms": 2350, "rescue": false, "num_choices": 3},
   "device_time": "2026-10-20T04:34:56Z"}
]}
```
- `id`: the client's UUID, the idempotency key. `type`: one of the types below. `payload`: a JSON object, stored as-is (max 8 KB). `device_time`: ISO 8601 with `Z` or an offset.

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
- Then read `GET /api/student/me`: after every sync the server replays the student's events and **its state wins**.

#### Event types and what the server replays ([D-011](../brain/decisions/D-011%20Server-side%20BKT%20replay.md))

The server replays all of a student's stored events, oldest first, through the client's own rules (`student_model.gd`, `lesson_session.gd`, `assessment_session.gd`, `wardrobe.gd`) and stores the result in `bkt_states`, `path_progress`, `student_wallets`, `intervention_flags`, `student_items` and `daily_usage`. An event whose fields don't make sense is kept but skipped. An unknown **type** is rejected, so update the server before shipping a client with a new type.

| `type` | Payload the server reads | What the server does |
|---|---|---|
| `response` | `skill, level, correct, rescue, num_choices` | One BKT observation for (skill, level), guess = 1/`num_choices` for choice items (else the Table 3.5 guess); mastery at P(L) ≥ 0.95 with ≥ 5 attempts; Level Up when every skill at the highest unlocked level is mastered. A low-mastery flag when P(L) < 0.30 after ≥ 5 answers, once per skill-level until mastered. |
| `response` + `assessment: "pre"/"post"` | `skill, correct` | A test item: scored, never a BKT observation. |
| `placement` | `start_level` | Recomputes `StudentModel.place()` from the pre-test answers: each sub-skill's lowest level from P(L0), Table 3.5 guess, mastered if the final posterior ≥ 0.95, start on the lowest level with an unmastered skill. `start_level` is used only when the server has no pre-test answers. |
| `assessment` | `kind, scores {skill: {correct, total}}` | Raw pre/post-test scores for the research export (the first report per kind). |
| `rescue_start`, `rescue_end` | `skill, level` | Counts the `rescue: true` answers in between; fewer than 3 correct demotes (skill, level − 1): P(L) ≤ 0.70, attempts 0, review. |
| `flag` | `type, skill, level` (+ details) | A teacher intervention flag whose id is the event UUID. `type: "clock_jump"` (`from, to`) goes to the admin log as an anomaly instead. |
| `lesson_end` | `level, node, correct, total, ended_early` | Stars from accuracy, XP = 10 × correct, coins = 5 × stars (+20 after a Level Up), path progress. |
| `chest` | `level` | +15 coins, once per world. |
| `purchase` | `item, price` | Spends the catalogue price (a copy of `wardrobe.gd` in `config/reading_racoon.php`; the client's price only for unknown items). Ignored if already owned or not enough coins. |
| `outfit` | `equipped {slot: item}` | What the raccoon wears: owned items in their own slot. Everyone starts owning and wearing `scarf_teal`. |
| `usage` | `date, minutes` | After-school minutes played that local day so far; the largest value per date wins. |
| `access` | `status, time` | A lock screen the device showed; logged once in the admin system log. |
| `bkt_state`, `level_up`, `hearts` | | Stored only: the server computes these itself. |

The server also logs to the admin portal: rejected events, `id_conflict`s, device clocks more than 5 minutes ahead (anomalies).

### `GET /api/student/me` (FR-03, FR-07)

Student token only. The official state after the server's replay. `model` has exactly the shape of `StudentModel.to_dict()`, so the game adopts it with `model.from_dict(body.model)`.

```json
{
  "student": {"id": 1, "code": "RR-7K2M9Q", "name": "Ana", "section": {"id": 1, "name": "Grade 1 - Demo"}},
  "model": {"states": {"phonics:1": {"p": 0.97, "attempts": 5, "mastered": true, "review": false}, "...": {}}, "highest_unlocked": 2},
  "aral_band": "ARAL Basic / Plus",
  "wallet": {"xp": 120, "coins": 35},
  "path": {"worlds": {"1": {"done": 2, "chest": true, "bonus": []}}},
  "items": [{"item_id": "scarf_teal", "slot": "neck", "equipped": true}],
  "equipped": {"neck": "scarf_teal"},
  "bkt_version": 1,
  "server_time": "2026-10-20T04:35:00Z"
}
```

### `GET /api/access/student/status` (FR-12)

Student token only. The section's schedule and today's decision, in the school's time zone (`SCHOOL_TIMEZONE`, default `Asia/Manila`). Call it at sign-in and at screen transitions, show the raccoon lock screen when play isn't allowed, and cache `schedule` + `server_time` for offline play (open issue 10). Every decision is written to the system log.

```json
{
  "status": "after_school",
  "minutes_left": 18,
  "server_time": "2026-10-20T07:12:00Z",
  "window": "after_school",
  "opens_at": null,
  "used_minutes": 12,
  "schedule": {"class_start": "07:30", "class_end": "08:30", "after_school_start": "15:00", "after_school_end": "17:00",
               "daily_minutes": 30, "weekends_open": false, "timezone": "Asia/Manila"}
}
```

| `status` | When | `minutes_left` |
|---|---|---|
| `allowed` | Weekday class window: everything, including the pre/post-test | until class ends |
| `after_school` | Weekday after-school window, or a weekend the teacher opened | min(daily minutes left, time to window end or midnight) |
| `class_lock` | Any other weekday time ("Come back during Reading time") | 0 |
| `daily_limit` | The daily after-school minutes are used up ("Great work today!") | 0 |
| `weekend_lock` | Saturday/Sunday while weekends are closed ("Game is sleeping") | 0 |

`window` is `class`, `after_school`, `weekend` or `null`; `opens_at` is when play opens next (UTC), or `null` while open. `used_minutes` comes from the synced `usage` events. Sections without their own schedule use the defaults above. Holidays aren't modelled yet.

## Database

| Table | Holds | Keys |
|---|---|---|
| `users` | All roles (`role`), email + password for staff, `login_code_hash` for students, admin TOTP secret (encrypted) | bigint |
| `teacher_registrations` | `pending` / `approved` / `denied`, reviewer, note | `user_id` unique |
| `sections` | Class sections, owned by a teacher (`teacher_id`) | bigint |
| `students` | Learners: `code` (pseudonym like `RR-7K2M9Q` for exports and AI prompts), parental consent record | bigint |
| `bkt_states` | 14 per student: `(sub_skill, level)`, `p_mastery`, `attempts`, `mastered_at`, `review` | unique per student |
| `path_progress` | `highest_unlocked` map level and the path's `worlds` (jsonb) | `student_id` |
| `student_wallets` | `xp`, `coins` | `student_id` |
| `student_items` | Owned shop items, slot, equipped | `(student_id, item_id)` |
| `intervention_flags` | Teacher alerts with `open`/`resolved` status | uuid (raised offline or derived) |
| `access_schedules` | Per section: class and after-school windows, daily minutes, weekends | `section_id` |
| `daily_usage` | After-school minutes per student per local date | `(student_id, date)` |
| `sync_events` | Raw client events: `uuid` (unique), `type`, `payload` jsonb, `device_time`, `received_at` | bigint `id` = arrival order |
| `audit_logs` | Every admin and teacher action. **Append-only**: a trigger refuses UPDATE and DELETE | bigint |
| `system_logs` | Sign-ins, access decisions, sync problems, server errors, with an `anomaly` flag | bigint |
| `ai_logs` | Every LLM call: task, prompt version, model, input JSON, reply, `status` (`ok`/`invalid`/`blocked`/`error`), reason, latency, tokens | bigint |
| `ai_reports` | Gemini's report paragraphs per set of numbers (`facts_hash`); `paragraphs` null = the AI failed and the template is used | unique `(student_id, facts_hash)` |

All times are `timestamptz`; the connection runs in UTC. `App\Actions\EnrollStudent` creates a student with their login code, student code, 14 BKT states at P(L0), wallet, starter outfit and path. Removing a learner deletes all their rows.

## Layout

| Path | What |
|---|---|
| `app/Http/Controllers/Api/` | `LoginController`, `ConfigController`, `SyncController`, `StudentMeController`, `AccessStatusController` |
| `app/Http/Controllers/Teacher/` | Teacher sign-in, registration, sections, roster, students, schedule, reports |
| `app/Http/Controllers/Admin/` | Admin sign-in, overview, registrations, logs, privacy audit, export |
| `app/Http/Middleware/` | `EnsureUserHasRole`, `EnsureApprovedTeacher`, `ConcealAdminPortal`, `AuthenticateAdmin` |
| `app/Actions/` | `EnrollStudent`, `RecordSyncEvents`, `ReplayStudentEvents` |
| `app/Support/` | `StudentReplay` (the BKT replay), `Bkt`, `SkillCatalog`, `AccessDecider`, `SectionStats`, `LoginCode`, `StudentCode`, `AdminPortal`, `AdminTotp`, `LlmClient` |
| `app/Reports/` | `StudentFacts`, `DiagnosticReportWriter` (the LLM seam), `TemplateReportWriter`, `StoredReportWriter` (pages), `GeminiReportWriter`, `ReportPrompt`, `AiReportCheck` |
| `app/Jobs/` | `WriteAiReport` (the queued Gemini report) |
| `app/Policies/` | Teachers see only their own sections, learners and flags |
| `app/Console/Commands/` | `admin:create`, `admin:reset-2fa`, `report:write` |
| `config/reading_racoon.php` | BKT parameters, rewards, shop catalogue, levels and ARAL bands, access defaults |
| `config/admin.php` | Admin portal settings (path, IP allowlist, idle time, sign-in limits) |
| `routes/web.php`, `routes/admin.php`, `routes/api.php` | Teacher pages, hidden admin portal, game API |
| `database/migrations/` | Schema (PostgreSQL only) |
| `tests/` | PHPUnit feature and unit tests |
