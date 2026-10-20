# 10 — Open Issues, Contradictions and Decisions Needed

Found while analyzing the manuscript (2026-10-17). Resolve each one, record the decision here (and in Graphify memory once the repo is indexed), and fix the manuscript to match.

Status key: 🔴 blocks coding · 🟡 decide during build · 📝 manuscript-only fix

---

### 1. Backend and database ✅ RESOLVED (2026-10-17)
- The tech stack table (3.4) and §3.4.2.3 say **Laravel + MySQL + Sanctum**.
- The ERD text, all flowcharts, NFR-05, BKT persistence, AI log storage, Remote Config, the deployment chapter and the checklist all say **Firebase** (Realtime DB, Auth, Remote Config).
- **Decision:** **Custom-coded backend: Laravel (PHP 8.x) + PostgreSQL 16+ + Sanctum. No Firebase anywhere.** "Custom-coded" is a required instruction from the adviser/professor ("hard code the backend" = build it yourselves instead of using a backend-as-a-service). **PostgreSQL instead of MySQL** was the team's choice (same day).
- **Consequences:**
  - Offline queue + sync must be built by hand in the Godot client (see [03-architecture.md](03-architecture.md#offline-and-sync-design)).
  - Firebase Remote Config is replaced by `GET /api/config`.
  - Firebase Auth is replaced by Sanctum tokens. Firebase security rules are replaced by Laravel policies/middleware.
  - "Firebase log node" is replaced by PostgreSQL `system_logs` / `ai_logs` tables.
  - We need hosting for PHP + PostgreSQL with HTTPS, reachable from school Wi-Fi. Many cheap shared PHP hosts are MySQL-only.
- **Manuscript to update:** Table 3.4 and §3.4.3.1 ("MySQL 8.x" → "PostgreSQL"), plus every "Firebase" mention: §2 none; §3.4.2.4 flow figures 3.11–3.15 and ERD text; NFR-05; §3.4.3 intro; §3.4.3.2 Step 2 and Step 4; §3.4.3.3 Stages 5–6; §3.4.4.1; §3.4.4.2 consent forms; §3.4.5 Activities 1–3 and checklist items 2, 4, 8, 9; §3.4.6.

### 2. AI model and hosting ✅ RESOLVED (2026-10-17)
- The thesis says "OpenAI GPT API (GPT-OSS-20B)" and mentions GPT-4 elsewhere. That mixes up the model and the provider.
- Advisor comment [b]: *"you need to specify what 'AI' is this."*
- **Decision:** **Google Gemini API**, using a cost-efficient **Flash / Flash-Lite** model (pin the exact model ID from Google's current model list in `.env`). It's paid with the **Google Cloud credits included in the team's Google AI Pro subscription** (~US$10/month) on a **billing-enabled** Google Cloud project, and called **only from Laravel**.
- **Why:** the team already has the subscription, so the cost is effectively zero (the study needs roughly US$5 of usage). Gemini is fast and handles English and Filipino well.
- **Superseded:** an earlier same-day decision of gpt-oss-20b on Groq. That would have been the smaller manuscript change and supports the open-weight "offline AI" future-work claim; this switch gives both up.
- **Manuscript wording:** "Google Gemini [model name], a large language model accessed through the Gemini API from the Laravel backend." Replace every "OpenAI GPT API", "GPT-OSS-20B" and "GPT-4" that describes this system. Rename "GPT report/dialogue" to "AI report/dialogue". The future-work item "local language model for offline AI" still stands, but as switching to a small open-weight model rather than "running the same model locally".
- **Check:** use the API under **paid (billing-enabled) terms**, not the free tier. Free-tier prompts may be used by Google to improve its products, which isn't acceptable for children's data under RA 10173.
- Details: [08-ai-integration.md](08-ai-integration.md).

### 3. Pre-test item count 📝
- The text says 20 items, and the blueprint rows add up to 20 (3+3+3+3+8). But the table total says **30**, the text says "8 of 200", "five items each", and "scores out of 30"; statistics say "out of 20".
- **Fix:** use 20 everywhere.

### 4. BKT level progression model ✅ RESOLVED (2026-10-17)
- **Decision:** option **A**, refined: BKT per **(sub-skill, level)** (14 states per student); global adventure levels 1–5; a skill-level is mastered at **P(L) ≥ 0.95 with ≥ 5 attempts**; **Level Up** when all skills active at that level are mastered; hint only **after a wrong answer** when P(L) < 0.30; P(G) ≈ 1/number of choices for MCQ items; the ARAL band comes from the map level, not raw P(L).
- **Why:** a simulation with the thesis parameters showed 3 correct answers in a row pass 0.95 for every sub-skill, so P(L) can't be used directly as a level score.
- Full spec: [05-bkt-engine.md](05-bkt-engine.md#level-progression-model-decided-2026-10-17-open-issue-4).
- **Update (2026-10-20):** pre-test placement uses the Table 3.5 guess rates (not 1/choices), or nobody could be placed above Level 1. See [D-003](../../brain/decisions/D-003%20BKT%20level%20progression.md).

<details><summary>Original problem</summary>

- The mapping table derives the level directly from P(L) (0.95–1.00 = Level 5), but the flowchart says reaching 0.95 increments the level by one.
- The hint bound P(L) < 0.30 equals the whole Level 1 band, so Level-1 learners would get a hint on every question.
- **Options:**
  - (A) **Per-level BKT**: track P(L) per sub-skill *per level*. At ≥ 0.95, advance one level and reset P(L) to that level's prior. Base hints on a drop or streak (e.g., P(L) < 0.30 *and* falling, or 2 consecutive errors), not the absolute band. *(recommended: matches "level up" gameplay and FR-04)*
  - (B) **Direct mapping**: level = band(P(L)). Drop the "increment" language and change the hint rule.

</details>

### 5. Heart recovery penalty ✅ RESOLVED (2026-10-17)
- **Decision:** a correct answer resets the streak and refills hearts. Recovery uses 3 items of the same sub-skill one level down (or easier same-level items when there's no lower level), and those answers update BKT. Partial recovery un-masters the lower skill-level (P(L) → min(current, 0.70), attempts reset), keeps the current map level unlocked, and flags the teacher. At most 2 recoveries per session.
- Full rules: [06-game-design.md](06-game-design.md#heart-system-and-heart-recovery-mini-game-246).
- **Manuscript:** rewrite the last paragraph of §2.4.6 to match ("P(Lt) decremented by one difficulty tier" → the rule above).

### 6. Figure captions swapped 📝
- Fig 3.12 "Student Login & Pre-test" actually shows the **access-control** flow.
- Fig 3.14 "Admin Flow" actually shows the **adaptive gameplay loop**, and Fig 3.15 "Adaptive Gameplay Loop" shows the **admin** flow.
- Table numbers are off by one in the text references (e.g., "Table 3.6" means initial params, which is labeled 3.5; Table 3.3 is used twice). Section refs say "3.3.x" where they mean "3.4.x".
- The architecture diagram needs grouping (advisor comment [a]).

### 7. Missing requirements in Table 3.1 📝 / 🟡
- Offline mode is called "non-negotiable" in one place and "medium-priority" in another, and isn't an FR.
- Time-restricted access, the heart system, hints, PDF export, roster management and remote config aren't FRs either.
- See proposed FR-11…FR-22 in [02-requirements.md](02-requirements.md).

### 8. ERD gaps 🔴
- The `students.session_id` FK is backwards. The ERD has no tables for content, choices, competencies, BKT params, assessments, shop/wallet, schedules, usage, flags, registrations, logs, or consent.
- Credentials are inconsistent: the ERD has `username` + `hashed_pin`, but flows say "email & password" (teacher) and "student & password" or "student ID" (student).
- See [04-data-model.md](04-data-model.md).
- **Progress (2026-10-20):** the first tables are built in `backend/database/migrations/` for the data the game already produces: `users` (role), `sections`, `students`, `bkt_states` (14 per student), `path_progress`, `student_wallets`, `intervention_flags`, `sync_events`. `students.session_id` is dropped; age and gender are left out until the study justifies them (RA 10173). Sync rules: [D-008](../../brain/decisions/D-008%20Offline%20sync%20contract.md). Still to design: content/questions/choices, competencies, `bkt_parameters`, sessions/responses, assessments, shop, schedules, usage, registrations, logs, consent.

### 9. Student login method 🟡
- 6–7-year-olds can't reliably type passwords. **Decide:** picture password / PIN, a teacher-issued QR code, or tap-your-name on a teacher-managed device.
- **Interim (2026-10-20):** the backend signs students in with an 8-character **login code** (`POST /api/auth/login`, e.g. `K7PM-3QXA`, no 0/O/1/I/L). Codes are random, shown once at enrolment and stored only as a SHA-256 hash. A QR card could carry the same code. Replace or wrap it once this issue is decided. Teacher/admin email + password login isn't built yet.
- **Game side (2026-10-20):** a grown-up connects a device from the **Grown-ups** screen (behind a times-table gate): server address + the student's login code. One profile per device until this issue is decided.

### 10. Offline vs time-restricted access 🟡
- The access check is server-side, so offline the app can't verify the schedule. **Decide:** cache the schedule + last server time and enforce it locally using the device clock, with tamper detection.
- **Groundwork (2026-10-20):** `GET /api/config` and `POST /api/sync` return `server_time`, and every synced event keeps both `device_time` and `received_at`, so the client can track its clock offset and the server can spot clock jumps.
- **Built in the game (2026-10-20):** `AccessPolicy` (class window open, other school hours locked, after-school 30-min daily cap with a countdown, weekends off unless opened, nights asleep). The schedule comes from `GET /api/access/student/status` and is cached; the device clock is corrected by the server offset; a clock that jumps backwards raises a `clock_jump` flag. With no schedule yet, the game stays open. Lock screens never close the app. Server endpoint: teacher dashboard session (in progress).

### 11. Timeline vs reality 🔴
- The Gantt shows development May–Aug 2026 and testing Jun–Oct 2026 (4 months). As of 2026-10-17 **no code exists**, and the deadline is November 2026.
- **Action:** re-plan the scope (an MVP cut) and the evaluation period with the adviser.

### 12. Past-tense "results" in the methodology 📝
- §3.4.5 says "All ten verification items passed…", teacher praise is reported, and the Reviewing phase claims successes and challenges. These read as completed results, but the system isn't built yet.
- **Fix:** rewrite in future tense until real data exists. Advisers and panels will flag fabricated-looking results.

### 13. Curriculum/teacher validity (advisor comments) 🟡
- [c] *"paki revisit or interview utro basin nag change na pd ug curriculum..given na three-term na ang classes next school year."* The advisor asks the authors to re-interview teachers because the curriculum may have changed with the three-term school year.
- [d] (author reply) *"wa na po teacher ing ani na sir, tong na interview namo, nag ingon na kotob ra sila graduation."* The authors say the interviewed teacher isn't available for this anymore (only until graduation).
- **Action:** confirm current Grade 1 competencies and who will review content and take part in TAM.

### 14. TAM instrument vs RQ3 wording 📝
- RQ3 asks about **functionality, usability, reliability, curriculum alignment**, but the instrument only measures PU/PEOU. Consider an ISO/IEC 25010-based instrument for the IT experts.
- The Reviewing phase uses 4.00–4.49 = "Agree", but Table 3.12 uses 3.50–4.49. Align the two.

### 15. Language policy 🟡
- L1–2 are in "Mother Tongue" (Bisaya/Butuanon in Butuan), yet future work suggests "adding Bisaya passages", so it's unclear which Mother Tongue L1–2 actually use. Re-check against current DepEd language policy.
- **Interim (2026-10-20):** the first game slice uses **English placeholder** items (`reading-racoon/content/levels.json`, `"language": "en-placeholder"`). Replace them once the language is decided and teachers review the content.
- **Levels 3-5 (2026-10-20):** placeholder content follows the bridge: **Filipino** for levels 3-4 and **English** for level 5, with 8 Butuan stories (60 / 100 / 130-word caps), plus 20-item pre- and post-tests in the thesis blueprint. All of it needs teacher review.

### 16. Latency claim 📝
- §3.4.2.2 says difficulty uses accuracy **and latency**, but BKT only uses correctness. Either define how latency is used or remove it.

### 17. Fluency assessment validity 📝
- MATATAG fluency means speed, accuracy and expression when reading aloud. The game's proxy tasks don't measure oral fluency. State this as a limitation (or add speech capture as future work).

### 18. Minor manuscript items 📝
- "sample is small (n = 62)": 62 is fine for a paired t-test, so reword the justification.
- A stray "2" before "Therefore" in §2.3.2. The Butler 2023 vs Buckley 2021 citation spelling ("Buckey") should be checked.
- Several references (e.g., Abejuela 2023, Kumar 2026, Davis & Granić 2024) should be checked to make sure they exist exactly as cited.
- Some references are unrelated to the topic (prenatal care, antenatal depression, nutrition). Remove the ones that are never cited.

### 19. Game engine: Unity → Godot ✅ RESOLVED (2026-10-17)
- The thesis specifies **Unity + C#** (Table 3.4, §3.4.3.1).
- **Decision:** **Godot 4.7 + GDScript**, Compatibility renderer, Android APK first. The project is in `reading-racoon/` (portrait 720×1280 since 2026-10-20). The team chose this independently of the thesis.
- **Why:** the app is 2D and UI-heavy and targets low-end Android (2 GB RAM). Godot is lighter and has built-in drag-and-drop UI and TTS. Its text-based scenes and the existing Godot MCP connection let Claude build and run scenes directly.
- **Trade-offs accepted:** a smaller asset store and fewer tutorials than Unity, and weaker 3D tools. The raccoon companion becomes a 2D animated character unless 3D is kept.
- **Manuscript to update:** Table 3.4 (game engine, language, offline cache, API client, assets, build), §3.4.3.1 justification paragraph, §3.4.3.2 ("Unity-based C# implementation"), §3.4.3.3 Stage 5, Table 3.8 system requirements (re-check minimums for Godot), §3.4.5 Activity 1 ("Unity project was compiled"). **Tell the adviser about the switch.**

### 20. UI direction ✅ RESOLVED (2026-10-20)
- The thesis shows low-fidelity Figma screens but no overall interaction model.
- **Decision:** a Duolingo-style vertical learning path (worlds = map levels, lesson nodes, chest, trophy), mixed with kids'-app patterns (audio-first prompts, answer on tap, a reacting raccoon guide). **Portrait 720×1280.** No leaderboards, no streak guilt, no red ✗.
- Full table of borrowed ideas: [D-007](../../brain/decisions/D-007%20UI%20direction%20Duolingo-style%20path.md).
- **Manuscript to update:** §3.4.2.2 (mechanics) and the Figma screens in §3.4.2.4 should show the path, the lesson layout and Racoon's Rescue.

### 21. Art direction ✅ RESOLVED (2026-10-20)
- The first build looked generic and used emoji as pictures.
- **Decision:** a paper-cut storybook look set in Butuan City (Agusan River, Mango Grove, Bahay Kubo Village, Balangay Bay, Mount Mayapay), built with Godot UI only; pictures are tinted SVG silhouettes from game-icons.net (CC BY 3.0); **no emoji**. Details: [D-009](../../brain/decisions/D-009%20Art%20direction%20Butuan%20storybook.md).
- **Manuscript to update:** credit game-icons.net (CC BY 3.0) and its authors in the acknowledgments or an appendix; show the new screens in §3.4.2.4.
