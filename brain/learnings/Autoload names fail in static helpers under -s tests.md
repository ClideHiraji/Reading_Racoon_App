---
type: learning
date: 2026-10-21
status: confirmed
tags: [learning, godot, testing]
---

# Autoload names fail in static helpers under -s tests

A `class_name` script that names an autoload (`GameState`, `Speech`) fails to compile with "Identifier not found" when a `-s` test script (`extends SceneTree`) loads it, because the test compiles before the autoloads exist. The failure is cached, so every scene that uses the class breaks too.

**Fix:** in shared `class_name` helpers, look autoloads up through the tree (`node.get_node_or_null("/root/GameState")`), as `Raccoon` and `Kit` do. In test scripts, call an autoload's static functions through `preload("res://scripts/autoload/speech.gd")`, but only if that script itself names no other autoload (preloading `sync.gd`, which uses `GameState`, fails the same way): keep testable helpers in pure `scripts/core/` classes instead. Scene scripts (not `class_name`) can keep using the autoload names.

Seen while building [[D-017 Practice Library Watch and collections]].
