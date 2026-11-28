---
type: home
tags: [home]
---

# Reading Racoon: project brain

Start here. This vault holds the **spec** (what the system must do), the **decisions** we've made, the **devlog** of progress, and the **learnings** worth keeping.

## Spec: docs/knowledge
The distilled thesis requirements. Read before building anything.

- [[README|Knowledge base index]]
- [[01-project-overview]] · [[02-requirements]] · [[03-architecture]] · [[04-data-model]]
- [[05-bkt-engine]] · [[06-game-design]] · [[07-curriculum-content]] · [[08-ai-integration]]
- [[09-evaluation-deployment]] · [[10-open-issues]] · [[glossary]]

## Decisions
Every decision, with status and whether it's saved to Graphify: ![[Decisions.base]]

- [[D-001 Backend Laravel + PostgreSQL]]
- [[D-002 AI model Gemini]]
- [[D-003 BKT level progression]]
- [[D-004 Heart Recovery rules]]
- [[D-005 Game engine Godot]]
- [[D-006 Project brain workflow]]
- [[D-007 UI direction Duolingo-style path]]
- [[D-008 Offline sync contract]]
- [[D-009 Art direction Butuan storybook]]
- [[D-010 Student login and automatic sync]]
- [[D-011 Server-side BKT replay]]
- [[D-012 Teacher web dashboard]]
- [[D-013 Hidden admin portal]]
- [[D-014 Time-restricted access rules]]
- [[D-015 Home hub and Adventure-only time locks]]
- [[D-016 Thesis color palette]]
- [[D-017 Practice Library Watch and collections]]
- [[D-018 Gemini teacher report]]
- [[D-019 Teacher content manifest]]
- [[D-020 Teacher content download in the game]]
- [[D-021 Second try hints and finished-only progress]]
- [[D-022 Full UI redesign]]
- [[D-023 Laptop layouts Back and safe areas]]
- [[D-024 Racoon redesign]]
- [[D-025 Performance no freezes]]
- [[D-026 Closet tiers and item art]]
- [[D-027 Full-colour pictures]]
- [[D-028 Paper-cut UI shapes]]
- [[D-029 Clothes and pets in the Closet]]
- [[D-030 Stiff items in his paws]]
- [[D-031 Windblown scarves and the Star halo]]
- [[D-032 A new question stops the voice]]
- [[D-033 Buddies Roco and Rina and talk language]]
- D-034: sounds (planned, not built)
- [[D-035 Recorded buddy voices]]
- [[D-036 Internet hosting from the home laptop]]
- [[D-037 Teacher dashboard needs-help first]]
- [[D-038 Dashboard trust fixes]]
- [[D-039 Dashboard on a phone]]
- [[D-040 Full screen for teacher videos]]
- [[D-041 Recorded voices only]]
- [[D-042 Settings card]]
- [[D-043 Practice games come from the adventure]]
- [[D-044 Animated opening and app icon]]
- [[D-045 Lesson language follows MATATAG]]
- [[D-046 Four team laptops and 30 learners]]
- [[D-050 Save file copy on the server]]

## Still open (from [[10-open-issues]])
- 🔴 **Before the final release: delete the developer menu** (issue 30). It's debug-build-only, but it must go: `reading-racoon/ui/dev_menu.gd` (and its `.uid`), its lines in `scripts/autoload/screen.gd`, and its check at the end of `tests/ui_smoke.gd`.
- 🔴 Timeline: a 4-month evaluation doesn't fit before November. Re-plan with the adviser (issue 11).
- 🔴 Finish the database design (issue 8, [[04-data-model]]). 16 tables are built in `backend/` (incl. `ai_logs`, `ai_reports`); content and `bkt_parameters` are left.
- 🟡 How 6-year-olds log in: interim login code on a kid keypad (D-010); picture PIN or QR card still possible (issue 9).
- 🟡 Hosting is decided (D-036, issue 40): the user still sets up the domain, Cloudflare Tunnel, Apache with OPcache, startup tasks and off-site backups (`docs/deploy/home-server.md`).
- 🟡 Re-check Grade 1 competencies with teachers (issue 13), and which Mother Tongue for levels 1–2 (issue 15).

