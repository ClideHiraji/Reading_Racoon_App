---
type: learning
date: 2026-11-17
status: active
tags: [learning, godot, textures, racoon]
---

# Pack a Godot puppet's SVG parts onto one sheet

A puppet built from many SVG parts doesn't need one file per part. Godot imports every SVG as its own texture with its own `.import` file. Put all the parts on one SVG sheet and point each node at its part's rectangle.

**What happened:** Racoon's 27 parts were 27 SVGs in `assets/racoon/parts/`: 54 files with their `.import`s, and 27 textures to load (D-024). `build_racoon.py` now shelf-packs them onto `assets/racoon/racoon_atlas.svg`. It's imported once, at 2× with mipmaps, and renders the same at rest.

**How:**
- Copy each part's markup into its own `<g transform="translate(...)">` on the sheet, and prefix its ids (gradients, clip paths) so two parts never share one.
- Leave a gap between parts (12 drawing units here). Mipmaps average neighbouring pixels, and without a gap the small sizes bleed one part's edge into the next.
- Write each part's place on the sheet next to its box in the drawing (here in `racoon_rig.json`). In Godot, scale it by the imported texture's size over the sheet's size (the import scale, 2×).
- A textured quad's `uv` is its rectangle's four corners. A mesh with 0–1 UVs maps through `Transform2D(Vector2(w, 0), Vector2(0, h), corner)`.
- A shader that used a whole part as a mask (the face clipped to the head) needs that part's sub-rectangle on the sheet as a uniform. It also needs a test that zeroes anything outside the box, or it picks up the neighbouring parts.
- Keep the sheet's SVG lines short (here 160 characters at most): the editor freezes on very long lines ([[Godot editor freezes on very long lines]]).

Related: [[Move a vector puppet in Godot with SVG textures on meshes]].
