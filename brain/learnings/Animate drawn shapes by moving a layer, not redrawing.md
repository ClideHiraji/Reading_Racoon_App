---
type: learning
date: 2026-10-26
status: active
tags: [learning, godot, performance]
---

# Animate drawn shapes by moving a layer, not redrawing

**Redrawing is expensive.** In Godot, `queue_redraw()` runs the whole `_draw()` again, and GDScript drawing is slow.

- Racoon's idle breathing changed a property whose setter called `queue_redraw()`, so his whole body (about 40 shapes with smooth edges) was rebuilt every frame on every screen.
- That cost 1.86 ms per frame on a laptop, roughly 10–20 ms on a low-end phone: most of a 60 fps frame.
- The Closet's six Racoons cost 11 ms per frame on the laptop.

**Do instead:**
- Draw each part once onto a child `Node2D`, added with `add_child(layer, false, INTERNAL_MODE_FRONT)` and drawn from `layer.draw.connect(...)`.
- Animate the layer's `position`, `rotation`, `scale` or `modulate`; a transform change costs almost nothing.
- Redraw only when the shape itself changes: mood, outfit or size.
- A layer with `show_behind_parent = true` draws behind its parent (Racoon's tail).
- Round pieces can turn about a point without changing their look (the tail's wag).

After the change, Racoon idling costs 0.023 ms per frame, about 80× less, and he looks identical. The same fix applies to the map's pulsing node and the sunburst.

**Measure first:**
- Headless Godot sleeps until 6.9 ms each frame, so a single scene always looks fast.
- Put many copies of a piece on screen until frames run long, then divide the frame time by the number of copies.
- Connecting to every `CanvasItem.draw` signal shows which pieces redraw every frame.

Related: the first visit to a screen compiles its scripts (Home took 0.5 s on the laptop). `GameState.warm_scenes()` loads the main screens on a background thread while the start screen waits for a tap.
