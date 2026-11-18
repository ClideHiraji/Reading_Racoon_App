# Pictures, drawn in code (D-027)

The game's full-colour pictures (words, stickers, Home tiles, Practice games) are drawn here in code, so all 60 share one style. The game's copies are in `assets/pictures/`.

**The style ("paper", the game's):** cut from paper like the rest of the game (D-009).
- Every piece is one flat colour, lifted on a crisp little shadow. No gradients, shine or outlines.
- Pale pieces (white, cream, skin) get a faint edge, so they show on cream paper.
- Colours come from the game's palette, softened a touch toward the warm paper.
- Dot-eye faces with blush go on animals, the sky and fruit; objects stay faceless.
- Each picture is cropped to fill its box (`fit.json`).

| File | What it does |
|---|---|
| `icons_gen.py` | The style: colours, paper pieces, faces (an `Icon` that writes one SVG). |
| `icon_set.py` | One function per picture. `python icon_set.py <out_dir> [paper\|soft\|ink]` writes them all. |
| `fit.py`, `fit_render.gd`, `fit.json` | Measures each paper picture with Godot's own SVG renderer and saves the view box that crops it to fill its square. |
| `build_board.py` | Writes the canvas boards that show them (Icons page of the Racoon canvas). |

`soft` and `ink` are the first, glossy sticker version (gradients and outlines), kept for comparison. They looked out of place in the game.

## Change or add a picture

1. Edit or add its function in `icon_set.py` (and its line in `ICONS`).
2. If its size changed or it's new: `python fit.py "<Godot.exe>" <scratch Godot project>`. Copy `fit_render.gd` into an empty scratch project for this; never run it in the game's folder while the editor is open.
3. `python icon_set.py ../../assets/pictures`. A new picture also needs its `.import`: Godot writes one when it imports; set `svg/scale=3.0` in it, like the others.

The one-colour glyphs the game tints (arrows, check, play, pause, repeat, talk, heart plus, and the tinted star, lock and coins on buttons and badges) stay in `assets/icons/`.
