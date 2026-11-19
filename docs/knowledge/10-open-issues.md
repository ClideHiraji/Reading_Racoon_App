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
- **Progress (2026-10-20):** built in `backend/`: FR-12 time-restricted access ([D-014](../../brain/decisions/D-014%20Time-restricted%20access%20rules.md)), FR-16 roster, FR-17 intervention flags, FR-18 PDF export in a Laravel teacher dashboard ([D-012](../../brain/decisions/D-012%20Teacher%20web%20dashboard.md)), FR-22 privacy audit in the hidden admin portal ([D-013](../../brain/decisions/D-013%20Hidden%20admin%20portal.md)). FR-21 AI output logging in `ai_logs` with the Gemini report (2026-10-21, [D-018](../../brain/decisions/D-018%20Gemini%20teacher%20report.md)).

### 8. ERD gaps 🔴
- The `students.session_id` FK is backwards. The ERD has no tables for content, choices, competencies, BKT params, assessments, shop/wallet, schedules, usage, flags, registrations, logs, or consent.
- Credentials are inconsistent: the ERD has `username` + `hashed_pin`, but flows say "email & password" (teacher) and "student & password" or "student ID" (student).
- See [04-data-model.md](04-data-model.md).
- **Progress (2026-10-20):** the first tables are built in `backend/database/migrations/` for the data the game already produces: `users` (role), `sections`, `students`, `bkt_states` (14 per student), `path_progress`, `student_wallets`, `intervention_flags`, `sync_events`. `students.session_id` is dropped; age and gender are left out until the study justifies them (RA 10173). Sync rules: [D-008](../../brain/decisions/D-008%20Offline%20sync%20contract.md). Still to design: content/questions/choices, competencies, `bkt_parameters`, sessions/responses, assessments, shop, schedules, usage, registrations, logs, consent.
- **Progress (2026-10-20, evening):** added `teacher_registrations`, `access_schedules`, `daily_usage`, `student_items`, `audit_logs` (append-only trigger), `system_logs`, `sections.teacher_id`, `students.code` (pseudonym for exports and AI prompts) and a parental-consent record on `students`. The server replays `sync_events` into the projections ([D-011](../../brain/decisions/D-011%20Server-side%20BKT%20replay.md)); pre/post-test scores come from the synced `assessment` events, so separate `assessments` tables aren't needed yet. Still to design: content/questions/choices, competencies, versioned `bkt_parameters`, `ai_logs`, `ai_reports`.

### 9. Student login method 🟡 (interim decided: D-010)
- 6–7-year-olds can't reliably type passwords. **Decide:** picture password / PIN, a teacher-issued QR code, or tap-your-name on a teacher-managed device.
- **Interim (2026-10-20):** the backend signs students in with an 8-character **login code** (`POST /api/auth/login`, e.g. `K7PM-3QXA`, no 0/O/1/I/L). Codes are random, shown once at enrolment and stored only as a SHA-256 hash. A QR card could carry the same code. Replace or wrap it once this issue is decided. Teacher/admin email + password login isn't built yet.
- **Game side (2026-10-20, [D-010](../../brain/decisions/D-010%20Student%20login%20and%20automatic%20sync.md)):** a normal login screen asks once per device for the student's code on a big keypad of valid characters only; the server address is built into the app and sync is automatic. No settings screen. Picture passwords or QR cards could still feed the same code later.

