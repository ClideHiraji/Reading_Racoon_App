# 03 — Architecture

> **Backend decision (2026-10-17):** custom-coded **Laravel + PostgreSQL + Sanctum**, no Firebase (required by the adviser). **LLM: Google Gemini API.** See [10-open-issues.md](10-open-issues.md) issues 1–2. Wherever the thesis says "Firebase" or "MySQL", read it as the Laravel API + PostgreSQL.

## Roles and workflows (Figure 3.2)

**Student**
1. Log in → (first time) Pre-Test → Reading Adventure map.
2. Plays reading tasks. BKT watches each answer and adjusts difficulty.
3. Game over → score, points and results are stored. The AI evaluates performance and writes a statement/analysis that is stored to the DB.
4. Earns points → spends them in the **Shop** → customizes the **raccoon character**.

**Teacher** (the thesis calls the teacher app the "Authoring Tool")
1. Registers → waits for **admin approval** → logs in.
2. Registers/removes students (roster).
3. Dashboard: class-wide BKT metrics, mastery bands, ARAL tier counts, intervention flags.
4. Opens a student profile → BKT chart, session history, AI report → plans intervention → exports PDF.

**Admin** (separate portal)
1. Logs in with restricted credentials.
2. Approves/denies teacher registration requests.
3. Retrieves system logs and checks for anomalies (unknown entries, violations, server crashes, bugs).
4. Runs a data-privacy (RA 10173) audit. Flags issues and logs every action with a timestamp.

Advisor note on the architecture figure: *"group those components that are the same, like the AI component, the frontend (authoring tool)"*. The diagram needs a redraw.

## Component overview

```
┌────────── Godot 4 app (GDScript, Android APK) ──────┐
│ Student game │ Teacher dashboard │ Admin portal*     │
│ BKT engine (client) · offline cache · sync queue    │
└───────────────┬─────────────────────────────────────┘
                │ HTTPS + JSON, Bearer token (Sanctum)
┌───────────────▼─────────────────────────────────────┐
│ Laravel API (PHP 8.x)                                │
│ Auth/RBAC · roster · content · sessions · BKT        │
│ validation + EM job · access control · shop          │
│ reports · logs · config · LLM proxy                  │
└───────┬──────────────────────────────┬──────────────┘
        │ Eloquent                     │ HTTPS (server-side key)
┌───────▼────────┐             ┌───────▼──────────────┐
│ PostgreSQL     │             │ Google Gemini API    │
│ 16+            │             │ (Flash-class model)  │
└────────────────┘             └──────────────────────┘
```
\*The admin portal could also be a Laravel web page (Blade). Decide during build. It's cheaper than building admin screens in Godot.

## Technology stack

| Layer | Choice | Notes |
|---|---|---|
| Game engine / client | **Godot 4.7**, **GDScript** | Compatibility renderer (best for low-end Android). Android APK first. iOS export needs a Mac, so only if iOS devices exist. Project lives in `reading-racoon/` (portrait 720×1280). |
| Backend API | **Laravel (PHP 8.x)** | REST, MVC, Eloquent, migrations, queues/scheduler. |
| Database | **PostgreSQL 16+** | All persistent data, including logs. Laravel `pgsql` driver. Use `jsonb` for event payloads and AI input/output logs. |
| Auth / RBAC | **Laravel Sanctum** | Personal access tokens for all 3 roles. Role middleware + policies (a teacher sees only their own sections). |
| Client ↔ API | REST JSON via Godot `HTTPRequest` node + `JSON` | `Authorization: Bearer <token>`. |
| Adaptive algorithm | BKT in GDScript (client, real time) + PHP validation (server) | Server recomputes/validates on sync. EM recalibration as a scheduled job. |
| Remote config | `GET /api/config` | Replaces Firebase Remote Config: BKT params, thresholds, prompt versions, UI scaling. Cached on the device. |
| LLM | **Google Gemini API** (Flash-class model), paid with the team's Google AI Pro Cloud credits, called **only from Laravel** | API key in `.env`, never in the APK. See [08-ai-integration.md](08-ai-integration.md). |
| Offline cache | JSON files under `user://` via `FileAccess` | `ConfigFile` for small settings. Holds content, BKT states, queued events. |
| Art / audio | 2D animated raccoon (`AnimatedSprite2D` or Spine-like cut-out), Blender only if 3D is kept; Godot audio buses; WAV/OGG; built-in TTS via `DisplayServer.tts_speak` (check device support) | |
| VCS | Git / GitHub | |

