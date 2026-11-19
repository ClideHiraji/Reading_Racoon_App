---
type: decision
status: decided
date: 2026-10-20
issue: 8
graphify: submitted
tags: [decision, backend, bkt, sync]
---

# D-011 Server-side BKT replay

**Decision:** after every `POST /api/sync`, the server replays **all** of a student's stored events, in arrival order, through the same rules as the client and stores the result as the official state. The client adopts it from `GET /api/student/me` (server wins, [[D-008 Offline sync contract]]).

| Event | What the server does |
|---|---|
| `response` | BKT for (skill, level) as `StudentModel.record()`: guess = 1/`num_choices` for choice items, mastery at P(L) ≥ 0.95 with ≥ 5 attempts, Level Up when every skill at the highest unlocked level is mastered ([[D-003 BKT level progression]]). |
| `response` with `assessment: pre/post` | Scored only. Never a BKT observation. |
| `placement` | Recomputes `StudentModel.place()` from the pre-test answers (Table 3.5 guess, final posterior, lowest level with an unmastered skill). `start_level` is only a fallback. |
| `assessment` | Raw pre/post-test scores per sub-skill, kept for the research export (RQ1). |
| `rescue_start/_end` | Counts the rescue answers; < 3 correct demotes the level below ([[D-004 Heart Recovery rules]]). |
| `flag` | Teacher intervention flag (id = event UUID). `clock_jump` goes to the admin log instead. |
| `lesson_end`, `chest` | XP, coins, stars and path recomputed from the rules, not trusted from the payload. |
| `purchase`, `outfit` | Coins spent at the server's copy of the `wardrobe.gd` price; only owned items can be worn; everyone starts with `scarf_teal`. |
| `usage` | Running daily total of after-school minutes; the largest value per date wins. |
| `access` | Logged once in the admin system log. |
| `bkt_state`, `level_up`, `hearts` | Stored, ignored: the server computes them. |

Also: a server-raised `low_mastery` flag when P(L) < 0.30 after ≥ 5 answers at a level, **once per skill-level until it is mastered** (its id is a UUIDv5 of the triggering answer, so a replay never duplicates it). A flag a teacher resolved stays resolved.

**Why**
- 03-architecture.md makes the server the BKT authority. Replaying everything (not incrementally) is simple, deterministic and lets new BKT parameters (EM recalibration) apply to old answers. A whole study is ~1,500 events per student: milliseconds.
- Recomputing coins, stars and prices means a tampered or buggy client can't award itself rewards.
- Test items must not move BKT, or the post-test would contaminate the learning measure.

**Consequences**
- The game must send `num_choices` in gameplay `response` payloads, or the server's P(L) drifts from the device's for choice items (asked of the game session on 2026-10-20).
- The shop catalogue lives twice (game + `config/reading_racoon.php`); change both together.
- An unknown event type is still rejected, so new types need a server release first.

**Rejected:** trusting client `bkt_state` events; incremental replay with a cursor (more state to keep right for little gain); turning `clock_jump` into a teacher flag (it's a device problem, not a reading one).

Details: `backend/README.md` ("Event types and what the server replays"), [[10-open-issues]] issues 8 and 10.