### 10. Offline vs time-restricted access 🟡
- The access check is server-side, so offline the app can't verify the schedule. **Decide:** cache the schedule + last server time and enforce it locally using the device clock, with tamper detection.
- **Groundwork (2026-10-20):** `GET /api/config` and `POST /api/sync` return `server_time`, and every synced event keeps both `device_time` and `received_at`, so the client can track its clock offset and the server can spot clock jumps.
- **Built in the game (2026-10-20):** `AccessPolicy` (class window open, other school hours locked, after-school 30-min daily cap with a countdown, weekends off unless opened, nights asleep). The schedule comes from `GET /api/access/student/status` and is cached; the device clock is corrected by the server offset; a clock that jumps backwards raises a `clock_jump` flag. With no schedule yet, the game stays open. Lock screens never close the app. Server endpoint: teacher dashboard session (in progress).
- **Built (2026-10-20, evening):** `GET /api/access/student/status` returns the section's schedule (with its time zone) and today's decision ([D-014](../../brain/decisions/D-014%20Time-restricted%20access%20rules.md)); the game caches it for offline play. Device clocks that jump backwards (`flag` clock_jump) or run more than 5 minutes ahead, and lock screens shown offline (`access` events), land in the admin system log. Still open: what the game does when its cached schedule is old.
- **Changed (2026-10-21, [D-015](../../brain/decisions/D-015%20Home%20hub%20and%20Adventure-only%20time%20locks.md)):** only Adventure (lessons, tests) follows that schedule. Practice, Library and Watch & Listen stay open with a shared 45-minute daily free-play timer outside Reading time; the hub sleeps only at night (9 PM–6 AM). New optional schedule keys: `free_play_minutes`, `day_start`, `day_end`.

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
- **The buddy's language (2026-11-18, D-033):** the student can make the buddy and the spoken menus talk in English, Filipino or Bisaya. That choice doesn't touch the lessons: items, hints and reading words keep this policy's language. The Filipino and Bisaya lines are a draft for a teacher to check (issue 35).

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
- **Colors updated (2026-10-21, [D-016](../../brain/decisions/D-016%20Thesis%20color%20palette.md)):** the thesis palette of light blue, cream, yellow and orange, with dark text on every colored button; leaf green and the world accents stay.
- **Pictures updated (2026-11-18, [D-027](../../brain/decisions/D-027%20Full-colour%20pictures.md)):** the pictures are now full-colour drawings made for the game. Only the glyphs on buttons, badges and tabs stay tinted game-icons.net silhouettes, so the credit to game-icons.net stays (issue 28).

### 22. Home hub and what stays open 🟡 (hub decided: D-015)
- The thesis has no landing page: the app opened straight into lessons, and time limits locked the whole app.
- **Decision (2026-10-21):** a game-lobby home hub (Racoon in the middle, PLAY opens a diamond picker), and only Adventure follows the school schedule. Details: [D-015](../../brain/decisions/D-015%20Home%20hub%20and%20Adventure-only%20time%20locks.md).
- **Still open (wireframe questions):** do Practice games count toward BKT or stay just-for-fun (suggested: just-for-fun, logged for the teacher)? How many free-play minutes a day (45 for now)? Songs and chants, or "record yourself reading"? Videos downloaded and curated (suggested) or online only?
- **Built with the suggested answers (2026-10-21, [D-017](../../brain/decisions/D-017%20Practice%20Library%20Watch%20and%20collections.md)):** Practice is just-for-fun (no BKT, logged as `practice` events); 45 free-play minutes; songs and chants included, no recording yet; videos curated and downloaded (Ogg Theora), none bundled. All sections are built: six Practice games, a Library of 8 placeholder books with read-along, Watch & Listen, Sticker Album, My Word Book and Today. **Server:** the new event types and the `free_play_minutes` / `day_start` / `day_end` schedule keys are accepted on the dashboard branch (4c26be5, not merged yet). Teachers pick books and videos on a Library & Videos page (D-019, e1a5d19, not merged) and the game downloads them on Wi-Fi with a SHA-256 check, never during a lesson ([D-020](../../brain/decisions/D-020%20Teacher%20content%20download%20in%20the%20game.md)).
- **Manuscript to update:** §3.4.2.2 and the screens in §3.4.2.4 should show the hub and the picker; FR-12 now applies to Adventure only.
- **Play picker merged into Home (2026-10-22, [D-022](../../brain/decisions/D-022%20Full%20UI%20redesign.md)):** one big PLAY on the hub (Adventure, Big Reading Day, or the opening time when Adventure rests); the separate diamond picker is gone.

