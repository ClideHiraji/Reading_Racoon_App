---
type: learning
date: 2026-11-17
status: active
tags: [learning, godot, textures, racoon]
---

# A saved Godot scene keeps a sheet's old UVs

When parts of a scene are textured from a sheet (a texture atlas) and the sheet is repacked, a scene saved before the repack keeps the old rectangles. Parts show the wrong piece of the sheet until the scene is rebuilt, or until the script sets them again on load.

**What happened:** moving the Closet items off Racoon's sheet onto their own (D-026) moved his 19 parts on `racoon_atlas.svg`. `racoon_puppet.tscn` had been saved with each quad's `uv` and a `tex` meta. `_set_quad_tex()` skipped a node whose `tex` meta already matched, so his muzzle and ears showed other parts of the sheet: a dark shape on his face and pink ears.

**How to apply:**
- In the script's setup, clear the "already set" mark before setting each part once (`node.set_meta("tex", "")`). It costs a few quads per instance, and an old scene heals itself in the game and in the editor.
- Then rebuild the scene (`make_racoon_puppet.gd` without `--animations`), so the saved file matches too.
- Meshes whose UVs are worked out every frame from the sheet (the face decals) aren't affected.

**The same trap with a "done" mark (later the same day):** his head mesh kept a `tris` mark ("triangles already built") while the scene builder reset it to a plain quad with no triangles. When the scene loaded, the mesh trusted the mark and skipped the triangles, so his head drew nothing. A saved mark is only as good as the data saved with it. Check the data itself (the triangle count), not the mark, and clear the mark wherever the data is reset. A unit test that loads the saved scene and checks the meshes now guards it.

Related: [[Pack a Godot puppet's SVG parts onto one sheet]].
