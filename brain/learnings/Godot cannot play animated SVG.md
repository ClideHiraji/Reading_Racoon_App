---
type: learning
date: 2026-10-22
status: confirmed
tags: [learning, godot, art]
graphify: submitted
---

# Godot cannot play animated SVG

Godot imports an SVG as one still image: SMIL animation (`<animate>`, `<animateTransform>`) is dropped. The team's `Animated - Star.svg` showed only its first frame.

**What worked:** sample the animation in Python at 30 fps (read each `<animate>`'s `values` / `keyTimes` / `keySplines` and write one static SVG per frame), render each frame in Godot with `Image.load_svg_from_string()` and save it as PNG (`assets/anim/star/star_00..45.png`), then play the frames in a `TextureRect` (`ui/animated_star.gd`, cached once in a static array). Rendering in Godot keeps the look the same as the engine's own SVG import.

**Watch for:** the star settles at about 45% of its box, so size the box about twice the star you want; and run `--import` after adding the PNGs and the new `class_name`.

Seen while building [[D-022 Full UI redesign]].
