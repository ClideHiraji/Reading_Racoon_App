---
type: decision
status: accepted
date: 2026-11-28
issue: 25
graphify: submitted
tags: [decision, sync, devices, backend, game]
---

# D-050 Save file copy on the server

**Decision:** A child's progress follows them to any laptop. The game uploads its whole save file for that child
(`PUT /api/student/profile`) at the end of each sync round when it changed, and at sign-in a laptop takes the
server's copy (from `GET /api/student/me`) when it's newer than the last copy that laptop sent or took and no
answers are waiting there. Switch student waits until the copy is on the server. The server also ignores any
pre-test placement after the first one.

**Why**
- With 4 shared laptops (D-046), a child signing in on a laptop they hadn't used got a blank save, took the
  pre-test again, and that second placement reset all 14 BKT states on the server: Day 1's lessons stopped counting
  on the dashboard, the AI report and the export (audit, 2026-11-28).
- A whole-file copy brings back everything the child has, including what the server doesn't add up (stickers,
  word book, story, Practice levels, buddy and language, track), with no second set of coin and Closet rules to keep
  in step.

**Consequences**
- New columns `students.profile` (jsonb) and `profile_saved_at`; the new endpoint skips TrimStrings and
  ConvertEmptyStringsToNull like `/api/sync`.
- A laptop with no save for the child that can't reach the server shows "Couldn't load your progress" instead of
  starting from zero.
- The copy is a convenience, not research data: teacher pages and exports still come from the events.
- The 4 laptops need a new Windows build; the server needs `php artisan migrate`.

**Rejected:** rebuilding every part of the save on the server from events (two copies of the reward rules that
would drift); a fixed laptop per child only (still a good habit for the pilot, but one slip lost data).

Details: [[10-open-issues]] issue 25, [[D-046 Four team laptops and 30 learners]], [[D-008 Offline sync contract]],
[[D-011 Server-side BKT replay]]
