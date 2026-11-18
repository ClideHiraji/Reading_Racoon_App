---
type: learning
date: 2026-10-24
status: confirmed
tags: [learning, godot, tooling, sessions]
---

# Two Godot editors on one project freeze the editor

`--import`, `--editor`, `--export` and the Godot MCP's scene and uid tools load the project as a second editor. Run while the user has the Godot editor open on the same folder, they rewrite the shared `.godot/` caches (`global_script_class_cache.cfg`, `uid_cache.bin`, imports) and `.import` files, the open editor rescans, and it stops responding. (Headless `-s` test and screenshot runs play the game rather than open the editor; they are less harmful but still best kept on a copy.) On 2026-10-24 a design session's `--import` spun at 100% CPU for over 3.5 minutes next to the open editor (9 to 14 s on its own), and the editor reopened in recovery mode.

**Rule:** while the user's editor is open, run Godot only on a separate copy of the project (a git worktree, or `reading-racoon/` copied without `.godot/` to the scratchpad), or ask the user to close the editor first. Parallel sessions should not share the main checkout for Godot runs.

**Enforced:** a PreToolUse hook in `.claude/settings.local.json` runs `.claude/hooks/godot_editor_guard.py` before every Bash, PowerShell and Godot MCP call. It denies `--import`, `--editor`, `-e`, `--export*` and `--recovery-mode` runs, and the MCP scene tools, on the main `reading-racoon/` while a Godot editor window is open on it, and tells the session to use a scratch copy. Paths through shell variables (scratch copies), `-s` runs and game runs pass; a guard error lets the call through. Set `GODOT_GUARD_DEBUG=1` to see its errors.

**Also:**
- A game started with F5 keeps running if its editor dies; look for a `Godot.exe` with `--editor-pid` of an editor that no longer exists, and close it.
- The first `--import` of a fresh copy can segfault while fonts import and `theme.tres` loads; running it again works.
- Copies keep the project's name, so they share `user://` (`%APPDATA%\Godot\app_userdata\Reading Racoon`) with the real project and with each other. Two sessions running the unit tests at once collide on the event-queue files (`test_queue_*` fail); run them one at a time, or rerun.

See also [[Godot editor freezes on very long lines]], [[Godot headless tests need an import first]], [[Headless test runs hide GDScript warnings]].
