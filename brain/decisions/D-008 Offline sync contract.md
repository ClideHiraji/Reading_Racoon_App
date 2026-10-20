---
type: decision
status: decided
date: 2026-10-20
issue: 8
graphify: submitted
tags: [decision, backend, sync]
---

# D-008 Offline sync contract

**Decision:** the game uploads its event queue to `POST /api/sync` in batches of up to 500, oldest first. The server:

| Rule | Detail |
|---|---|
| Stores raw events first | Table `sync_events`: client `uuid` (unique), `student_id`, `type`, `payload` (jsonb, stored exactly as sent), `device_time`, `received_at`. Its bigint `id` is the arrival order, which follows the client's queue order (device times only have 1-second resolution). |
| Idempotent by UUID | `INSERT … ON CONFLICT DO NOTHING`. A retried batch, or the same event twice in one batch, is stored once and acknowledged again. The first copy wins. |
| Checks each event on its own | One bad event never blocks the queue. The reply lists `acknowledged` ids and `rejected` ids with a reason (`invalid` + field errors, or `id_conflict` when the UUID belongs to another student). |
| Client side | Delete acknowledged **and** rejected events (keep a local copy of rejected ones); retry anything else. A `422` means the envelope is wrong, so drop nothing. |
| Projections come next | `bkt_states`, `intervention_flags`, `student_wallets` and `path_progress` exist but are filled in the next slice, by replaying `sync_events` through server-side BKT (the server is the BKT authority, [[03-architecture]]). |

Also decided while building the first schema (issue 8):
- Server-created rows (users, sections, students) use bigint keys. Rows raised offline use UUIDs: `sync_events.uuid`, and `intervention_flags.id` = the UUID of the `flag` event.
- All times are `timestamptz`, and the pgsql connection runs in UTC ([[Laravel timestamptz needs a UTC session]]).
- The ERD's `students.session_id` is dropped. Age and gender are left out until the study justifies them (RA 10173).

**Why**
- The school Wi-Fi drops often (FR-11). Requests will be retried, so duplicates must be impossible, not merely unlikely.
- If one malformed event failed the whole batch, the client would resend it forever and nothing behind it would ever sync.
- Keeping the raw log means the server can replay it again when BKT parameters change (EM recalibration).

**Consequences**
- The Godot sync slice must follow the client rules above.
- Server and client are released together: an event type the server doesn't know is rejected, so update the server before shipping a client with new event types.

**Rejected:** rejecting the whole batch on any bad event; a uuid primary key alone (loses arrival order); trusting client `bkt_state` events as the official BKT state.

Details: [[10-open-issues]] issue 8, `backend/README.md`. Related: [[D-001 Backend Laravel + PostgreSQL]], [[D-003 BKT level progression]].