## API surface (draft — names marked ★ appear in the thesis)

| Method | Path | Role | Purpose |
|---|---|---|---|
| POST | `/api/auth/login` | all | Issue Sanctum token (student login method: open issue 9) |
| POST | `/api/auth/logout` | all | Revoke token |
| POST | `/api/teachers/register` | public | Teacher registration request (pending) |
| GET | `/api/config` | all | Remote config (BKT params, thresholds, flags) |
| GET | ★`/api/access/student/status` | student | Access window check: allowed / class-lock / after-school remaining minutes / weekend-lock |
| GET | `/api/content?since=` | student | Content package (levels 1–5, passages, questions, audio URLs) for offline cache |
| GET | `/api/student/me` | student | Profile, BKT states, wallet, equipped items |
| POST | `/api/assessments/{pre\|post}` | student | Submit pre/post-test answers → initialize BKT |
| POST | `/api/sync` | student | **Batch upload** of queued events (sessions, responses, BKT updates, hearts, usage minutes) |
| POST | ★`/api/bkt/update` | student | Single BKT update when online (or fold into `/api/sync`) |
| GET/POST | `/api/shop/items`, `/api/shop/purchase`, `/api/shop/equip` | student | Reward economy |
| POST | `/api/companion/dialogue` | student | LLM raccoon line (with a local fallback library) |
| GET | `/api/teacher/sections/{id}/dashboard` | teacher | Class metrics, bands, flags |
| GET/POST/DELETE | `/api/teacher/students` | teacher | Roster management |
| GET | ★`/api/student/report` → `/api/teacher/students/{id}/report` | teacher | AI report + BKT history |
| GET | `/api/teacher/students/{id}/report.pdf` | teacher | PDF export |
| PUT | `/api/teacher/sections/{id}/schedule` | teacher/admin | Access windows, weekend toggle |
| GET/POST | `/api/admin/registrations` (+ `/approve`, `/deny`) | admin | Teacher approval queue |
| GET | `/api/admin/logs` | admin | System/audit logs with filters |
| GET | `/api/admin/export.csv` | admin | Research data export (pre/post, BKT history, events) |

## Offline and sync design

The thesis requires gameplay without internet, and the school connection is unstable. Without Firebase, we build this ourselves:

1. **Content cache:** at first online login, download the content package and store it with a version number. Re-download only when `/api/config` reports a newer content version.
2. **Event queue:** every gameplay event (response, BKT state after update, heart change, level change, usage minutes) is appended to a local queue file with a **client-generated UUID** and a device timestamp.
3. **Sync:** when online (at login, at screen transitions, every N minutes), POST the queue in batches to `/api/sync`. The server inserts **idempotently** (unique UUID), so retries never duplicate data. The client deletes the events the server acknowledges.
4. **BKT authority:** the client computes BKT in real time. The server replays the synced responses with the current parameters, stores the result as the official state, and returns it. The client adopts the server state at the next sync. One device per student keeps conflicts rare. If they diverge, the server wins.
5. **Access control offline:** cache the schedule plus the last server time offset. Enforce locally using the device clock, and flag sessions with a large clock jump for the admin logs.
6. **LLM offline:** companion lines come from the bundled fallback library. Teacher reports are generated server-side after sync.

## Security and privacy (RA 10173)
- Parental consent is recorded before any data collection. Students are identified by codes, not full names, in analysis exports.
- HTTPS only. Sanctum tokens are stored on the device. Passwords and PINs are hashed (bcrypt).
- Policies make sure teachers only read their own sections. Every admin and teacher action is written to `audit_logs`.
- LLM prompts contain **no names**, only student codes and scores.
- Store only the PII the study needs. The ERD stores age and gender; justify each field or drop it.

## Hosting (decide early)
Laravel + PostgreSQL needs a server with HTTPS that the school devices can reach. Options: university server (ask CCIS), a cheap VPS (install PHP + PostgreSQL), or a managed PostgreSQL service paired with a PHP host. Note that cheap shared PHP hosting often offers only MySQL, so check for PostgreSQL support before paying. For local development on Windows, use Laragon (which can add PostgreSQL) or the official PostgreSQL installer + pgAdmin, alongside PHP 8.x + Composer. Watch the 99% uptime target (NFR-03).
