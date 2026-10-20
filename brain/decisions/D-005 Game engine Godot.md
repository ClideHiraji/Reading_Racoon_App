---
type: decision
status: decided
date: 2026-10-17
issue: 19
graphify: submitted
tags: [decision, godot, client]
---

# D-005 Game engine: Godot 4.7

**Decision:** **Godot 4.7 + GDScript**, Compatibility renderer, **portrait 720×1280**, Android APK first. The project is in `reading-racoon/` and the main scene is `reading-racoon/scenes/main.tscn`.

**Updated 2026-10-20:** moved from `game/` to `reading-racoon/`, and from landscape 1280×720 to portrait for the Duolingo-style vertical path ([[D-007 UI direction Duolingo-style path]]).

**Why**
- The app is 2D and UI-heavy, with drag-and-drop puzzles, audio and text. It targets cheap Android phones (2 GB RAM).
- Godot is lighter than Unity and has built-in drag-and-drop UI and TTS.
- Scenes are text files, and the Godot MCP connection lets Claude create, edit and run scenes directly.

**Trade-offs:** a smaller asset store and fewer tutorials than Unity, and weaker 3D tools. The raccoon becomes a 2D animated character unless 3D is kept.

**To do:** tell the adviser, and update thesis Table 3.4, §3.4.3.1–3.4.3.3, Table 3.8 and §3.4.5.

**Rejected:** Unity 6 (the thesis default; still installed).

Details: [[03-architecture]], [[10-open-issues]] issue 19, [[Godot MCP cannot set Vector2]].