## Devlog
- [[2026-10-17]]: thesis analyzed, knowledge base, decisions D-001 to D-005, GitHub, Godot project.
- [[2026-10-20]]: blueprint page, Obsidian + Graphify brain, first playable game slice (D-007), first Laravel backend slice (D-008), server BKT replay, teacher dashboard and hidden admin portal (D-011 to D-014).
- [[2026-10-21]]: hub wireframes approved; game-lobby home hub, diamond Play picker, Adventure-only time locks (D-015); thesis color palette with dark text (D-016); Practice, Library, Watch & Listen, stickers, word book and daily goals (D-017); teacher books and videos downloaded on Wi-Fi (D-020); Gemini teacher report with output checks and `ai_logs` (D-018).
- [[2026-10-22]]: play-test fixes (D-021): two tries with a hint for every question, answer and explanation after the second, -1/+1 hearts, no CONTINUE taps, nothing saved from a stopped lesson, Adventure opens the map, pre/post-test results by skill then home. Then the full UI redesign from the canvas, except Racoon (D-022): Home with PLAY built in, one meaning per color, 96/120 px sizes, the animated earned star.
- [[2026-10-24]]: product record (`PRODUCT.md`); the editor freezes fixed (short Lottie lines, a guard hook); laptop and phone layouts started (D-023).
- [[2026-10-26]]: laptop and phone layouts finished (D-023); the star baked; Racoon drawn as moving layers and the main screens warmed up; Racoon redesign, option C (D-024): its 3D model, refined in a seven-round loop, and a 2D motion demo in which the drawing turns, points and walks up to the screen.
- [[2026-11-16]]: the user redrew Racoon in Inkscape (bean body, no scarf; arms at his sides after a second edit); the motion demo and parts board are now built from that drawing, and the River scarf and open book are drawn as Closet items you can try on; a second board shows his animations for the game's lesson moments; then the new Racoon went into the game: the rig ported to `raccoon.gd`, his moments in the lesson, and the book in a new Closet slot (D-024).
- [[2026-11-17]]: Racoon's arm outline joins his body's, and a raised paw never slips behind his head (D-024; canvas version 43). Then Racoon became a Godot scene: one node per part of the drawing, and his 21 moves as AnimationPlayer animations you can edit in the editor (D-024). Then the freezes were found and fixed (D-025): a lesson's end, Windows read-aloud cut-offs, the Closet and first visits. Then his 27 part files became one texture sheet, and he got 8 new moves he plays on his own on Home, the start screen and the Closet (walking about, hops, a big jump, a dance...), fitted to the box he stands in (D-024). Then the Closet got five tiers, copper to diamond, with 27 drawn items on their own sheet, effects that grow with the tier, and items earned by reading (D-026).
- [[2026-11-18]]: the pictures redrawn in one soft storybook style, judged on the canvas (Icons page), then put in the game: full-colour pictures for words, stickers, Home tiles and practice games (D-027). In the game the glossy sticker look was out of place, so the 60 pictures were redrawn as flat paper cut-outs on crisp shadows, like the rest of the game. A read-along no longer moves its screen on once the child has left it. Then the game files nothing uses were cleaned out: 24 old silhouettes, a font, the old Home tile and two empty scenes; the team's animated SVGs moved to `tools/team-animations/`. Then the UI was cut from paper (D-028): hand-cut edges on cards and buttons (circles stay round), stitches on the special pieces, tilted Home tiles, washi tape, paper confetti and a crayon underline. Then the UI's own icons went to paper colours: a gold paper coin everywhere, a sticker and a word book on the Home bar, and the sticker and Closet tabs. Then a debug-only developer menu (delete before release, issue 30), and 12 more Closet items with sports, builder, explorer and space themes (39 in all, D-026).
- [[2026-11-19]]: quality areas (CAP, ACID, ISO/IEC 25010) mapped to tools; seven skills and plugins reviewed, then installed (Google-SRE skills, event-store design, GDPR checklist, webapp-testing with Playwright, four Trail of Bits security plugins, GodotPrompter, Laravel Boost with a project `.mcp.json`); the 9 advisories `composer audit` found are cleared by patch updates (Laravel 12.73.0, Symfony 7.4.23; 34 tests pass); the gaps between the game and the server listed.

- [[2026-11-20]]: the teacher dashboard and admin portal critiqued (20/40) and redesigned (D-037): needs-help first grouped by child, plain states with P(L) on demand, the class on the reading map, a filterable learner list, risky actions on the learner page with confirmations, server-drawn charts (no Chart.js or CDN), WCAG AA contrast and focus, phone layouts; 184 tests pass.

