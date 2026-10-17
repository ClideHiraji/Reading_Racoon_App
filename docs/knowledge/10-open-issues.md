# 10 — Open Issues, Contradictions and Decisions Needed

Found while analyzing the manuscript (2026-10-17). Resolve each one, record the decision here (and in Graphify memory once the repo is indexed), and fix the manuscript to match.

Status key: 🔴 blocks coding · 🟡 decide during build · 📝 manuscript-only fix

---

### 1. Backend and database ✅ RESOLVED (2026-10-17)
- The tech stack table (3.4) and §3.4.2.3 say **Laravel + MySQL + Sanctum**.
- The ERD text, all flowcharts, NFR-05, BKT persistence, AI log storage, Remote Config, the deployment chapter and the checklist all say **Firebase** (Realtime DB, Auth, Remote Config).
- **Decision:** **Custom-coded backend: Laravel (PHP 8.x) + PostgreSQL 16+ + Sanctum. No Firebase anywhere.** "Custom-coded" is a required instruction from the adviser/professor ("hard code the backend" = build it yourselves instead of using a backend-as-a-service). **PostgreSQL instead of MySQL** was the team's choice (same day).
- **Consequences:**
  - Offline queue + sync must be built by hand in Unity (see [03-architecture.md](03-architecture.md#offline-and-sync-design)).
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

### 9. Student login method 🟡
- 6–7-year-olds can't reliably type passwords. **Decide:** picture password / PIN, a teacher-issued QR code, or tap-your-name on a teacher-managed device.

### 10. Offline vs time-restricted access 🟡
- The access check is server-side, so offline the app can't verify the schedule. **Decide:** cache the schedule + last server time and enforce it locally using the device clock, with tamper detection.

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

### 16. Latency claim 📝
- §3.4.2.2 says difficulty uses accuracy **and latency**, but BKT only uses correctness. Either define how latency is used or remove it.

### 17. Fluency assessment validity 📝
- MATATAG fluency means speed, accuracy and expression when reading aloud. The game's proxy tasks don't measure oral fluency. State this as a limitation (or add speech capture as future work).

### 18. Minor manuscript items 📝
- "sample is small (n = 62)": 62 is fine for a paired t-test, so reword the justification.
- A stray "2" before "Therefore" in §2.3.2. The Butler 2023 vs Buckley 2021 citation spelling ("Buckey") should be checked.
- Several references (e.g., Abejuela 2023, Kumar 2026, Davis & Granić 2024) should be checked to make sure they exist exactly as cited.
- Some references are unrelated to the topic (prenatal care, antenatal depression, nutrition). Remove the ones that are never cited.
