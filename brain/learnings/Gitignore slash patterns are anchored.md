---
type: learning
date: 2026-10-17
tags: [learning, git]
---

# A .gitignore pattern containing a slash only matches from the repo root

`.obsidian/workspace*.json` did **not** ignore `Reading Racoon App/.obsidian/workspace.json`. A slash in the middle of a pattern anchors it to the folder the `.gitignore` is in.

**Fix:** prefix `**/` to match at any depth, e.g. `**/.obsidian/workspace*.json`. Likewise, Godot's Android build folder is ignored as `game/android/build/`, not `/android/build/`.

**Check:** run `git status --short` before the first commit to catch files that slipped through.
