---
type: learning
date: 2026-10-26
status: active
tags: [learning, blender, art]
---

# Blender opens files in Solid shading

**Blender switches Rendered shading back to Solid whenever it loads a file.** A `.blend` saved in Rendered view always opens in Solid, whether a background script saved it or Blender's window did. Material Preview is kept, and so is the camera view.

Tested on 2026-10-26 with Blender 5.0: the same scene, saved once in Rendered and once in Material Preview, reopened in Solid and in Material Preview.

**To make a model open in its real look**, save its 3D views in Material Preview, lit like the render:

```python
shading.type = "MATERIAL"
shading.use_scene_lights = True          # the scene's own lights
shading.use_scene_world = False
shading.studiolight_intensity = 0.0      # no extra light from the preview HDRI
shading.studiolight_background_alpha = 0.0
```

Material Preview runs EEVEE, so a toon shader built with Shader to RGB shades as it does in an EEVEE render. `tools/racoon-art/racoon_3d.py` saves Racoon's `.blend` this way.

**Hide moods with collections, not only `hide_render`.** `hide_render` keeps an object out of renders but not out of the viewport, so the open file showed both of Racoon's faces at once. The script now puts each mood in its own collection ("Mood idle", "Mood happy") and leaves the happy one unticked.

Related: [[D-024 Racoon redesign]], [[Compare 3D renders with 2D art in one shared frame]].
