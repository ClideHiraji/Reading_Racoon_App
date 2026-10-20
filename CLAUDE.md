# Reading Racoon App

Capstone thesis project (Caraga State University, BSIT, due Nov 2026): a Godot 4 mobile game (`game/`, GDScript) that adaptively assesses Grade 1 reading comprehension with Bayesian Knowledge Tracing, an LLM-written teacher report, a raccoon companion, a teacher dashboard, and an admin portal.

**Read `docs/knowledge/README.md` before designing or building anything.** It is the distilled spec from the thesis manuscript. Check `docs/knowledge/10-open-issues.md` first: the thesis contradicts itself in several places (e.g., the AI model and the BKT level progression). Don't silently pick one. Record decisions there.

**Backend is decided: custom-coded Laravel (PHP 8.x) + PostgreSQL 16+ + Sanctum. No Firebase.** Custom-coded is required by the professor; PostgreSQL was the team's choice. Treat any "Firebase" or "MySQL" in the thesis as this API + DB. **The LLM is the Google Gemini API (Flash-class), called only from Laravel** (see `docs/knowledge/08-ai-integration.md`). Offline sync, remote config (`/api/config`), and the LLM proxy are built in Laravel. See `docs/knowledge/03-architecture.md`.

**Game engine is decided: Godot 4.7 + GDScript** (the thesis says Unity; see open issue 19). Use the Godot MCP tools to create scenes, run the project and read debug output. Prefer editing `.tscn` text directly when a tool can't set a property (e.g., Vector2). Project root: `game/`.

Reference requirement IDs (`FR-xx`, `NFR-xx`) from `docs/knowledge/02-requirements.md` in commits and code comments.

## Project brain (Obsidian + Graphify)

The repo root is an Obsidian vault. `docs/knowledge/` is the spec; `brain/` holds decisions, devlog and learnings (`brain/Home.md` indexes them). Graphify memory on `ClideHiraji/Reading_Racoon_App` holds one-fact copies for agents.

- **Session start:** read `brain/Home.md` and the newest `brain/devlog/` note; run Graphify `recall` for the topic at hand.
- **New decision:** add `brain/decisions/D-00X <name>.md` (template `brain/templates/Decision.md`), update `docs/knowledge/10-open-issues.md`, save a one-fact Graphify `remember`, then set `graphify: submitted`.
- **Reusable lesson:** add `brain/learnings/<lesson>.md` and a Graphify `remember`.
- **Session end:** write or append `brain/devlog/YYYY-MM-DD.md` (Done / Learned / Next), then offer to commit and push.
- Link notes with `[[wikilinks]]` by file name; frontmatter has `type`, `date`, `status`, `tags`.

<!-- graphify-rules-start (managed by `graphify init`) -->
## Use Graphify before grep

This repository is indexed by Graphify: a code graph over its call, dependency, and test structure, exposed through a connected Graphify MCP server. Before reaching for grep or reading files, use the Graphify tools your MCP client lists (their exact names and descriptions are in the server's tool list) for what the graph knows and a text search does not:

- find where a symbol, function, or class is defined (instead of grepping for it)
- understand how something works, or where a behavior is handled
- find who calls a function, or what it calls
- see what a change affects (its blast radius) and which tests cover it
- map a file's dependencies and dependents

Fall back to grep or file reads only for what the graph does not model: literal string or comment matches, non-indexed files, or reading a file you have already located. If no Graphify tools are listed, check the MCP server connection.
<!-- graphify-rules-end -->
