---
type: decision
status: decided
date: 2026-10-20
issue: 10
graphify: submitted
tags: [decision, backend, access, fr-12]
---

# D-013 Time-restricted access rules

**Decision:** `GET /api/access/student/status` decides, in the school's time zone (`SCHOOL_TIMEZONE`, default `Asia/Manila`), with one schedule per section (teacher-editable; defaults 07:30–08:30 class, 15:00–17:00 after school, 30 minutes, weekends closed):

| Status | When | Minutes left |
|---|---|---|
| `allowed` | Weekday class window: everything, including pre/post-test | until class ends |
| `after_school` | Weekday after-school window, or a weekend the teacher opened | min(daily minutes left, time to window end or midnight) |
| `class_lock` | Any other weekday time | 0 |
| `daily_limit` | The daily after-school minutes are used | 0 |
| `weekend_lock` | Saturday/Sunday while closed | 0 |

The reply also has `window`, `opens_at` (next opening, UTC), `used_minutes` and the `schedule` with its time zone, so the game can enforce it offline. Minutes come from the synced `usage` events (running daily total; class time isn't counted). Every decision is written to the system log, and so is every lock screen the device showed offline (`access` events). A device clock that jumped backwards (`flag` clock_jump) or runs > 5 minutes ahead is an admin anomaly.

**Why**
- §3.4.2.3 / [[06-game-design]]: class session = full access, other subjects locked, ≤ 30 min after school, weekends off by default with a toggle.
- `opens_at` lets the lock screen say when to come back instead of just "no".
- Logging both server decisions and device lock screens covers online and offline play (open issue 10).

**Consequences**
- DepEd holidays aren't modelled yet (a holiday list for the admin is a follow-up).
- `post_test_open` is global (`POST_TEST_OPEN` in `.env`) for now; a per-section switch would need the teacher page and an authenticated config.

**Rejected:** counting class minutes toward the cap (the cap is for after-school play); per-student schedules (sections share a timetable).

Details: `backend/README.md` ("GET /api/access/student/status"), [[10-open-issues]] issue 10.
