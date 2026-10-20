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
- [[D-010 Server-side BKT replay]]
- [[D-011 Teacher web dashboard]]
- [[D-012 Hidden admin portal]]
- [[D-013 Time-restricted access rules]]

## Still open (from [[10-open-issues]])
- 🔴 Timeline: a 4-month evaluation doesn't fit before November. Re-plan with the adviser (issue 11).
- 🔴 Finish the database design (issue 8, [[04-data-model]]). 14 tables are built in `backend/`; content, `bkt_parameters` and AI logs are left.
- 🟡 How 6-year-olds log in: picture PIN, QR card or tap your name (issue 9).
- 🟡 Where the Laravel + PostgreSQL server is hosted.
- 🟡 Re-check Grade 1 competencies with teachers (issue 13), and which Mother Tongue for levels 1–2 (issue 15).

## Devlog
- [[2026-10-17]]: thesis analyzed, knowledge base, decisions D-001 to D-005, GitHub, Godot project.
- [[2026-10-20]]: blueprint page, Obsidian + Graphify brain, first playable game slice (D-007), first Laravel backend slice (D-008), server BKT replay, teacher dashboard and hidden admin portal (D-010 to D-013).

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
- [[Blade inline php swallows a later php block]]
- [[migrate fresh keeps PostgreSQL functions]]
- [[A hidden route needs a catch-all against 405]]

## Links
- Visual blueprint (private page): https://claude.ai/artifact/TPcwMuVYMvR9gx8ypBMYB9
- GitHub: https://github.com/ClideHiraji/Reading_Racoon_App
- Graphify workspace: `king-s-workspace`, repo `ClideHiraji/Reading_Racoon_App`
