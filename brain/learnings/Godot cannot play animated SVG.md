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

**Two more traps (the second star and the heart, same day):**
- Animated colors (`values="#f08f00; #f08f00"`) must be blended as colors. Read as numbers, they turn into invalid colors, strokes vanish and fills go black.
- Check the SVG in a browser first: `svg.pauseAnimations(); svg.setCurrentTime(t)` at a few times. A re-exported star kept its main layer at scale 0 the whole time, so it was empty in the browser too; no renderer bug.

The sampler and renderer now live in `tools/svg-frames/` with the commands for the star and the heart.

**Later the same day:** the game switched to playing the team's Lottie files live ([[Godot can play Lottie with a small player]]), and the PNG frames and `ui/frame_animation.gd` were removed. This frame route is still the way for an animation that only exists as animated SVG.

Seen while building [[D-022 Full UI redesign]].
