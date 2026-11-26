---
type: learning
date: 2026-11-26
status: confirmed
graphify: submitted
tags: [learning, godot, ui, touch]
---

# Buttons in a scroll list must pass the touch

On a phone, a drag that started on a Library, Practice, Watch, Word Book or Closet card didn't scroll the list; only a drag from the gaps between cards did. Godot 4.7's buttons default to `MOUSE_FILTER_STOP`, so the press never reaches the `ScrollContainer`.

**Fix (Godot 4.7.2 source, `scroll_container.cpp` and `base_button.cpp`):** set the button to `MOUSE_FILTER_PASS`. The press then reaches the list as well; once the finger moves past the list's deadzone, the list sends `NOTIFICATION_SCROLL_BEGIN`, which cancels the button's press, so a drag never opens the card. `Screen._on_node_added` now does this for every button inside a `ScrollContainer` (the learning path's `world_trail.gd` already did it for its nodes).

**The catch:** a tap the button takes calls `accept_event()` on the release, so the list never sees the finger lift and still thinks it is dragging. On a phone the next touch resets it, but with a mouse on a touchscreen laptop the next pointer move scrolls the list. Setting the list's scroll (`list.scroll_vertical = list.scroll_vertical`) calls its `_cancel_drag()`; the hook does that on the button's `pressed`.

**Test it without a phone:** run the Windows build with an `override.cfg` beside the exe containing `[input_devices]` and `pointing/emulate_touch_from_mouse=true`, then drag by window messages ([[Drive a Godot window by messages, not the mouse]]). `tests/layout_audit.gd` flags any button or word that still stops the touch inside a scroll list (SCROLL).

Found in the bug hunt of [[2026-11-26]].
