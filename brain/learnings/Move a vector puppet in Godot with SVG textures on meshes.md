---
type: learning
date: 2026-11-16
status: active
tags: [learning, godot, art, animation, racoon, svg]
---

# Move a vector puppet in Godot with SVG textures on meshes

To bring an SVG puppet that moves in a browser into Godot, ship its parts as SVG strings in a JSON file. Rasterise each part once at the size it's shown, then move and warp those textures every frame.

**Update (2026-11-17):** Racoon is now a scene with one node per part (`scenes/companion/racoon_puppet.tscn`, D-024).
- The parts are SVG, imported at `svg/scale=2.0` with mipmaps, not rasterised at run time. Since 2026-11-17 they're on one sheet, `assets/racoon/racoon_atlas.svg`, not one file each ([[Pack a Godot puppet's SVG parts onto one sheet]]).
- The quads and meshes are Polygon2D nodes: `uv` in texture pixels, triangles in `polygons`.
- The moves are AnimationPlayer animations ([[Record coded tweens as AnimationPlayer keyframes]]).
- The notes below describe the first version, which drew everything from one Control.

**What happened:** Racoon's canvas demo bends his parts with SVG transforms, masks and clip paths every frame ([[Turn a flat 2D character by putting its parts on round shapes]]). Godot can't render SVG live ([[Godot cannot play animated SVG]]). So `build_racoon.py` writes `assets/racoon/racoon_rig.json`, and `raccoon.gd` does the following:
- **Rasterising:** `Image.load_svg_from_string(svg, scale)` makes each part a texture at the scale he's shown, cached by name and scale, so every Racoon of the same size shares them.
- **Rigid parts** (head, body, feet, book): `draw_set_transform_matrix` + `draw_texture_rect`.
- **Bent parts** (face decals on the round head, arm strips, the tail, the scarf band): a grid or strip of points with UVs, drawn with `RenderingServer.canvas_item_add_triangle_array`.
- **SVG masks:**
  - a clip to the head becomes a small canvas shader that multiplies by the head texture's alpha
  - a sliding cut (the ear coming in front) becomes polygon clipping on the CPU, with vertex alpha for the soft edge
- **The JS tweens and awaits** become a small tween table plus a `Job` object with a `finished` signal. A new move drops the old tweens and timers, so an interrupted coroutine never resumes.

**Watch out for:**
- Keep each SVG string in short chunks: the editor freezes on very long lines ([[Godot editor freezes on very long lines]]).
- GDScript can't infer a type from a Dictionary value (`var front := d.h < 2`): give it one (`var front: bool = ...`).
- A Control's `_process` runs in the editor for `@tool` scripts. Skip the per-frame work there.
- Cards that show many small copies (the Closet) should draw them once (`still`), not animate each.

**Cost:** about 1.3 to 1.6 ms per frame for the whole rig on the dev laptop while he moves.
