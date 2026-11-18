---
type: learning
date: 2026-10-26
status: active
tags: [learning, art, animation, racoon]
---

# Turn a flat 2D character by putting its parts on round shapes

> **Added 2026-11-16, two fixes for depth:**
> - **A part that rotates to the front of a round shape must come in front of it.** Racoon's ears were drawn behind his head, as in the 2D art, so in a head turn the near ear sank behind the dome. Draw a second copy in front of the head, shown down to a line that slides from the dome's edge to the part's base as it comes forward, with a soft edge so it grows out of the fur. Only do it while the face points toward the viewer.
> - **Sort parts by depth against each other, not only against the body.** Racoon's arms knew only "behind the body" or "in front of it", so from behind they covered his tail, which was nearer to the viewer. Give in-between slots (here: after the body, before a nearer tail) and pick them by comparing depths.
> - **A limb that rotates must keep growing out of the body.** Hide the limb's drawn outline near the joint once it swings (a mask whose radius grows with the swing). Wherever the root pokes out of the body, give it a rim like the drawn outline (its stroke, clipped to the limb and masked to outside the body). At rest the art is unchanged.

A 2D character built from round shapes can turn all the way around without a drawing for every angle. Give each part of the flat drawing a place on the character's round head or body, then move it as the character turns.

**How Racoon does it** (option C, canvas board "C · Racoon in motion", `tools/racoon-art/motion-demo/Motion.dc.html`):
- **Outlines that don't change:** a sphere looks round from every side, so the head outline stays put. The body is an ellipsoid, so it narrows a little in profile.
- **Face parts** (mask, brows, eyes, blush) are painted on the head:
  - each point slides around the head by its longitude
  - it squeezes as it nears the edge
  - it folds onto the edge once it turns behind
- **Shapes that stick out** (muzzle, nose) sit in front of the head's surface, so they poke past the outline in profile.
- **The tail, book, feet, arms and scarf knot** turn about his middle. Each one is drawn in front of or behind the body, depending on which side it's on.
- **At rest** every part sits exactly where the drawing has it, so he looks the same as the 2D drawing.
- **One gotcha:** a shape that crosses the back of the head (the mask, when he faces away) must turn as one piece, measured from its own centre. Turning each point on its own splits the shape across the back of the head, which drew a dark band there.

**Ears and other parts that stick out:**
- **Place them a little forward of the sides.** Racoon's ears sit at 72° around his head, not 90°. Exactly at the sides, a turn mostly moves them in depth, so they hardly shift while the face slides 60 px, and the head looks like a mask sliding on a ball.
- **Keep cone-shaped parts at least 70% wide from the side.** Ears squeezed like flat cards turn into spikes in profile.
- **Give them follow-through with a spring** driven by how fast the head turns and rises: they trail behind turns, flop on jumps and landings, then bounce back. A small kick to one ear's spring makes an idle ear twitch.

**The same in Godot:** Node2D parts, plus a small script that places each part from the turn and tilt every frame. That's about 30 points per frame, so it's cheap even on low-end phones.

**Limits:** the side and back views are computed, not drawn. They read well for a round, chibi character, but an artist's own side view would be cleaner.

Related: [[D-024 Racoon redesign]], [[Animate drawn shapes by moving a layer, not redrawing]].
