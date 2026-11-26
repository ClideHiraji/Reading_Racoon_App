---
type: learning
date: 2026-11-26
status: confirmed
graphify: submitted
tags: [learning, godot, gdscript]
---

# Godot turns process back on at ready

A node whose script defines `_process` has processing switched on when it becomes ready (`NOTIFICATION_READY`), even if `_init` called `set_process(false)`. The new word wheel (`scenes/tasks/spin_wheel.gd`) meant to run `_process` only while flung. Instead it ran from the first frame with no spin, "settled" on the letter at the pointer and answered before the child touched it.

**Fix:** guard `_process` itself: when idle, `set_process(false)` and return. Calling `set_process(false)` in `_ready` works as well, but the guard also covers any later idle frame.

**Caught by:** the `ui_smoke` fling check, which saw a locked wheel at its opening angle (its intro tween had been killed by the early settle).

Found in [[2026-11-26]].
