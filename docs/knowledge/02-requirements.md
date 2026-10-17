# 02 — Requirements

## Functional requirements (thesis Table 3.1)

| ID | Requirement | Priority |
|---|---|---|
| FR-01 | Authenticate users in three roles: **Student, Teacher, Administrator**. | High |
| FR-02 | Administer a **Pre-Test** to set each learner's baseline before gameplay. | High |
| FR-03 | Run **BKT** to track mastery probability per reading sub-skill in real time. | High |
| FR-04 | Adjust difficulty from BKT mastery (threshold **≥ 0.95**) to keep learners in their ZPD. | High |
| FR-05 | Generate **AI pedagogical summaries** (strengths, areas needing intervention). | High |
| FR-06 | **Teacher Dashboard** with real-time class-wide and per-student progress. | High |
| FR-07 | **Reward economy**: earn points, redeem for raccoon customizations in a shop. | Medium |
| FR-08 | Admin **approves/denies teacher registrations** and **retrieves system logs** for anomaly monitoring. | Medium |
| FR-09 | All content aligned to **MATATAG** competencies: phonological awareness, phonics, vocabulary, fluency, literal comprehension. | High |
| FR-10 | Administer a **Post-Test** after the evaluation period. | High |

## Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-01 | Performance: BKT update **≤ 500 ms** after each interaction. |
| NFR-02 | Usability: touch targets **≥ 48×48 dp**, fonts **≥ 24 pt** (Grade 1 UI standard). |
| NFR-03 | Reliability: **≥ 99% uptime** during school hours. |
| NFR-04 | Data privacy: comply with **RA 10173 (Data Privacy Act of 2012)**; learners are minors. |
| NFR-05 | Scalability: multiple classrooms concurrently without response degradation. |

## Requirements implied elsewhere in the thesis (not in Table 3.1, but described as features)

Add these to Table 3.1 or the backlog, since the thesis describes them as part of the system:

| Proposed ID | Requirement | Source |
|---|---|---|
| FR-11 | **Offline gameplay**: cache Levels 1–5 content, BKT states and pending responses locally, then auto-sync when online. | Teacher interviews; Tech stack; Deployment |
| FR-12 | **Time-restricted access**: class window, lock during other subjects, 30 min/day after school, weekends off by default. | §3.4.2.3 |
| FR-13 | **Heart system**: 3 hearts, lose one per consecutive wrong answer, Heart Recovery mini-game at 0 hearts. | §2.4.6 |
| FR-14 | **Raccoon companion hints** when P(L) < 0.30, plus supportive dialogue at decision points. | §3.4.3.2, §3.4.3.3 |
| FR-15 | **Scoring feedback** after each level: stars, accuracy %, response outcomes, XP and coins. | §3.4.2.2 |
| FR-16 | **Teacher roster management**: add/remove students. | Teacher flow, orientation |
| FR-17 | **Intervention flags**: color-coded low-P(L) alerts, plus an auto-flag when heart recovery fails. | Teacher dashboard, §2.4.6 |
| FR-18 | **PDF export** of AI class/student reports. | Teacher flow, orientation |
| FR-19 | **Remote config** of BKT/GPT parameters and UI scaling without reinstalling. | §3.4.3.3 Stage 6, Deployment |
| FR-20 | **Audio narration** (TTS or recorded) for passages, plus BGM and SFX. | Tech stack |
| FR-21 | **AI output logging** with timestamp and input, for monitoring. | MLDLC Stage 6 |
| FR-22 | Admin **data privacy audit** view. | Admin flow |

## Device requirements (thesis Table 3.8)

| Component | Minimum | Recommended |
|---|---|---|
| OS | Android 8.0 / iOS 13.0 | Android 11 / iOS 15+ |
| CPU | Quad-core 1.5 GHz | Octa-core 2.0 GHz+ |
| RAM | 2 GB | 3 GB+ |
| Storage | 500 MB free | 1 GB+ |
| Screen | 720p | 1080p |
| Network | Wi-Fi / mobile data for login + sync | Stable Wi-Fi; offline gameplay |
| Touch | Capacitive multi-touch | same |
| Battery | ≥ 30-min session | battery-saver supported |

School Wi-Fi benchmark: **3 Mbps**. Distribution is a **signed APK** sideloaded via local transfer or MediaFire, not the Play Store. iOS (IPA) is mentioned but no iOS devices are confirmed.

## Grade 1 UI/UX rules (Ungrammary, 2024)
- Touch targets ≥ 48×48 dp, **~64 px spacing** between targets.
- Prefer **drag/swipe** over precise taps.
- **3–5 choices** per screen max.
- Text ≥ 24 pt.
- Palette: vibrant orange, cheerful yellow, soft cream, calming light blue.
