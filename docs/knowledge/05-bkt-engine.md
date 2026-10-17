# 05 — BKT Adaptive Engine

BKT models the mastery of each skill as a hidden binary state (a hidden Markov process). Each **sub-skill is tracked independently**, so every student has five BKT states.

## Parameters
| Symbol | Meaning |
|---|---|
| P(L₀) | Prior: probability the skill is already known before the first interaction |
| P(T) | Learn/transit: probability of moving from not-known to known after one practice opportunity |
| P(G) | Guess: correct answer without mastery |
| P(S) | Slip: wrong answer despite mastery |

## Update equations (per response)
Correct answer (obs = 1):

```
P(Lt | 1) = P(Lt)·(1 − S) / [ P(Lt)·(1 − S) + (1 − P(Lt))·G ]
```

Incorrect answer (obs = 0):

```
P(Lt | 0) = P(Lt)·S / [ P(Lt)·S + (1 − P(Lt))·(1 − G) ]
```

Learning transition (next opportunity):

```
P(Lt+1) = P(Lt | obs) + (1 − P(Lt | obs))·T
```

Constraint (prevents degenerate EM fits): **1 − P(S) > P(G)**. A proficient learner must be more likely to answer correctly than a guesser.

## Initial parameters (thesis Table 3.5)
| Sub-skill | P(L₀) | P(T) | P(G) | P(S) |
|---|---|---|---|---|
| Phonological Awareness | 0.20 | 0.15 | 0.20 | 0.10 |
| Phonics | 0.25 | 0.18 | 0.20 | 0.10 |
| Vocabulary | 0.30 | 0.20 | 0.25 | 0.12 |
| Reading Fluency | 0.15 | 0.12 | 0.15 | 0.08 |
| Literal Comprehension | 0.20 | 0.15 | 0.20 | 0.10 |

These are literature defaults until the Pre-Test sets each student's baseline. The Reviewing phase notes that **Fluency's parameters proved too conservative for Advanced learners**, so expect to recalibrate them.

## Thresholds
| Threshold | Value | Effect |
|---|---|---|
| Mastery | P(L \| obs) **≥ 0.95** *and* **≥ 5 attempts** on that skill-level | That skill-level is **mastered** (see the progression model below) |
| Hint | incorrect answer *and* P(L) **< 0.30** after it | **Hint Trigger**: raccoon gives scaffolded dialogue |

## Level progression model (decided 2026-10-17, open issue 4)

### What the simulation showed
Using the thesis parameters (Table 3.5), starting from P(L₀):

| Sub-skill | Posterior after 1 / 2 / 3 correct in a row | After 1 wrong at the start | 0.95 then 1 wrong |
|---|---|---|---|
| Phonological Awareness | 0.53 / 0.87 / **0.97** | 0.03 | 0.70 |
| Phonics | 0.60 / 0.90 / **0.98** | 0.04 | 0.70 |
| Vocabulary | 0.60 / 0.88 / **0.97** | 0.06 | 0.75 |
| Reading Fluency | 0.52 / 0.89 / **0.98** | 0.02 | 0.64 |
| Literal Comprehension | 0.53 / 0.87 / **0.97** | 0.03 | 0.70 |

So **3 correct answers in a row pass 0.95**, and with 3–4 answer choices a lucky guessing streak can do that. P(L) moves far too fast to work as a "which level am I" score. That's why the thesis's direct P(L) → level table (old Table 3.6) can't work, and why a minimum attempt count is needed. This also matches the thesis's own Adjustment Log example: "BKT advances student too quickly after 2 correct answers".

