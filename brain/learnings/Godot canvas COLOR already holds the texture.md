---
type: learning
date: 2026-11-17
status: active
tags: [learning, godot, shaders]
---

# Godot canvas COLOR already holds the texture

In a Godot 4 `canvas_item` shader, `COLOR` in `fragment()` is already the vertex colour times the texture. Writing `COLOR = COLOR * texture(TEXTURE, UV);` applies the texture twice: colours come out darker and more saturated (each channel squared).

**What happened:** Racoon's belly clip shader made his white belly go from (0.99, 0.96, 0.91) to (0.98, 0.93, 0.84). A shader containing only that line did the same, and removing the line restored the drawing's colours exactly. The same line had been in his face clip shader since D-024, so his brows were drawn too dark and his mask near-black. It was also in the Closet's tier shader, so the shiny items were too dark.

**How to apply:**
- Start a custom canvas shader from `COLOR` as it is (`vec4 c = COLOR;`) and change only what you mean to: alpha for a clip, a highlight for a shine.
- Sample `TEXTURE` yourself only for a different spot (an offset, a mask), not the pixel itself.
- Check a new shader against the same node with no material: same pixel, same colour.

Related: [[Move a vector puppet in Godot with SVG textures on meshes]].
