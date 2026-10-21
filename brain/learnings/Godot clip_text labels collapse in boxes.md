---
type: learning
date: 2026-10-21
status: confirmed
tags: [learning, godot, ui]
---

# Godot clip_text labels collapse in boxes

A `Label` with `clip_text = true` reports a minimum width of 0. Inside an `HBoxContainer` (or any box) that doesn't stretch it, the label gets 0 px and its text vanishes, with no error.

**Fix:** leave `clip_text` off and keep the text short enough, or give the label `size_flags_horizontal = SIZE_EXPAND_FILL` (or a `custom_minimum_size`) so the box hands it real width. `text_overrun_behavior` (ellipsis) has the same catch.

Seen on the hub's PLAY button: "Opens 7:30 AM" disappeared until `clip_text` was removed ([[D-015 Home hub and Adventure-only time locks]]).
