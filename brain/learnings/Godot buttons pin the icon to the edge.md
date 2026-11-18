---
type: learning
date: 2026-10-22
status: confirmed
tags: [learning, godot, ui]
graphify: submitted
---

# Godot buttons pin the icon to the edge

A Godot 4 `Button` with an icon and centered text draws the icon at the left content margin and centers the text in the space left over, so "▶ START" shows as "▶ ······ START". There is no setting to keep them together.

Widening the left content margin until the pair is centered doesn't work: the margin then depends on the button's width, which pins the button's minimum width to its current width, so it can never shrink again.

**What works (`ui/chunky_button.gd`):** when a button has text and an icon, take the icon out of Button's slot (`icon = null`), add the icon's width plus the gap to the left content margin (the text then centers as if the icon were there), and draw the icon by hand in `_draw()` just left of the text. The minimum width stays honest: margins + icon + text. Make the icon side 1 px tighter and the text side 1 px looser; that looks centered.

Also from the same pass: `get_meta("key", null)` still reports an error when the key is missing, because a `null` default counts as no default. Check `has_meta()` first.

Seen in the polish pass after [[D-022 Full UI redesign]].
