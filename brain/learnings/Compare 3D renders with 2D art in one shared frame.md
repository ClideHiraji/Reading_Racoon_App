---
type: learning
date: 2026-10-26
status: active
tags: [learning, blender, art, testing]
---

# Compare 3D renders with 2D art in one shared frame

To check a 3D model against its 2D drawing with numbers, not only by eye, render both into **the same frame**:

- **Shared units:** 1 Blender unit is 100 px of the 400 px drawing, and the drawing's ground line (y = 378) is z = 0.
- **Same framing:** an orthographic front camera at (0, −12, 1.78) with ortho scale 4.0, rendered at 800 × 800 on a transparent background, gives exactly 2 px per drawing px. Render the SVG at 800 × 800 on a transparent background too.
- **Silhouette overlap (IoU):** the pixels opaque in both images (alpha > 128), divided by the pixels opaque in either. 1.0 is a perfect match.
- **Landmarks,** each as an offset in drawing px: the ear tips (highest point on each side), the tail tip (rightmost), the feet (lowest), the pupils (darkest pixels near each eye), and the centres of the scarf's teal and the book's orange.
- **A review sheet** each round: 2D, 3D, an overlay (the drawing's edge over the faded render), a difference image (red only in 2D, blue only in 3D), the other angles, and both at the game's sizes (180, 100, 56 px).
- **A game test:** swap the render into the real screens on a scratch copy, and screenshot them.

With this loop, Racoon's option C went from 91.6% to 95.7% overlap in seven rounds. The ears moved from 33 px off to within 4.4, the book to within 0.5, and the triangles fell from 304k to 58k.

**Watch out:**
- Headless Chrome draws edges a little differently with and without the GPU, which moved the score in the fourth decimal. Use `--disable-gpu` (software rasterizing) and a scratch `--user-data-dir`, so the reference is the same on every run.
- Don't chase 100%. Some differences come from the depth that 3D adds: the muzzle stands out, and the tail's rings wrap at an angle. Stop when the numbers stop moving and the review sheet looks right.

Code: `tools/racoon-art/loop/`. Results: [[D-024 Racoon redesign]].
