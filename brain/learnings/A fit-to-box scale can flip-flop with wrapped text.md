---
type: learning
date: 2026-11-26
status: confirmed
graphify: submitted
tags: [learning, godot, ui, crash]
---

# A fit-to-box scale can flip-flop with wrapped text

`ui/fit_box.gd` scales a lesson's task down to fit its box. It set the task's scale from its minimum size, then its size to `box / scale`. A task with wrapped words is shorter when it is wider, so on a 1366x768 laptop a story question's cards needed 564 px at scale 0.98 (895 px wide) and 452 px at scale 0.78 (1117 px wide). Each sort picked the other scale, which re-queued the sort, forever within one frame: the deferred-call queue overflowed ("Object was deleted while awaiting a callback" x178) and Godot crashed with signal 11 at `fit_box.gd:23`. It happened in 2 of 3 audit runs, only on laptops.

**Fix:** remember a scale the child grew back to that didn't hold (it had to shrink again), and never grow to it again while the box keeps its size (`FitBox.next_scale`, with a ceiling in the child's `fit_state` meta, cleared on resize). Shrinking is always allowed, so a first guess made before the task had its real width still grows back.

**Two traps on the way:**
- A plain "only ever shrink" rule fixes the loop but traps the first guess: lc3-04 stuck at 0.66 because the first sort measured the task before its own layout.
- `Vector2` stores float32: a scale read back from `scale.x` is never exactly the float64 you set, so compare with a tolerance (`EPS := 0.001`), or a "seen it" check never matches and the loop comes back.

**Testing it:** off the scene tree (as in `run_tests.gd`, whose tests run in `_init`) a Control's minimum size is cached and never refreshed, so a node-based test passes even with the bug. Test the scale rule as a pure function instead (`test_fit_box_settles`), and replay the real items in a window.

Found in the bug hunt of [[2026-11-26]].
