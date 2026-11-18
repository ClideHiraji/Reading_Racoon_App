---
type: learning
date: 2026-10-26
status: confirmed
tags: [learning, godot, editor]
---

# The embedded game window can freeze the Godot editor

On 2026-10-26 the editor (Godot 4.7.2, Windows 10) stopped responding while the game ran **embedded in the editor's Game tab**. Godot starts the game with `--wid <editor window>` and `--editor-pid`, and glues its window into the editor.

**How it showed**
- The editor was "Not responding" at 1.3 GB, but at **0% CPU**. The game process was also at 0% CPU, and every thread in both processes was waiting. That's a deadlock, not heavy work.
- The game's log was quiet, and no project file had long lines, so neither [[Godot editor freezes on very long lines]] nor output spam was the cause.
- **Closing only the game process brought the editor back within seconds**, with no restart and no lost work.

**Fix:** run the game in its own window. In the editor's **Game** tab, turn off **Embed Game on Next Play**. The editor setting is `run/window_placement/game_embed_mode`.

**If it happens again before that:** don't kill the editor. In Task Manager, end the `Godot.exe` that was started with `--editor-pid` (the game); the editor recovers. To find it from a shell:
`Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" | Select ProcessId, CommandLine`

**Telling freezes apart**

| Symptom | Likely cause |
|---|---|
| Editor at 100% CPU right at start | A huge file in the reopen list ([[Godot editor freezes on very long lines]]) |
| Editor freezes while another tool runs Godot on the same folder | [[Two Godot editors on one project freeze the editor]] |
| Editor and game both at 0% CPU during F5 | This note: the embedded game window |
