---
type: learning
date: 2026-10-22
status: confirmed
tags: [learning, godot, animation, lottie]
graphify: submitted
---

# Godot can play Lottie with a small player

Godot 4.7 has no Lottie support: no class for it, and `.lottie` or Lottie JSON isn't a resource it loads. But a Lottie is just JSON (a `.lottie` file is a zip with `manifest.json` and `a/<scene>.json`), and the team's animations use a small part of the format, so `ui/lottie_player.gd` plays them live with Godot's own drawing:

- **Layers:** shape layers and precomps. A precomp's layers run on `(time - st) / sr` (`st` start offset, `sr` time stretch); a shape layer's keyframes are in its comp's time, its own `st` doesn't shift them. The last layer in a list is at the bottom.
- **Shapes:** groups with a transform (`translate(p) * rotate(r) * scale(s) * translate(-a)`), bezier paths (static or animated: vertices `v` with relative handles `i` / `o`), ellipses, solid fills, linear-gradient fills (a `GradientTexture1D` sampled by each point's place along the axis), strokes with butt or round caps, trim paths. Fills and strokes paint the paths *before* them in the list, earlier groups included; earlier items are on top.
- **Keyframes:** cubic-bezier ease from the key's out handle (`o`) and the next key's in handle (`i`); solve x, use y (it can overshoot, like a bounce).

**The trap that broke the SVG exports:** the precomps' time stretch (`sr` 0.4 and 0.5). The SVG exporter ignored it, so the star stayed at scale 0 (empty) and Regain Heart showed only its slow start. Check a `.lottie` for `sr` before trusting an export.

**Light enough for low-end phones:** paths are turned into point arrays once per file; each half-frame is built once, in the animation's own units, cut into triangles, and shared by every player of that file at any size; drawing replays the triangles only when the frame changes. `LottiePlayer.warm_up()` builds frames ahead, a couple per game frame, from a node in the tree, so quitting mid-way leaves nothing behind. On a laptop: first build about 5 ms a frame for the star, replays about 1.3 ms; the hearts about 0.5 ms.

**Checking against a video:** draw the player at the video's frame times and diff frame by frame (OpenCV reads the MP4). When capturing, remember a 720×1280 canvas is scaled to fit the window (a 1061 px tall window draws it at 0.83), so compute the crop from both width and height; getting that wrong made the star look 22% too small.

**GDScript gotchas met on the way:** layer `ty` is a number and shape `ty` is text, so compare with `str()`; a static function in a subclass counts as an override, so its signature must match the parent's; a lambda can't wrap onto a second line inside a call.

Seen while building [[D-022 Full UI redesign]]; it replaced the frame pipeline of [[Godot cannot play animated SVG]].
