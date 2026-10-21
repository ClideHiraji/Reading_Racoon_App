---
type: learning
date: 2026-10-21
status: confirmed
tags: [learning, godot, testing]
---

# Headless test runs hide GDScript warnings

`godot --headless -s res://tests/run_tests.gd` prints no GDScript warnings (shadowed names, integer division, a `@tool` base class without `@tool`...). They appear only when the debugger is on, as when the game runs from the editor, where the Debugger's Errors tab lists them. So the tests passed while the user saw a list of "errors".

**Check:** add `-d` and pipe `c` in case the debugger stops on an error:

```bash
yes c | "C:\Program Files\Godot\Godot.exe" -d --headless --path reading-racoon -s res://tests/ui_smoke.gd -- --profile=smoke --fresh
```

The smoke test only loads the scripts it reaches; to see every script's warnings, load every `.gd` and `.tscn` file the same way.

**Common causes here:** local variables named `name`, `pressed`, `len`, `round`, `mini` or `get` (they shadow a Node property, a BaseButton signal or a built-in function), and a `var` in an inner block that a later `var` of the same name in the outer block shadows.

Seen while fixing warnings after [[D-020 Teacher content download in the game]].
