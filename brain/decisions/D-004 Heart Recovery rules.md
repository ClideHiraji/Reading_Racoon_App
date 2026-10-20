---
type: decision
status: decided
date: 2026-10-17
issue: 5
graphify: submitted
tags: [decision, game-logic, hearts]
---

# D-004 Heart Recovery rules

**Decision**
- 3 hearts. A heart is lost per **consecutive** wrong answer within one sub-skill. Any correct answer refills them.
- 3 wrong in a row → **Heart Recovery**: 3 items of the same sub-skill one level down (or easier same-level items when there's no lower level). These answers update BKT.
- **3/3 right** → back to the level with full hearts.
- **Fewer than 3** → the lower skill-level is un-mastered (P(L) set to at most 0.70, attempts reset). The current level stays unlocked, the map shows a review badge, and the teacher gets a flag.
- At most **2 recoveries per session**. On a third trigger, the raccoon ends the session kindly and flags the teacher.

**Why:** teachers said some children cry when they keep failing phonics. Recovery has to feel like help, not punishment, while still giving honest assessment data.

Details: [[06-game-design]], [[10-open-issues]] issue 5. Related: [[D-003 BKT level progression]].
