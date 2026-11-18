---
type: learning
date: 2026-11-16
status: active
tags: [learning, art, animation, racoon, svg]
---

# Build a puppet from the artist's file, not from code

When an artist edits a character in a drawing app, read their shapes into the animation rig. Don't redraw the character in code to match their edit.

**What happened:** Racoon's motion demo first drew its own shapes from numbers in code (head ellipse, body ellipse, a generated tail). When the user redrew him in Inkscape (arms out, bean body, no scarf), matching that by hand would have meant re-measuring every part, and every later edit would mean doing it again. Instead, `tools/racoon-art/motion-demo/build_racoon.py` reads the SVG and places the user's own shapes on his round head and body ([[Turn a flat 2D character by putting its parts on round shapes]]). Now each edit only needs a rebuild.

**How to do it:**
- **Find parts by their labels** (Inkscape's `inkscape:label`), not by ids or order, and fail with a clear message naming the missing label.
- **Apply every transform** (groups, `matrix()`, scale) so the shapes are in page coordinates, and convert gradients in `userSpaceOnUse` to the shape's own box so the shading moves with the shape.
- **Keep the drawing read-only.** Nothing the build writes goes to the artist's file. (An older export script that wrote that file was deleted, so a rebuild can't wipe the user's edits.)
- **Keep what the drawing can't hold as a few named constants**, such as depth: how round the head is, how far forward the ears sit, and how far the tail curls behind.
- **Give each moving part its own frame, measured from the drawing:**
  - An arm: the line from the shoulder to the paw tip, found from the sleeve's main axis. Every outline point is stored as (distance along that line, distance across it). Re-laying the points along a new line points or stretches the arm without distorting the paw.
  - A tail: fit a centre line to the drawn tail (Nelder-Mead on the overlap of a tube with the drawn shape), then store each outline point as (t along the line, offset along, offset across). The tail then bends and turns with its drawn shape intact.
- **Expect the drawn pose to change, and write moves as targets, not offsets:** the user's second edit moved the arms from out to the sides down to hanging. Moves that said "lift the arm 0.55 rad" now barely moved it. Moves that say "raise to 23° above level" work from any drawn pose. Also measure a limb's direction from the sleeve toward the paw rather than assuming which way it points.
- **Let props hang off the hands:** a held prop (Racoon's book) is placed from where the paws are, not the other way round. Its edges are where the paw centres go, and the arm's length is solved so the middle of the paw, not its tip, lands on the edge. Then every move that moves a paw moves the prop too, and one-handed moves just let the prop hang from the other paw.
- **Check the rest pose against the drawing, pixel by pixel:** render both at 3× and count the pixels that differ. Racoon differs in 0.1%, all thin edge slivers. Then check poses and moves ([[Headless Chrome runs animation frames only once]]).
- **Check the reader before trusting it:** compare every shape's outline with Chrome's rendering of the same file. Racoon's 49 shapes all fall within 0.4 px.
