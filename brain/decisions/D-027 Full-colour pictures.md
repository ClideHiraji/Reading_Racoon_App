---
type: decision
status: decided
date: 2026-11-18
issue: 28
graphify: submitted
tags: [decision, art, icons, pictures, godot, d-009]
---

# D-027 Full-colour pictures

**Decision:** the game's pictures are full-colour drawings, drawn in their own colours and never tinted, and they are **cut from paper like the rest of the game** ([[D-009 Art direction Butuan storybook]]).

- **The style:**
  - Every piece is one flat colour, lifted on a crisp little shadow, like the buttons and the Home trees. No gradients, shine or outlines.
  - Pale pieces (white, cream, skin) get a faint edge, so they still show on cream paper.
  - Colours come from the game's palette (D-016), softened a touch toward the warm paper.
  - Dot-eye faces with blush go on animals, the sky (sun, moon, star, cloud) and fruit. Objects stay faceless, so a face means something alive.
  - Each picture is cropped to fill its box (`fit.json`), so all of them sit the same size in a card.
- **63 pictures** in `reading-racoon/assets/pictures/`, imported at 3× (384 px) with mipmaps. They cover every word picture in the lessons, all 40 stickers, the Home tiles, every Practice game (Spin the Words has its own two paper arrows) and Memory Match's card backs.
- **The UI's own icons too (2026-11-18, the user asked):**
  - A gold paper **coin** for every coin: the counters on Home, the path and the Closet; Closet prices and its Buy button; lesson-end and reward cards.
  - The Home bar's **Closet** (the hat), **Stickers** (a new star sticker with a peeling corner) and **Words** (a new orange word book with a pencil).
  - The sticker album's group tabs and the Closet's slot tabs show their paper pictures (`ChunkyButton.full_color`).
  - The Closet's tabs are picture-only, 78 px, with no words (the user asked). Racoon says a tab's name when it's tapped, and the name is its tooltip.
  - The old one-colour coin silhouette was removed.
- **Drawn in code**, not by hand: `reading-racoon/tools/icon-art/` (`icons_gen.py` is the style, `icon_set.py` has one function per picture). Change a picture there and run it again.
- **Where they show:** word pictures (picture cards, choices, order tiles, balloons, Word Book, Library, Watch), stickers (a paper disc ringed in the group's colour), the Home tiles and the Practice games.
- **What stays one colour:** glyphs the game tints to match a button, badge, tab or the path (arrows, check, play, pause, repeat, talk, heart plus, and the tier stars and lock). They stay in `assets/icons/` (game-icons.net, CC BY 3.0). The 24 silhouettes that were only ever word or sticker pictures (ant, apple, bag, dog, mouse…) were removed on 2026-11-18; a glyph stays only where the game draws it tinted (cat on "Practice my words", fish and boat on the path's trail, bolt on the path…).
- **In code:** `Icons.picture_rect()`, `Icons.picture_tex()` and `Icons.has_picture()`, plus `ChunkyButton.full_color`. `Icons.exists()` is true for a picture or a glyph; `Icons.has_glyph()` only for a glyph. A name with no drawing falls back to the tinted glyph.

**History:** the first version (the same day) followed the user's reference board: soft gradients, a gloss highlight, an outline in a deeper shade of each colour, and a shadow on the ground. The user chose it on the canvas, then saw it in the game and said it looked out of place. D-009 had already rejected "bold sticker" and "soft clay" looks for this paper world, and the first version was both. The pictures were redrawn as paper cut-outs from the same code.

**Why**
- The white silhouettes came from many artists and didn't match each other or Racoon (a realistic goat beside a flat heart). One drawn style makes the game feel like one world.
- Grade 1 readers match a word to its picture. A coloured, friendly picture is quicker to recognise than a silhouette.
- Paper cut-outs belong to the game's world: flat colours on crisp shadows are how its buttons, cards and scenery are already made.
- The old "mouse" was a computer mouse; the lessons mean the animal ("Which is bigger, elephant or mouse?").

**Consequences**
- Updates [[D-009 Art direction Butuan storybook]]: pictures are no longer tinted silhouettes. Still no emoji.
- Unit tests check that every lesson picture, sticker, Home tile and Practice game has a full-colour drawing, and that pictures are drawn untinted.
- A few paper colours behind pictures changed to suit the new drawings: hat (now pale blue), ball, ant, cloud, elephant.
- A new word picture needs a drawing in `tools/icon-art/icon_set.py` and a new `fit.json` (`fit.py`), or it shows its tinted glyph.

**Rejected:**
- Stickers (gradients, shine, coloured outlines, a ground shadow): out of place in the paper world.
- Racoon's ink outline: more like stickers still.
- Faces on every object: they would blur which things are alive.
- Raster art: the SVGs stay sharp at every size and are small.

Details: [[10-open-issues]] (issue 28)