### 23. Second try, hints, hearts and unfinished lessons ✅ RESOLVED (2026-10-22)
- The thesis loop shows the answer after one wrong try ("hint → next question", hint only when P(L) < 0.30), hearts refill on any right answer, and the first build saved every answer, so a lesson stopped halfway still counted. Every answer needed a CONTINUE tap, Adventure could drop the child straight into the pre-test, and the pre-test ended on a world card that looked like Adventure.
- **Decision (user's play-tests):** two tries per question, only the first is BKT evidence; Racoon's question-specific hint after every wrong first try; after a wrong second try, the answer and an explanation; every wrong try costs a heart and every right answer gives one back; no CONTINUE taps (a short word from Racoon, then the next question); nothing is saved until a lesson or test finishes; Adventure always opens the map, where the pre-test waits behind START; the pre/post-test ends with a results bar per skill ("Great!" / "Practice"), then the home hub. A SKIP button was tried and removed the same day. Details: [D-021](../../brain/decisions/D-021%20Second%20try%20hints%20and%20finished-only%20progress.md).
- **Still to do:** show second tries and the per-skill test results on the teacher dashboard; teachers review the hint and explanation wording (issue 15).
- **Manuscript to update:** §3.4.2.2 and the gameplay flowchart (06-game-design step 6), FR-13 (one heart lost per wrong try, one back per right answer), FR-14 (hint after every wrong first try; P(L) < 0.30 still logged), FR-15 (second-try scoring).

### 24. Visual design system ✅ RESOLVED (2026-10-22)
- The design critique of every screen found tap targets and labels below Grade 1 sizes, colors used for many meanings (green buttons beside green right answers, yellow everywhere), PLAY taking two steps, and crowded headers.
- **Decision (user reviewed the redesign canvas):** the game follows the redesign on every screen except Racoon. One meaning per color (yellow = Adventure, orange = the main button, green = a right answer only, blue = listening, plum = Big Reading Day and night); tap targets at least 96 px, main buttons 120 px, text at least 22 px; Home button on sections, ✕ on activities, round dots in games; the team's animated star wherever a star is earned. D-021 wins where the two differ. Details: [D-022](../../brain/decisions/D-022%20Full%20UI%20redesign.md).
- **Still open:** the Apple-style motion plan on the canvas's Rules board (not built yet); the source and license of the animated star and hearts before release.
- **Racoon's redesign: decided 2026-10-26 ([D-024](../../brain/decisions/D-024%20Racoon%20redesign.md)).** Option C, "Little reader": a round head, a small body, a thick ink outline with soft shading, the teal scarf, and an open book. The team's own 3D design was explored and discarded the same day.
  - **Built 2026-11-16** from the user's own drawing (see "In the game" below), not from the plan's hand-drawn mood parts.
  - **3D:** a 3D version of C, toon-shaded with an outline, is built in Blender and was refined in a seven-round loop: its outline overlaps the 2D drawing by 95.7%, and it reads well on the game's screens. It could be rendered into the same 2D parts, or shown in real-time 3D in Godot. Not decided.
  - **Motion:** a canvas demo shows the 2D drawing turning all the way around, pointing, walking up to the screen and reacting to taps. Each part of the drawing sits on his round head and body, so no extra angles are drawn (D-024). Not in the game yet.
  - **Redrawn by the user, 2026-11-16:** the user edited Racoon in Inkscape: a taller bean body and belly, thinner outlines, and no scarf or shadow; a second edit the same day moved his arms to hang at his sides. The motion demo and the parts board are now built from that file (`motion-demo/build_racoon.py`). **Decided the same day:** the scarf and the book come back as Closet items (FR-07): his default look has neither, the River scarf stays free in the Closet, and the book gets a new slot for things he holds (D-024, part 4). Both are drawn to fit him (`parts/racoon_C_closet.svg`) and can be tried on in the motion demo; not in the game yet.
  - **Game moments (2026-11-16):** a canvas board, "C · Racoon in the game", plays his animations on the real laptop lesson screen: lesson start, reading, right, hint, answer, Racoon's Rescue, level up, lesson complete, waiting, and rest. It uses the game's lines, hints and rules (D-024). The "waiting" nudge line is still a proposal for the line library.
  - **In the game (2026-11-16):** the new Racoon replaces the old one on every screen. `raccoon.gd` draws the user's drawing with the motion demo's rig, from `assets/racoon/racoon_rig.json`, and keeps the old API.
    - The lesson plays his moments, and Home has the wave and tap reactions.
    - The Closet has the scarf and the open book: new profiles wear nothing, and the book is free in the new "In his paws" slot.
    - Tested on a scratch copy; not yet on a phone, and not committed (D-024, "In the game").
  - **A Godot scene (2026-11-17):** he's now `scenes/companion/racoon_puppet.tscn`, with one node per part of the drawing (textures in `assets/racoon/parts/`) and an AnimationPlayer with his 21 moves as keyframed animations (`assets/racoon/racoon_moves.tres`), editable in the Godot editor. A script keeps the 3D look. D-024, "Racoon as a Godot scene".
  - **One texture sheet and 8 new moves (2026-11-17):** the 27 part files are packed onto one sheet (`assets/racoon/racoon_atlas.svg`). He has 8 new animations (walk around, hops, a big jump, look around, stretch, dance, tail wag, turn around), which he plays on his own after a quiet spell on Home, the start screen and the Closet. Taps on Home cycle through 8 reactions. His walks and jumps shrink to stay inside the box he's in. D-024, "One texture sheet, and a livelier Racoon".
- **Animated star and hearts (2026-10-22):** the team's Lottie files play live in the game (`ui/lottie_player.gd`): the earned star, Regain Heart for a heart that comes back, Broken Heart for a lost one, the hearts in the lesson hearts' colors.
- **Manuscript to update:** the screens in §3.4.2.4 and the color and size rules in §3.4.2.2; NFR-02 can quote the 96 px / 48 dp minimum.

### 35. A girl buddy, and a choice of language ✅ DECIDED (2026-11-18)
- The user asked for both genders for students to choose from, a girl version of the companion for girl students, and a choice of language.
- **Decision (D-033):**
  - Each student picks **Roco** (boy) or **Rina** (girl), and **English, Filipino or Bisaya**, on a new "Choose your buddy" screen. It opens the first time a student plays; the profile chip on Home opens it again. Both picks are saved with the profile.
  - Rina is the same raccoon with eyelashes, pink cheeks and ears, and a bow, so every Closet item fits her.
  - The language changes the buddy's lines and the spoken menu lines (`content/talk.json`). Lessons, hints and reading words keep their own language (issue 15). Visible labels stay English for now.
  - Voice: system text-to-speech for now, with Rina higher (pitch 1.4, a female voice where there is one). Recorded Gemini voices come later: Zeno for Roco, Cleo for Rina.
  - Details: [D-033](../../brain/decisions/D-033%20Buddies%20Roco%20and%20Rina%20and%20talk%20language.md).
- **Still open:**
  - A teacher should review the Filipino and Bisaya lines.
  - Phones without a Filipino or Cebuano voice stay silent in those languages.
  - Translating the visible labels.
  - Recording the voices.
  - The manuscript names one companion, Racoon: add the choice to §3.4.2 (FR-14).

### 34. The voice ran on into the next question ✅ RESOLVED (2026-11-18)
- The user noticed Racoon's voice carrying on into the next question. On Windows a new line waited for the sentence being spoken (D-025), so the last question's words played over the new one.
- **Decision (D-032):** a new question stops the voice at once, on every device.
- **Still open:** starting any line from quiet costs Windows' voice one slow frame (about 0.14 s) inside Godot; recorded narration would remove it. This covers a lesson, a lesson's story, Practice, and books' and videos' questions (`Speech.new_question()`). Within a question, Windows still lets a sentence finish before a new line. On Windows the stop runs on a worker thread (optimised the same day): a cut costs the game 0.1 ms instead of 210 ms, and leaving a screen no longer pauses either.
  - Details: [D-032](../../brain/decisions/D-032%20A%20new%20question%20stops%20the%20voice.md).

### 33. Windblown diamond scarves and a halo ✅ DECIDED (2026-11-18)
- The user asked for the diamond scarf to wave behind Racoon in the wind (reference: a "moving circles" scarf animation), in a design for girls and one for boys, and for an animated halo behind his head in the hats, at diamond tier (their reference picture's halo as a guide only, not to copy).
- **Decision (D-031):**
  - **Two new diamond scarves** (470 coins each): the **Starlight ribbon** (pink ribbon tails with stars, a lilac back, notched ends, twinkles) and the **Comet scarf** (a red hero tail with a gold lightning stripe, a forked end, sparks). Neither is labelled by gender. The **Rainbow scarf** blows in the wind too.
  - **The wind:** each point along a tail moves round a small circle, a little later than the one before, so waves run down to the tip; the ribbon twists to show its back; gusts; a diamond shimmer runs along it. Drawn in code (`scenes/companion/wind_scarf.gd`).
  - **The Star halo** (hat, diamond, 490 coins): a golden ring with gems and beads, a star on top, three small stars travelling round it, and a breathing glow. Our own design (`scenes/companion/halo.gd`).
  - Both turn with Racoon: behind him when he faces you, in front when he turns away. Side-on, the halo is a thin ring standing behind the back of his head, with a gap (fixed the same day: at first it sat too close and looked like a line through his head).
  - The Closet now has 52 items, 14 earned.
  - Details: [D-031](../../brain/decisions/D-031%20Windblown%20scarves%20and%20the%20Star%20halo.md).
- **Still open:** try them with children; whether the tails distract during a lesson.

### 32. The item in his paws stretched ✅ RESOLVED (2026-11-18)
- The user saw the item in Racoon's paws stretch when he moved his arms, and asked for it to be held in either paw during arm-moving animations.
- The puppet stretched the item between his two paws. Over all 28 moves the worst stretch was 74% (peek), then hint and thinking (31–32%) and dance, happy, greet and walk_around (10–13%).
- **Decision (D-030):** the item is stiff. In both paws it keeps its width; when his paws move apart or together, or one rises much higher than the other, it rides in one paw (the left, unless the left arm is the busy one), blending smoothly. A tilt turns it like a card instead of skewing it. No move changed.
  - Details: [D-030](../../brain/decisions/D-030%20Stiff%20items%20in%20his%20paws.md).

### 31. Clothes and pets instead of pins ✅ DECIDED (2026-11-18)
- The user asked for T-shirts or other upper-body clothing (dresses too) instead of the Closet's pins, a small animated pet floating by Racoon's head that plays with him, and the turn-around move removed.
- **Decision (D-029):**
  - **Clothes (slot `top`):** 11 tees, tops and dresses, from a River tee to a Barong and a Filipiniana dress. Each is trimmed to his body's outline in the game, so it fits every pose.
  - **Pets (slot `pet`):** 6 pets drawn in code (`scenes/companion/pet.gd`): maya bird, bee, butterfly, alitaptap, little dragon, star sprite. A pet loops with hearts when he's tapped, circles his head when he dances, rests on his head now and then, and sleeps there when he's sleepy.
  - **Pins retired:** an old save's pins are dropped when it loads; the drawings are kept in `tools/racoon-art/parts/retired-pins/`.
  - **`turn_around` removed** from his moves, his ambient list and the Closet's gold show-off (now `dance`).
  - The Closet now has 49 items, 14 earned; tiers and prices unchanged.
  - Details: [D-029](../../brain/decisions/D-029%20Clothes%20and%20pets%20in%20the%20Closet.md).
- **Still open:** try the pets with children (do they distract during a lesson?); a pet's sound when it cheers.

### 30. Developer menu: DELETE BEFORE THE FINAL RELEASE 🔴 OPEN (2026-11-18)
- The user asked for debug options to explore the game, and to be reminded to delete them once everything is final.
- **What it is:** `reading-racoon/ui/dev_menu.gd` (`DevMenu`).
  - It opens with **F12**, or **5 quick taps in the top-right corner**.
  - It jumps to any screen (Home, a lesson, the pre-test, every section, login, the lock screen).
  - It adds coins or sets them to none.
  - It unlocks all worlds, finishes the current world, skips the pre-test, opens the post-test, or resets progress.
  - It gives all stickers, all Closet items or today's goals.
  - It moves the clock (Monday 7:45 AM, Tuesday 6 PM, real time), and shows the frame rate or a test reward card.
- **Safe meanwhile:** it only exists in debug builds (`OS.is_debug_build()`: the editor and debug exports). A release export never shows it, and `DevMenu.ENABLED = false` hides it in debug builds too. Each debug run prints a reminder in the Output panel.
- **To delete it (all four, then run the tests):**
  1. `reading-racoon/ui/dev_menu.gd` and `ui/dev_menu.gd.uid`.
  2. In `scripts/autoload/screen.gd`: the `DevMenu.allowed()` print in `_ready()`, and the `_input()` function.
  3. In `tests/ui_smoke.gd`: the "developer menu" block at the end.
  4. Search the project for `DevMenu`: nothing should be left.

### 29. A livelier UI: shapes cut from paper ✅ DECIDED (2026-11-18)
- The user found the UI too plain ("not just full squares and rectangles or circles") and asked for something livelier, consistent, soft-coloured and fun, based on research into what children like.
- **Decision (D-028):**
  - **Hand-cut edges:** cards, buttons and panels have slightly uneven corners and gently wavy sides (`ui/paper_box.gd`, replacing StyleBoxFlat in the box builders).
  - **Round stays round:** circles and pills stay perfectly round (the user's call).
  - **Craft details:** stitches on the special big pieces (Home tiles, Practice cards, the lesson picture card, album panels), tilted Home tiles, washi tape on the lesson's picture card, pale paper confetti on section pages, and a crayon squiggle under section titles.
  - The layout, palette, Racoon and sizes are unchanged.
  - Details: [D-028](../../brain/decisions/D-028%20Paper-cut%20UI%20shapes.md).
- **Still open:** a few boxes defined inside scene files are still straight (the lesson's top bar and sheet, the overlay card); try the look with children.

### 28. Pictures in one style ✅ DECIDED (2026-11-18)
- The pictures were white silhouettes from game-icons.net, tinted in Godot (D-009). They came from many artists and didn't match each other or Racoon. The old "mouse" was a computer mouse, though the lessons mean the animal.
- The user asked for them redrawn in the style of their reference (cute, softly shaded characters with faces) and judged them on the canvas first.
- **Decision (D-027):**
  - **60 full-colour pictures** in `reading-racoon/assets/pictures/`, drawn in their own colours, never tinted. They cover every lesson picture, all 40 stickers, the Home tiles and every Practice game.
  - **Cut from paper like the rest of the game (D-009):** flat colours from the palette, each piece lifted on a crisp little shadow, no gradients, shine or outlines; each picture cropped to fill its box. Faces go on animals, the sky and fruit; objects stay faceless.
  - The first version the same day was glossy stickers with coloured outlines. In the game it looked out of place (D-009 had rejected sticker and clay looks), so it was redrawn as paper.
  - **Drawn in code** in `reading-racoon/tools/icon-art/`.
  - Glyphs the game tints (buttons, badges, tabs, the path) stay in `assets/icons/`.
  - Details: [D-027](../../brain/decisions/D-027%20Full-colour%20pictures.md).
- **Still open:** try the pictures with children (do they name each one?), especially at the smallest sizes.

### 27. Closet tiers and earned items (FR-07) ✅ DECIDED (2026-11-17)
- The user asked for richer, animated Closet items ranked in tiers, from copper (free or easy) to diamond (very expensive, with one or two earned by a hard goal), and for the items to be art files, separate from Racoon's own sheet.
- **Decision (D-026):**
  - **Five tiers:** copper, silver, violet, gold and diamond, shown as 1–5 stars and a colour. Each tier adds to the look: a shine, then a glow and swaying, then gleams and glints, then a rainbow.
  - **27 items,** all drawn in `tools/racoon-art/parts/racoon_C_closet.svg`, on their own sheet in the game (`assets/racoon/racoon_closet.svg`).
  - **Prices:** silver 20–40, violet 60–90, gold 150–250, diamond 450–500 (about 30 coins a day).
  - **Earned items:** 8, from "finish a lesson" to "collect all 40 stickers" (Rainbow scarf) and "finish all 5 worlds" (Crystal storybook).
  - **12 more items (2026-11-18)**, because the first set leaned toward what girls like: a builder's hard hat, pirate hat, captain's hat, hero mask, pilot goggles, explorer bandana, coach's whistle, rocket and dino pins, a basketball, a toy jeepney and a galaxy rocket. Now 39 items, 11 earned (D-026).
  - **Nothing random:** no real money, no timers; every way to get an item is shown first.
  - **Organised (2026-11-17):** each item is its own Inkscape file in `tools/racoon-art/closet/<slot folder>/`. The catalogue is `content/closet.json`, and the game has one sheet per slot (`assets/racoon/closet/`). Adding an item means a drawing, one catalogue line and a build, with no code ("How to" in `tools/racoon-art/closet/README.md`).
- **Still open:**
  - **The Laravel `SyncEventType` enum** listed only the lesson events, so `/api/sync` rejected the game's other events. **Fixed on branch `claude/elegant-dubinsky-5661ae` (commit `a958e29`, FR-11), not merged yet:** it adds the 13 missing types (`purchase`, `outfit`, `item_earned`, `sticker`, `goal`, `book`, `media`, `practice`, `word`, `placement`, `assessment`, `access`, `usage`), with a sync test that sends one of each and still rejects unknown types.
  - Try the item sizes and the effects with children; check the prices against real play. (The pins were replaced by clothes in D-029, issue 31.)
  - The manuscript's FR-07 description.

### 26. Freezes when a child taps (NFR-01) ✅ RESOLVED (2026-11-17)
- A profiling tour (`tools/perf/`) found freezes on the dev laptop:
  - a lesson's end: 237 ms, writing its events one at a time
  - Windows' read-aloud: 210 ms each time a line was cut off
  - the Closet: up to 144 ms
  - first visits to screens: 70–530 ms
- **Decision (D-025):** each cause is fixed.
  - On Windows, Racoon's read-aloud is never cut off mid-sentence within a screen (the user's choice): a new line waits for the current sentence to end. **Since 2026-11-18 a new question cuts it at once (D-032, issue 34).** Android and iPhone are unchanged. **Since 2026-11-17, leaving a screen stops his voice at once on every device** (the user's choice; about 0.2 s on Windows, during the screen change).
  - **Rapid taps (2026-11-17):** buttons ignore a repeat within 0.45 s and any tap within 0.2 s of another; Back ignores a repeat within 0.45 s; Racoon takes a tap only after he finishes his reaction and line.
  - Events are written in one go, buttons build their look once, screens load in the background, and Racoon's rig is lighter.
  - Worst frames are now 15–63 ms where they were 109–237 ms.
- **Still open:** a real 2 GB phone hasn't been measured; Library and Watch are render-heavy on phones; shader warm-up.

### 25. Devices: shared laptops with a mouse, and parents' phones 🟡 MOSTLY RESOLVED (2026-10-24)
- The thesis lists Android 8 / iOS 13 phones and the build so far targets a portrait Android phone. The user confirmed how the two classes will actually play:
  - **Advanced section** (Teacher Delgado, 36 learners): at school on **3 shared Windows laptops with a mouse**, about 12 children per laptop.
  - **Regular section** (Teacher Estremos, 26 learners): on **their parents' phones, Android and iPhone**.
- **To decide or build:**
  - A **Windows build** with mouse play: how the portrait 720×1280 layout sits on a landscape screen, and hover and drag with a mouse. *(Done, see below.)*
  - An **iOS build**: safe areas, Reduce Motion, edge-swipe back. *(Safe areas done.)*
  - **Android Back:** the game doesn't handle it, so Godot's default (`quit_on_go_back`) quits the game; a child pressing Back loses their place. *(Done.)*
  - **Notches and system bars:** no safe-area insets are applied yet. *(Done.)*
  - Where and when the regular section plays (at home, after school, with a parent nearby?).
- Recorded in `PRODUCT.md` (Users, Operating Context, Capabilities and Constraints).
- **Decision (2026-10-24, user chose real landscape layouts):**
  - **Laptops:** a landscape window draws the game on a 1280×720 canvas, and every screen lays out side by side (Racoon beside the task, wider grids, picture beside words). A task too big for the shorter screen shrinks just enough to fit. Buttons show the pointing hand and lift under the mouse, and the login code can be typed. The Windows build opens full screen.
  - **Phones:** stay portrait. Android Back and Escape do what the screen's ✕ or Home does (an open card first, "Stop now?" in a lesson), and leave the game only from Home, start, login and lock. Every screen keeps clear of notches and the home indicator.
  - Details: [D-023](../../brain/decisions/D-023%20Laptop%20layouts%20Back%20and%20safe%20areas.md).
- **Still open:**
  - The iOS build (needs a Mac with Xcode and an Apple developer account).
  - Whether the Windows laptops have Filipino and Bisaya text-to-speech voices.
  - Where and when the regular section plays.
  - Reduce Motion on iOS.


### 38. Holidays and the post-test switch 🟡
- DepEd holidays and suspensions aren't modelled: on a weekday holiday the schedule still says `class_lock`/`after_school`. **Decide:** an admin-managed holiday list (treated like a weekend), or leave it to the weekend toggle.
- `post_test_open` in `GET /api/config` is global (`POST_TEST_OPEN` in `.env`). If sections finish the evaluation at different times, it needs a per-section switch on the teacher's schedule page (the config would then need the student's token).

### 39. Gemini teacher report ✅ BUILT (2026-10-21)
- **Decision:** [D-018](../../brain/decisions/D-018%20Gemini%20teacher%20report.md). Gemini writes the report's two paragraphs; the lists and table stay rule-based. A queued job (`WriteAiReport`) writes it 10 minutes after a sync, for **consented learners only**, and stores it in `ai_reports` per set of numbers. Temperature 0.3, prompt `report-v1` with the student code and numbers only (no names, ages or dates). Each reply is checked against the facts (two paragraphs, length, no other learner code, every number in the facts, every needs-support sub-skill named); up to 3 calls, then the template. Every call is in `ai_logs` (FR-21) and the admin portal's **AI calls** tab.
- **Still to do:** set a real key and pinned model in `backend/.env` and run `php artisan report:write <code>` (not yet tested against the live API); a queue worker on the server; teachers rate sample reports (MLDLC Stage 4, accept at WM ≥ 4.0) and the prompt is revised by bumping `ReportPrompt::VERSION`; the consent form must say that anonymised scores go to Google.
- **Manuscript to update:** §3.4.3.3 Stage 5: the report is generated by a background job on the server after the session syncs, not by the client; Stage 6: `ai_logs` in PostgreSQL. Describe the output checks (numbers must match the input) as the guardrail.
- The server's P(L) matches the device's for choice items because the game sends `num_choices` in gameplay `response` payloads (added 2026-10-20; 0 for order-tiles items keeps the Table 3.5 guess), see [D-011](../../brain/decisions/D-011%20Server-side%20BKT%20replay.md).
