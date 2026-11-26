---
type: learning
date: 2026-11-19
status: confirmed
tags: [learning, godot, ui, video]
---

# Godot VideoStreamPlayer expand stretches the video

What happened: the Watch & Listen player set `expand = true` on its `VideoStreamPlayer` so a teacher video would fill the stage. `expand` scales the video to the node's whole rect and ignores the clip's shape, so a 16:9 clip on a phone's 672 × 430 stage was squeezed by about 12%. Without `expand`, the node takes the video's own pixel size and doesn't scale at all. Neither keeps the shape.

**So:**
- Put the `VideoStreamPlayer` (with `expand = true`) inside an `AspectRatioContainer` (`STRETCH_FIT`, centred) and set its `ratio` from `get_video_texture().get_size()`. For Ogg Theora that size is known from the file's header as soon as `stream` is set, before `play()`.
- The texture size is the picture size (320 × 180), not Theora's padded frame size (a multiple of 16).
- Test it with a real clip: `tests/fixtures/wide_clip.ogv` (1 s of 320 × 180, recorded with Godot's Movie Maker, `--write-movie clip.ogv`). `tests/ui_smoke.gd` checks the shown video stays 16:9 and fits the stage.

Related: [[Godot autowrap labels collapse in grids]], [[D-017 Practice Library Watch and collections]], [[D-020 Teacher content download in the game]].
