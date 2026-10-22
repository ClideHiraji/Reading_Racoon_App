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
- D-011 to D-014: teacher dashboard and admin portal (branch `claude/cranky-dhawan-dfb068`, PR #2)
- [[D-015 Home hub and Adventure-only time locks]]
- [[D-016 Thesis color palette]]
- [[D-017 Practice Library Watch and collections]]
- D-018: Gemini teacher report (renumbered on its branch); D-019: teacher content manifest (dashboard branch)
- [[D-020 Teacher content download in the game]]
- [[D-021 Second try hints and finished-only progress]]
- [[D-022 Full UI redesign]]

## Still open (from [[10-open-issues]])
- 🔴 Timeline: a 4-month evaluation doesn't fit before November. Re-plan with the adviser (issue 11).
- 🔴 Finish the database design (issue 8, [[04-data-model]]). The first 8 tables are built in `backend/`.
- 🟡 How 6-year-olds log in: interim login code on a kid keypad (D-010); picture PIN or QR card still possible (issue 9).
- 🟡 Where the Laravel + PostgreSQL server is hosted.
- 🟡 Re-check Grade 1 competencies with teachers (issue 13), and which Mother Tongue for levels 1–2 (issue 15).

## Devlog
- [[2026-10-17]]: thesis analyzed, knowledge base, decisions D-001 to D-005, GitHub, Godot project.
- [[2026-10-20]]: blueprint page, Obsidian + Graphify brain, first playable game slice (D-007), first Laravel backend slice (D-008).
- [[2026-10-21]]: hub wireframes approved; game-lobby home hub, diamond Play picker, Adventure-only time locks (D-015); thesis color palette with dark text (D-016); Practice, Library, Watch & Listen, stickers, word book and daily goals (D-017); teacher books and videos downloaded on Wi-Fi (D-020).
- [[2026-10-22]]: play-test fixes (D-021): two tries with a hint for every question, answer and explanation after the second, -1/+1 hearts, no CONTINUE taps, nothing saved from a stopped lesson, Adventure opens the map, pre/post-test results by skill then home. Then the full UI redesign from the canvas, except Racoon (D-022): Home with PLAY built in, one meaning per color, 96/120 px sizes, the animated earned star.

## Learnings
- [[BKT passes 0.95 after 3 correct]]
- [[Godot MCP cannot set Vector2]]
- [[Gitignore slash patterns are anchored]]
- [[Gemini subscription vs API credits]]
- [[Graphify does not index markdown]]
- [[Newer emoji render as boxes on Windows 10]]
- [[Godot headless tests need an import first]]
- [[Laravel timestamptz needs a UTC session]]
- [[Laravel rewrites JSON strings by default]]
- [[Composer picks Laravel 12 on PHP 8.2]]
- [[Laravel API guests need a null redirect]]
- [[Reset a lost postgres password]]
- [[Godot containers reset child rotation]]
- [[GDScript helper names can override engine callbacks]]
- [[Godot clip_text labels collapse in boxes]]
- [[Autoload names fail in static helpers under -s tests]]
- [[Python write_text makes CRLF on Windows]]
- [[Headless test runs hide GDScript warnings]]
- [[Godot cannot play animated SVG]]
- [[Code-built unique nodes need an owner]]
- [[Godot buttons pin the icon to the edge]]

## Links
- Visual blueprint (private page): https://claude.ai/artifact/TPcwMuVYMvR9gx8ypBMYB9
- GitHub: https://github.com/ClideHiraji/Reading_Racoon_App
- Graphify workspace: `king-s-workspace`, repo `ClideHiraji/Reading_Racoon_App`
