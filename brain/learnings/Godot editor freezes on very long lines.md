---
type: learning
date: 2026-10-24
status: confirmed
tags: [learning, godot, editor, json]
---

# Godot editor freezes on very long lines

Godot's script editor reopens the files that were open last time (`.godot/editor/editor_layout.cfg`, `open_scripts`). `assets/anim/lottie/star.json` was minified onto one 205,200-character line; once it had been opened, every editor start spun its main thread for minutes and Windows showed "Not responding". Recovery mode and a fresh copy were fine because they don't reopen it.

Reproduced on a scratch copy with the user's reopen list: hung for the full 2 minutes; without the Lottie files in the list, opened in 19 s; with the files reformatted (one key per line, short number lists inline, longest line 209 characters), opened in 18 s even with `star.json` open. The game loads them with `JSON.parse_string`, so the data is unchanged (checked in Python; 4,031 unit checks and the smoke test pass).

**Rule:** keep JSON and other text in the project on short lines; indent anything a tool writes (Lottie exports, content). If the editor hangs at start, look at `open_scripts` in `editor_layout.cfg` for a huge file and remove it while Godot is closed.

Found 2026-10-24 alongside [[Two Godot editors on one project freeze the editor]].
