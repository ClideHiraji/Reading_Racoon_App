---
type: learning
date: 2026-10-20
tags: [learning, godot, gdscript]
---

# GDScript helper names can override engine callbacks

What happened: the Grown-ups screen had a helper `func _input(value, hint) -> LineEdit`. `_input` is a Node callback (`_input(event)`), so Godot refused to load the whole script ("function signature doesn't match the parent"). The screen never opened, and only a scene-loading test caught it.

**So:**
- Don't start helper names with an underscore plus an engine callback name (`_input`, `_process`, `_draw`, `_ready`, `_notification`...). Use names like `_line_edit`.
- A label that wraps (`autowrap_mode`) inside an HBox shows one letter per line unless it has `SIZE_EXPAND_FILL`.
- A GDScript `:=` on a value typed as Variant (a Dictionary `get`, an untyped `session`) is a parse error in this project. Give the type explicitly.
- Every new screen gets a line in `tests/ui_smoke.gd` that loads it.

Related: [[Godot containers reset child rotation]], [[Godot headless tests need an import first]]
