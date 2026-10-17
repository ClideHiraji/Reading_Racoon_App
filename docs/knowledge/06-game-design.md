# 06 — Game Design

## Core concept
- **Stealth assessment**: evaluation is embedded in gameplay, with no visible "test", which lowers anxiety.
- **Reading Adventure map**: progression map showing levels, unlocked tiers and rewards.
- **Raccoon companion**: a friendly 3D raccoon avatar (the app's mascot). It gives hints and encouragement, and can be customized.

## Mechanics (§3.4.2.2)
| Mechanic | Detail |
|---|---|
| Tactile interactions | Tap multiple choice, drag syllables/letters/words, **spin-n-match** ("Spin the Words") |
| Dynamic difficulty | BKT adjusts per sub-skill in real time |
| Scoring and feedback | After each level: **star rating, accuracy %, per-response outcomes** |
| AI evaluation | Diagnostic summary sent to the teacher dashboard |
| Reward loop | **XP + coins** → Shop → hats, glasses, shirts, badges for the raccoon |

## Task types per sub-skill
| Sub-skill | Game tasks |
|---|---|
| Phonological awareness | Tap the rhyming word; drag syllable tiles to rebuild a word; count syllables in a spoken word |
| Phonics | Drag the missing letter into a word; pick the word matching an audio cue; **Spin the Words** word-family task (e.g., -OCK + picture) |
| Vocabulary | Match word ↔ picture; choose meaning from context; tap the sight word among distractors |
| Fluency | Arrange jumbled words into a sentence; tap words in reading order; sentence-completion drag |
| Literal comprehension | Who/what/where/when MCQ after a passage; sequence-the-events drag; predict-what-happens-next |

Other literature ideas listed: Rhyming Match, Clap the Syllables, Sound Blending, Letter-Sound Bingo, Word Building Race, Memory Match, Story Sequencing, Question Ball Toss, True or False, Who-What-Where Relay.

## Adaptive gameplay loop (actual flowchart, image 43)
1. Open Adventure → select a reading level (BKT decides which tiers are unlocked).
2. Reading task shown (story + audio + raccoon companion).
3. Comprehension question (tap / drag-and-drop).
4. BKT updates P(L): correct raises it, incorrect lowers it.
5. P(L) ≥ 0.95 → **Level Up**, go to the next tier and back to level select.
6. Otherwise, if P(L) < 0.30 → **raccoon hint shown** → next question.
7. Level complete (all questions answered)? If not, next question.
8. Results and score screen (stars, accuracy, XP earned) → XP and coins credited → return to map.

## Heart system and Heart Recovery mini-game (§2.4.6)
- Each session starts with **3 hearts**, shown prominently.
- Each **consecutive** wrong answer within a sub-skill task costs 1 heart.
- At the 3rd error, primary gameplay **pauses** and the **Heart Recovery mini-game** starts. The session does not end.
- Recovery: **3 simplified review questions** from **one tier below** the current level (e.g., L3 → L2 content). Each correct answer restores 1 heart. The raccoon gives encouraging dialogue throughout.
- Full recovery → resume at the original level with full hearts.
- Partial recovery → that sub-skill's mastery is **dropped one difficulty tier**, and the **teacher dashboard is notified** (flag for intervention, ARAL-style tiered support).
- Design intent: the error limit is a diagnostic pivot, not a punishment.

**Decided rules (2026-10-17, open issue 5), matching the progression model in [05-bkt-engine.md](05-bkt-engine.md#level-progression-model-decided-2026-10-17-open-issue-4):**
- **Streak:** hearts track *consecutive* wrong answers within the current sub-skill. A correct answer **resets the streak and refills hearts to 3**.
- **Recovery content:** 3 items of the **same sub-skill** at level *n − 1*. If *n* is that sub-skill's lowest level, use **easier items at the same level** (tagged `recovery: true`, e.g., 2 choices instead of 4, picture support).
- **Recovery answers are real BKT observations.** They update the (sub-skill, *n − 1*) state, or the same-level state when there's no lower level.
- **Full recovery (3/3)** → back to level *n* with 3 hearts. Nothing else changes.
- **Partial recovery (< 3/3)** = "drop one tier":
  - The (sub-skill, *n − 1*) state loses its mastered status: P(L) is set to **min(current, 0.70)** and its attempt counter restarts. The learner then has to show mastery again, with at least 5 attempts.
  - Map level *n* **stays unlocked** (no lockout). The map shows a "Review with Racoon" badge on level *n − 1* for that sub-skill, and the next questions for that sub-skill come from *n − 1* until it's mastered again.
  - If there's no lower level, nothing is demoted.
  - In both cases an **intervention flag** goes to the teacher dashboard (sub-skill, level, timestamp) and is written to the log.
- After partial recovery, the session continues with 3 hearts. Recovery can't trigger more than **twice per session**. On a third trigger, the raccoon ends the session kindly ("Let's rest and try again tomorrow!") and flags the teacher.

## Time-restricted access (§3.4.2.3, server-enforced)
| Window | When | Allowed | Restriction |
|---|---|---|---|
| Class session | Teacher-set (e.g., 7:30–8:30 AM) | Everything: gameplay, pre/post-test, BKT, companion | None |
| Other subjects | Rest of school hours | Nothing | "Class is in session" lock screen; can't be bypassed |
| After school | Configurable (e.g., 3–5 PM) | Gameplay **≤ 30 min/day**, visible countdown; BKT syncs | Friendly lock at the limit ("Great work today! See you tomorrow") |
| Weekends / DepEd holidays | Sat, Sun, holidays | Off by default; teacher/admin toggle, same 30-min cap | |

- The client calls `GET /api/access/student/status` at login and at every screen transition.
- When locked, it shows a themed raccoon lock screen and never kills the app.
- Lock-screen texts from the flowchart: "Come back during Reading time", "Game is sleeping", "Great work today! See you tomorrow".
- Every access decision is logged (timestamp, ID, status).

## User flows (figures, with the captions corrected)
> In the manuscript, the captions of Figures 3.12, 3.14 and 3.15 don't match their images. This is the corrected mapping.

- **Login and role selection** (image 32): role screen (Student/Teacher/Admin) → role login → auth → *Student*: load BKT → student dashboard → pre-test/game. *Teacher*: check admin approval (loops until approved) → teacher dashboard. *Admin*: load portal + logs → approve/deny pending registrations.
- **Student login + access control** (image 44, captioned "Student Login & Pre-test"): role select + student ID → auth (Laravel + Sanctum) → access-window check → full / limited / lock → session logging.
- **Student pre-test** (text only): first-time student → 20-item diagnostic across 5 sub-skills → initialize BKT → adventure starts at the matching level.
- **Teacher dashboard** (image 28): login (admin-approved accounts only) → if the class is empty, add students → dashboard (roster + BKT indicators) → class progress (mastery bands, ARAL tier counts) → intervention flags → student profile and BKT chart → AI report (strengths, gaps, MATATAG alignment) → plan intervention → export PDF.
- **Admin** (image 37, captioned "Adaptive Gameplay Loop"): login → dashboard → task: teacher registration / system logs / privacy audit → anomaly? flag and take action : log the outcome → continue or log out.
- **Adaptive gameplay loop** (image 43, captioned "Admin Flow"): see above.

## Screens (low-fidelity Figma)
- Role choice: large rectangular buttons.
- Student: Pre-Test, Reading Adventure map, "Level 3 – Simple Stories" reading screen with character hints, Reading Questions (tactile MCQ), shop and customization.
- Teacher: class dashboard, mastery/fluency/comprehension metrics, longitudinal progress, student profile, AI reports.
- Admin: teacher account management (approve/revoke), log retrieval, anomaly visualization.

## Companion guardrails
6–7-year-olds can form strong attachments to AI. The companion must stick to **curriculum task support** and avoid open-ended social chat (Vasan 2025; Xu 2024). Keep dialogue short, positive and on-task.

## Reward design cautions
Avoid global leaderboards and heavy competition, which demotivate struggling learners (MDPI 2023/2024). Keep rewards personal (cosmetics, stars).
