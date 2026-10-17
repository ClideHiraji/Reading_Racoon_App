# 09 — Evaluation and Deployment

## A. Pre-test / post-test (RQ1, RQ4, RQ5)
Oral administration with visual supports (accommodates non-readers). Validated by 2 Grade 1 teachers + 1 literacy expert.

| Sub-skill | Question type | Items | Difficulty |
|---|---|---|---|
| Phonological Awareness | Rhyme identification; syllable counting | 3 | Easy |
| Phonics | Letter-sound matching; CVC decoding | 3 | Easy–Moderate |
| Vocabulary | Word meaning in context; picture matching | 3 | Moderate |
| Reading Fluency | Sentence arrangement; word recognition | 3 | Moderate |
| Literal Comprehension | Who/What/Where/When; prediction | 8 | Moderate–Challenging |
| **Total** | | **20** | |

(The manuscript table says 30, and the text says "8 of 200" and "five items each". **20 is the correct total.**)

## B. TAM survey (RQ3): 10 items, 5-point Likert, N = 5 (2 teachers + 3 IT experts)
**Perceived Usefulness (1–5)**
1. Monitors reading progress in real time.
2. Reduces admin burden vs Phil-IRI/EGRA.
3. AI reports give actionable intervention insights.
4. Content aligned to MATATAG Grade 1.
5. Student dashboard clearly shows mastery per sub-skill.

**Perceived Ease of Use (6–10)**

6. Easy to navigate without training.
7. Login/role screens are intuitive.
8. Teacher dashboard is easy to read at a glance.
9. Comfortable integrating it into the daily routine.
10. Technically reliable and functionally sound.

| WM range | Interpretation | TAM implication |
|---|---|---|
| 4.50–5.00 | Strongly Agree | Highly Acceptable |
| 3.50–4.49 | Agree | Acceptable |
| 2.50–3.49 | Neutral | Moderately Acceptable |
| 1.50–2.49 | Disagree | Not Acceptable |
| 1.00–1.49 | Strongly Disagree | Highly Not Acceptable |

Composite WM per construct, plus an overall score.

## C. Classroom observation checklist (two observers for inter-rater reliability)
- **Engagement:** voluntarily replays after a level; visible enthusiasm; ≥ 10 min of sustained attention.
- **Confusion:** > 30 s without progress (overload); repeated taps on the same wrong answer (perseveration); asks the teacher for help; raccoon hint triggered (BKT < 0.30).
- **Adaptive response:** advances at ≥ 0.95; difficulty drops after repeated errors; tier matches the teacher's ARAL band.
- **Technical:** no crashes; touch accuracy OK; offline mode works.

Several of these can be **logged automatically** by the app (idle > 30 s, repeated wrong taps, hint triggers, level changes, crashes). Build telemetry for them.

### Adjustment log and severity tiers
Columns: date, observed issue, affected component, adjustment made.
Tier 1 = minor UI fix (≤ 24 h) · Tier 2 = algorithm/content change (1 sprint, 1–2 weeks) · Tier 3 = architectural / GPT template change (needs teacher + adviser consultation).

## D. Statistics
- **Descriptive** (RQ1, RQ4): mean and SD per section and per sub-skill; scores converted to %; bands Below Basic / Basic / Proficient (ARAL).
- **Inferential** (RQ5): **paired-samples t-test**, α = 0.05, two-tailed, df = n − 1. `t = d̄ / (SD_d / √n)`. Effect size **Cohen's d = d̄ / SD_d** (0.2 small, 0.5 medium, 0.8 large).
- **TAM** (RQ3): WM = Σ(w·f)/N per item, then composite PU (1–5), PEOU (6–10), and overall.
- Also analyze BKT mastery logs longitudinally per sub-skill.

> Data the app must export for analysis: per-student pre/post item scores, BKT state history, sessions/responses, hint/heart events. Plan a CSV export from the admin portal.

## E. Deployment (§3.4.5)
1. **Packaging**: signed release APK, distributed by local transfer / MediaFire (not the Play Store); installed on school and team devices.
2. **Backend prep** (Laravel + PostgreSQL): deploy on an HTTPS host; run migrations + seeders; RBAC policies on; MATATAG content library seeded; accounts pre-registered; BKT records initialized with Table 3.5 defaults; Wi-Fi ≥ 3 Mbps; `/api/config` serving the current parameters; DB backups scheduled.
3. **Pre-deployment verification** (all must pass):
   1. APK installs on all devices.
   2. Student login works.
   3. Teacher login + dashboard data.
   4. Pre-test loads and records responses.
   5. BKT changes difficulty after responses.
   6. Companion dialogue arrives in < 2 s on school Wi-Fi.
   7. Offline mode keeps gameplay working.
   8. Offline data syncs when back online.
   9. AI teacher report appears after a session.
   10. Admin portal shows logs and pending registrations.
4. **Teacher orientation**: login, reading the dashboard, student profiles, AI class reports + PDF export, roster management, connectivity handling. 15-minute hands-on session, consent forms, quick-reference guide.

## F. Reviewing phase (planned outputs)
Pre/post analysis, TAM results (commendations / concerns / recommendations), and a reflective assessment.

Future-work ideas in the thesis: an offline local LLM, Bisaya passages, an SMS parent module, a longer evaluation, and full BKT calibration.