- [[2026-11-24]]: a second critique of the dashboard (23/40) listed about 60 gaps from wording to whole flows; then the trust fixes (D-038): Slipping, two help groups with Close all, last-synced times, branded error pages, busy-locked forms, working map links, accessibility and print; 188 tests pass.
- [[2026-11-26]]: the recorded-voice branch merged into main's line, then device TTS removed (D-041), Settings (D-042), Practice games in the adventure (D-043), the new-day card shown once, drag that lifts the tile out, and a real spinning word wheel. Before that: a full bug hunt of the game, then a layout audit at 7 screen sizes (new `tests/layout_audit.gd`) that found a laptop crash in FitBox, the touch-scroll bug (buttons block drag-scroll) and about 12 layout bugs, all fixed the same day with tests: headless tests clean (5,161 checks, smoke, all 126 scripts load), then play-tests on the phone (adb) and the laptop (window messages) and a 3,200-action monkey test with no errors or leaks. Found: the committed project cannot export for Android (ETC2), answer pictures turn into black silhouettes on result cards, Practice tiles overflow on laptops, a tripled Closet title line; the laptop has no Filipino or Bisaya voice.

- [[2026-11-25]]: a phone critique of the dashboard (24/40); then the phone fixes (D-039): compact learner cards (the class page went from 17 to 9 screens), Mark resolved, Close all and consent in place with Undo, an admin Menu button, landscape and 360 px layouts, 44 px targets and 16 px fields; 190 tests pass.
- [[2026-11-19]]: recorded buddy voices (D-035): Gemini's Zeno and Cleo for Roco and Rina, in a lively style, on the AI Studio free tier, with "reader" in place of names; the batch cutter now aligns by sentence length; Rina's Closet tab says "In her paws"; the Watch & Listen videos fixed (D-040).
- [[2026-11-20]]: the recorded voices finished: all 1,465 lines in the game (12.0 MB); Rina's last short lines recorded among lines she already had.

## Learnings
- [[Judge new art inside the game, not on a board]]
- [[BKT passes 0.95 after 3 correct]]
- [[Godot MCP cannot set Vector2]]
- [[Gitignore slash patterns are anchored]]
- [[Gemini subscription vs API credits]]
- [[Graphify does not index markdown]]
- [[Newer emoji render as boxes on Windows 10]]
- [[Godot headless tests need an import first]]
- [[Laravel timestamptz needs a UTC session]]
- [[Laravel rewrites JSON strings by default]]
- [[Vet the ref a plugin marketplace installs]]
- [[Composer picks Laravel 12 on PHP 8.2]]
- [[Laravel API guests need a null redirect]]
- [[Reset a lost postgres password]]
- [[Godot containers reset child rotation]]
- [[GDScript helper names can override engine callbacks]]
- [[Godot clip_text labels collapse in boxes]]
- [[Autoload names fail in static helpers under -s tests]]
- [[Python write_text makes CRLF on Windows]]
- [[Headless test runs hide GDScript warnings]]
- [[Drive a Godot window by messages, not the mouse]]
- [[Buttons in a scroll list must pass the touch]]
- [[A fit-to-box scale can flip-flop with wrapped text]]
- [[Two Godot editors on one project freeze the editor]]
- [[Godot editor freezes on very long lines]]
- [[Godot cannot play animated SVG]]
- [[Code-built unique nodes need an owner]]
- [[Godot buttons pin the icon to the edge]]
- [[Godot can play Lottie with a small player]]
- [[Embedded game window freezes the editor]]
- [[Godot boxes can't change orientation]]
- [[Animate drawn shapes by moving a layer, not redrawing]]
- [[Blender opens files in Solid shading]]
- [[Compare 3D renders with 2D art in one shared frame]]
- [[Turn a flat 2D character by putting its parts on round shapes]]
- [[Headless Chrome runs animation frames only once]]
- [[Build a puppet from the artist's file, not from code]]
- [[Move a vector puppet in Godot with SVG textures on meshes]]
- [[Record coded tweens as AnimationPlayer keyframes]]
- [[Windows text-to-speech blocks when it stops]]
- [[Pack a Godot puppet's SVG parts onto one sheet]]
- [[A saved Godot scene keeps a sheet's old UVs]]
- [[Godot canvas COLOR already holds the texture]]
- [[Git Bash sed -i drops CRLF]]
- [[Laravel needs config cache under threaded Apache]]
- [[PHP built-in server drops connections on Windows]]
- [[Blade inline php swallows a later php block]]
- [[migrate fresh keeps PostgreSQL functions]]
- [[A hidden route needs a catch-all against 405]]
- [[Dotenv overwrites what it loaded itself]]
- [[A unique delayed job debounces syncs]]
- [[Cut TTS batches by aligning sentence lengths]]

## Links
- Visual blueprint (private page): https://claude.ai/artifact/TPcwMuVYMvR9gx8ypBMYB9
- GitHub: https://github.com/ClideHiraji/Reading_Racoon_App
- Graphify workspace: `king-s-workspace`, repo `ClideHiraji/Reading_Racoon_App`
