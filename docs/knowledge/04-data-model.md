# 04 — Data Model

> **Built so far (2026-10-20):** `users` (role, admin TOTP), `teacher_registrations`, `sections` (owned by a teacher), `students` (pseudonymous `code`, consent record), `bkt_states`, `path_progress`, `student_wallets`, `student_items`, `intervention_flags`, `access_schedules`, `daily_usage`, `sync_events`, `audit_logs` (append-only) and `system_logs`, in `backend/database/migrations/`. Projections are rebuilt by replaying `sync_events` ([D-010](../../brain/decisions/D-010%20Server-side%20BKT%20replay.md)). Summary table in `backend/README.md`; sync rules in [D-008](../../brain/decisions/D-008%20Offline%20sync%20contract.md). Everything else below is still to design (open issue 8).

Target: **PostgreSQL 16+ via Laravel migrations** (backend decision, open issue 1). Use `uuid` keys for anything created offline on the device (sessions, responses, sync events), `jsonb` for payloads and AI logs, and `timestamptz` for all times. The thesis ERD text says "Firebase Realtime Database… hierarchical JSON". Rewrite it as relational tables.

## ERD as drawn in the thesis (Figure 3.16)

| Entity | Fields (type) | Keys / relations |
|---|---|---|
| `users` | user_id (str), role (str: student/teacher/admin), username (str), hashed_pin (str) | PK user_id. Auth root; `role` gates all access. |
| `students` | student_id, student_age (int), student_gender (char), session_id, section_id, user_id | PK student_id; FK section_id → sections, user_id → users, session_id → sessions (*see issue*) |
| `teachers` | teacher_id, section_id, user_id | FK section_id → sections, user_id → users |
| `admin` | admin_id, user_id | FK user_id → users |
| `sections` | section_id, section_name | |
| `sessions` | session_id, student_id, difficulty_level (int), start_time, end_time | FK student_id → students |
| `responses` | response_id, session_id, question_id, is_correct (bool), response_ms (int) | FK session_id, question_id |
| `questions` | question_id, sub_skill, difficulty_level (int), correct_answer | |
| `bkt_states` | bkt_id, student_id, sub_skill, mastery_prob (float), updated_at | One row per student per sub-skill, updated after every response |
| `ai_reports` | report_id, ai_summary, generated_at, student_id, session_id | Built from sessions + responses |

The text calls these "eight principal entities", but the diagram shows 10 tables.

## Problems in the ERD
1. `students.session_id` FK is backwards. A student has many sessions, and `sessions.student_id` already models that. Drop it.
2. `users` has `username` + `hashed_pin`, but the teacher flow says "email & password". Decide credentials per role.
3. `questions` has no prompt, choices/distractors, media (image/audio), passage link, language, task type, or MATATAG competency code.

## Missing entities (required by features described in the thesis)
| Entity | Why |
|---|---|
| `passages` / `content` | Stories for Levels 3–5, language, word count, readability, competency codes |
| `question_choices` | MCQ options and distractors, drag tiles |
| `competencies` | MATATAG codes (e.g., `RL1CAT-I-2a`) linked to sub-skills and questions |
| `bkt_parameters` | Per sub-skill P(L0), P(T), P(G), P(S) with version history (EM recalibration, served via `/api/config`) |
| `sync_events` | Client UUID (unique), student, type, payload, device time, received time (idempotent offline sync) |
| `bkt_states` redesign | One row per **(student, sub_skill, level)** (14 per student): `p_mastery`, `attempts`, `mastered_at`, `updated_at`. See [05-bkt-engine.md](05-bkt-engine.md) |
| `student_progress` | Highest unlocked map level, current hearts/streak, recoveries this session |
| `assessments` + `assessment_results` | Pre-test / post-test (20 items), per-sub-skill scores, date |
| `student_wallet` / `xp_ledger` | Points, XP, coins earned and spent |
| `shop_items` + `student_items` | Hats, glasses, shirts, badges; owned and equipped |
| `access_schedules` | Per-section class window, after-school window, 30-min cap, weekend toggle |
| `daily_usage` | Minutes played per student per day (after-school cap) |
| `hearts` / session fields | Hearts remaining, recovery attempts and outcome |
| `intervention_flags` | Low P(L), failed heart recovery, status (open/resolved) |
| `teacher_registrations` | Status: pending/approved/denied, reviewed_by, reviewed_at |
| `system_logs` / `audit_logs` | Actor, action, timestamp, IP/device, anomaly flag |
| `ai_logs` | Prompt type, input JSON, output, model, latency, timestamp |
| `consents` | Parental consent record per student (RA 10173) |
