---
type: learning
date: 2026-11-19
status: confirmed
tags: [learning, godot, ui]
---

# Godot autowrap labels collapse in grids

What happened: Watch & Listen's Videos chip showed "Nothing here yet. Your teacher can add videos." as one letter per line down the left edge. The message was a `Label` with `autowrap_mode` on (every `Kit.label` has it), added straight to the list's `GridContainer`. An autowrapped label reports a minimum width of 1 px, and a grid column is only as wide as its cells ask unless one of them expands. The song and video cards had `SIZE_EXPAND_FILL`; the message didn't, so it got 1 px and wrapped after every character (1 × 1,677 px). It showed only on the Videos chip, the one kind the bundled content has none of, so the tests never reached it.

**So:**
- Give every cell of a grid or box `size_flags_horizontal = SIZE_EXPAND_FILL`, the "nothing here" message too. Set it in one loop over all cells, so a new kind of cell can't miss it.
- When the message stands alone in a multi-column grid, drop to one column, or it gets one column's share and sits off-centre.
- A smoke check that every cell is at least its column's width catches this headless (`tests/ui_smoke.gd`, Watch & Listen part).
- My Word Book dodges the same trap with a fixed `custom_minimum_size = Vector2(600, 0)` on its empty message.

Related: [[Godot clip_text labels collapse in boxes]] (the same 0-width minimum, from `clip_text`), [[D-017 Practice Library Watch and collections]], [[D-023 Laptop layouts Back and safe areas]].
