---
type: learning
date: 2026-10-20
tags: [learning, godot, testing]
---

# Godot headless tests need an import first

What happened: tests run with `Godot.exe --headless --path reading-racoon -s res://tests/run_tests.gd`. Scripts refer to each other by `class_name`, and Godot only knows those names after it has scanned the project (`.godot/global_script_class_cache.cfg`, which git ignores).

**So:** on a fresh clone, or after adding a new `class_name`, run `Godot.exe --headless --path reading-racoon --import` once before the tests. Also, JSON round-trips floats with last-bit differences, so compare saved numbers with a tolerance.

Related: [[D-005 Game engine Godot]], [[Godot MCP cannot set Vector2]]
