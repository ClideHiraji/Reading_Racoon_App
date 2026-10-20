---
type: decision
status: decided
date: 2026-10-17
issue: 4
graphify: submitted
tags: [decision, bkt, game-logic]
---

# D-003 BKT level progression

**Decision**
- BKT tracks each **(sub-skill, level)** pair, giving **14 states per child**: PA L1–2, Phonics L1–3, Vocabulary L2–4, Fluency L3–5, Literal Comprehension L3–5.
- A skill-level is **mastered** when P(L) ≥ **0.95** *and* the child has made **≥ 5 attempts** there.
- **Level Up:** when every skill active at a map level is mastered, the next map level unlocks.
- **Hint:** only after a **wrong** answer, when P(L) is below **0.30**.
- Guess rate for multiple-choice items ≈ 1 ÷ number of choices.
- The ARAL band shown to teachers comes from the map level, not from raw P(L).

**Why:** with the thesis parameters, 3 correct answers in a row already pass 0.95 for every skill ([[BKT passes 0.95 after 3 correct]]). P(L) moves too fast to use directly as a level score, which is what the thesis's Table 3.6 tried to do.

Details: [[05-bkt-engine]], [[10-open-issues]] issue 4. Related: [[D-004 Heart Recovery rules]].