### The model
1. **Knowledge component = (sub-skill, level).** Each student has one BKT state per sub-skill **per level in that sub-skill's range** (Table 3.7): PA L1–2, Phonics L1–3, Vocabulary L2–4, Fluency L3–5, Literal Comprehension L3–5, for **14 states per student**. Each new state starts at that sub-skill's P(L₀). Store it as `bkt_states(student_id, sub_skill, level, p_mastery, attempts, mastered_at, updated_at)`.
2. **Adventure levels 1–5 are global.** Map level *n* contains tasks for every sub-skill whose range includes *n*. In level *n*, each question updates the state for (that sub-skill, *n*).
3. **Skill-level mastery:** posterior ≥ 0.95 **and** attempts ≥ 5 (configurable in `/api/config`). After that, level *n* stops serving that sub-skill, except for an occasional review item.
4. **Level Up:** when **every** sub-skill active at level *n* is mastered at *n*, fire the **Level Advance** event and unlock map level *n + 1*. A sub-skill whose range ends at *n* (e.g., PA at L2) counts as finished.
5. **Question selection within a level:** pick the active, unmastered sub-skill with the lowest P(L), using tasks for that sub-skill at level *n*. Never repeat the same item twice in a row.
6. **Hints:** after an **incorrect** answer, if the posterior is < 0.30 → raccoon hint. Hints never come after a correct answer, so learners at a new level aren't flooded.
7. **Guess rate per task type:** a 3-choice item has a real guess rate of ~0.33, not 0.20. Set P(G) ≈ 1 / number of choices for MCQ-style tasks; drag/sequence tasks keep the table values. Keep 1 − P(S) > P(G).
8. **Going down a level:** never automatic from a single wrong answer. Only a **failed Heart Recovery** drops a skill back ([06-game-design.md](06-game-design.md#heart-system-and-heart-recovery-mini-game-246)).

### ARAL band shown to teachers (replaces old Table 3.6)
The band comes from the student's **highest unlocked map level**, not from raw P(L):

| Map level | Name | ARAL band | Task type |
|---|---|---|---|
| 1 | Foundational | ARAL Basic | Single-syllable words; letter-sound matching |
| 2 | Emerging | ARAL Basic / Plus | Two-syllable words; sight words |
| 3 | Developing | ARAL Plus | Simple sentences; who/what questions |
| 4 | Approaching | Approaching Proficient | Short paragraphs; where/when questions |
| 5 | Proficient | Grade-Level Proficient | Multi-paragraph stories; inference/prediction |
| 5, all mastered | — | Grade-Level Proficient (complete) | — |

The dashboard also shows, per sub-skill, its current level and P(L) as a progress bar inside that level. Intervention flags: P(L) < 0.30 after ≥ 5 attempts at a level, or a failed Heart Recovery.

### Manuscript changes
- Table 3.6: drop the P(Lt) range column; map level → ARAL band → task type (table above).
- §3.4.3.2 Step 3: "difficulty mapping" becomes the progression model above.
- §2.5.1 and FR-04: mastery = P(L) ≥ 0.95 *with a minimum of 5 attempts per skill-level*.
- Figure 3.17: "Increment reading level for sub-skill" becomes "Mark skill-level mastered; if all skills at this level are mastered → Level Up".

## Per-response flow (Figure 3.17)
1. Student submits response → evaluate correct/incorrect.
2. Apply the posterior update equation.
3. **Mastery check**: if posterior ≥ 0.95 and attempts ≥ 5 → mark this skill-level mastered; if all active skills at this map level are mastered → Level Advance. Then compute P(Lt+1) and increment `attempts`.
4. Save the state locally and queue it for sync to the Laravel API / PostgreSQL (the thesis says "to Firebase"; see open issue 1). Then collect student feedback and send a system notification.
5. **Engagement check**: if the answer was incorrect and the posterior < 0.30 → hint trigger → raccoon scaffolding dialogue.
6. Await the next question.

Performance target: the whole step finishes in **≤ 500 ms** (NFR-01). Run it client-side so it also works offline.

## Server-side recalibration (EM)
- Periodically re-estimate P(L₀), P(T), P(G), P(S) per sub-skill from all students' response sequences (Expectation-Maximization), enforcing 1 − S > G.
- Store versioned parameters in the PostgreSQL `bkt_parameters` table. Clients pick them up via `GET /api/config`.
- Implementation: `pyBKT` (Python) is the reference EM implementation (cited, MDPI 2023). Options: (a) a Laravel scheduled command that shells out to a small Python script, (b) running EM manually on a CSV export and importing the results, or (c) EM written in PHP (~100 lines for the single-skill HMM). For the thesis timeline, (b) is enough.

## Inputs the thesis mentions but BKT doesn't use
§3.4.2.2 says the AI monitors **accuracy and latency**. Standard BKT uses correctness only. `response_ms` is logged, but nothing defines how it affects difficulty. Either define that or remove "latency" from the claim.

## Pre-test → BKT initialization (placement)
The 20-item pre-test is played as ordinary tasks, so every item is a BKT observation:
1. Replay each sub-skill's pre-test items through BKT on that sub-skill's **lowest-level** state (starting from P(L₀)). The minimum-attempts rule doesn't apply to placement.
2. If the result is ≥ 0.95, mark that skill-level mastered.
3. Start the student on the **lowest map level that still has an unmastered active skill**.
4. Store the raw pre-test scores separately for the research analysis (RQ1). Placement doesn't change them.

Only 3 items per sub-skill (8 for Literal Comprehension) means placement is coarse. Gameplay corrects it quickly.
