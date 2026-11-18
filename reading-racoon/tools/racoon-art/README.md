# Racoon art (D-024)

The source of the redesigned Racoon: **option C, "Little reader"**. He has Mochi's round head and small bean body, a thick ink outline with soft shading, grey-violet fur, a bandit mask, a ringed tail and the teal river scarf, and he holds an open book.

On 2026-11-16 the user redrew him in Inkscape (`parts/racoon_C_inkscape.svg`): arms hanging at his sides (a second edit; the first had them stretched out), a taller bean body, thinner outlines, and no scarf, book or ground shadow. The motion demo and the part files are built from that drawing; the older 2D drawings and the 3D model below still show the earlier design.

This folder has a `.gdignore`, so Godot doesn't import it. Everything generated goes to `out/`, which git ignores.

## 2D drawings (`make_racoons.py`)

`make_racoons.py` draws all four style options from the canvas "Racoon redesign options":

| Option | Name | Notes |
|---|---|---|
| A | Mochi | |
| B | Bean plush | |
| C | Little reader | the chosen one |
| D | Sticker | |

Each comes in four moods (idle, happy, thinking, sleepy) plus a test wearing the Closet's salakot. Every drawing is a 400 × 400 SVG with the feet near y = 378, on the same grid as today's Racoon, so Closet items can be fitted the same way.

```bash
python make_racoons.py
```

## 3D model (`racoon_3d.py`)

Option C in 3D, built by Blender 5.0 from simple shapes measured off the 2D drawing:
- toon shading (three flat tones per colour) and an ink outline (an inside-out shell)
- the face markings as a smooth texture projected from the front
- two moods: idle ("w" smile, open eyes) and happy (closed ^^ eyes, open smile)

Every size is in the `P` table at the top. 1 Blender unit is 100 px of the 400 px drawing, and the drawing's ground line (y = 378) is z = 0.

```bash
blender -b --factory-startup --python-exit-code 1 -P racoon_3d.py -- <out_dir>
```

| Output | What it is |
|---|---|
| `racoon_C_3d_front_match.png` | the front, framed exactly like the 2D drawing rendered at 800 × 800 (2 px per drawing px) |
| `racoon_C_3d_front.png`, `_side`, `_back`, `_three_quarter` | four angles |
| `racoon_C_3d_front_match_happy.png`, `_three_quarter_happy` | the happy face |
| `checks.json` | Blender version, object and triangle counts, anything outside the frame, render times |
| `racoon_C.blend` | the model. It opens in Material Preview lit by its own sun, which is the toon look, through the three-quarter camera. To swap faces, tick "Mood happy" and untick "Mood idle" in the Outliner. |

`out/3d/` holds the final round: these files, plus the loop's `metrics.json`, `review.png` and `ingame.png`.

## The loop (`loop/`)

The model was refined in rounds: build, compare with the drawing, review, test in the game, adjust. Seven rounds took the outline overlap from 91.6% to 95.7% (see D-024).

- `compare.py <round_dir> <label> <ref_png>` scores a round against the 2D drawing: the silhouette overlap (IoU), and landmark offsets in drawing px (ears, pupils, scarf, book, tail tip, feet). It writes `metrics.json` and `review.png`: 2D, 3D, an overlay and a difference image, the other angles, both at game sizes, and the happy face.
- `ingame.gd` puts the render in place of Racoon on Home, a lesson and Practice, and screenshots them.
- `round.sh <n>` runs one round into `<scratch>/round<n>/`: render, compare, game test.

Before the first round:
1. Run `python make_racoons.py`. `round.sh` renders the 2D references from its SVGs at 800 × 800 with headless Chrome.
2. Make a scratch copy of the game and import it. **Never run Godot on `reading-racoon/` itself while the editor is open.** In PowerShell:

   ```powershell
   robocopy reading-racoon <scratch>\rr /MIR /XD .godot tools
   & "C:\Program Files\Godot\Godot.exe" --headless --path <scratch>\rr --import
   ```

Then, from this folder:

```bash
NSP=<scratch> bash loop/round.sh 8
```

`BLENDER`, `GODOT` and `CHROME` override the default install paths. Blender and Chrome run without a window, but the game test opens a small Godot window for a few seconds, since it needs a real renderer to take screenshots.

## Motion demo (`motion-demo/`)

`Motion.dc.html` is the canvas board "C · Racoon in motion (2D demo, press Play)": Racoon acting as if he were in 3D. It runs only on the canvas, and is kept here as the reference for a Godot version.

**It's built from your Inkscape drawing**, `parts/racoon_C_inkscape.svg` (redrawn by hand on 2026-11-16):

```bash
python build_racoon.py
```

| File | What it is |
|---|---|
| `build_racoon.py` | reads the drawing and writes `Motion.dc.html` and `../out/parts/`. It never writes to the drawing. |
| `racoon_design.py` | the drawing reader: each object's shape (transforms applied), fill, outline and gradient |
| `Motion.template.dc.html` | the board without Racoon: the scene, the buttons and the moves |
| `InGame.template.dc.html` | the second board, "C · Racoon in the game": the laptop lesson screen at its real size, with ten of the game's moments. It runs the Motion board's script (inserted at `/*RACOON:BASE*/`) and adds the lesson and the moves on top. `build_racoon.py` writes it to `InGame.dc.html`, with its ids renamed `ig-` |

What the drawing must keep (layer › object labels): `Tail` › Fur and the rings; `Body` › Foot left, Foot right, and two paths, the body (the wider one) and the belly; `Arms` › groups "Arm left" and "Arm right", with the paw labelled "paw"; `Head` › Ear left and Ear right (Outer, Inner), Head, Head shine; `Face` › Brow left and right, Mask, Eye left and right (White, Pupil, then glints), Blush left and right, Muzzle, Nose, Mouth (smile). The Expressions and Poses layers aren't read: the demo draws his blink, happy eyes, other mouths and the pointing arm itself.

Only his depth isn't in the drawing: `HEAD_R`, `EAR_Z` and `TAIL_Z` at the top of `build_racoon.py`.

- Each part of the drawing has a place on his round head and body. Face parts slide around the head, and the muzzle and nose stick out in profile. The tail, feet and arms turn about his middle and swap in front of or behind him. At rest he matches the drawing (0.1% of pixels differ, along edges).
- The arms sway as he breathes, fly up on hops, swing as he walks, and swing round the shoulder to reach. Moves set arm poses as angles, so they work whether the arms are drawn out or hanging. The tail's outline rides on a centre line fitted to the drawn tail, so it keeps its shape as it turns.
- "Try on from the Closet" puts on the River scarf and the open book from `closet/neck/scarf_teal.svg` and `closet/paws/open_book.svg`. His paws hold the book's edges, so it moves with them (lifted for "ta-da", in one paw when he points, over his face for peekaboo).
- The moves:
  - a fake-3D head turn
  - a full turn-around
  - pointing at PLAY
  - walking up to the glass to knock and talk
  - four tap reactions (giggle, spin, peekaboo with his paws, jump)
  - eyes and head that follow the pointer
- The ears sit a little forward on his head and stay cone-wide in profile. A spring per ear makes them trail turns, flop on jumps, and twitch now and then.
- The game uses the same rig: `scenes/companion/raccoon.gd` is a GDScript port of `headDecal`, `onMuzzle`, `arm()` and `rig()` (see "In the game" below).

## Parts to edit (`parts/`)

- **`racoon_C_inkscape.svg` is Racoon.** It's the user's hand-edited drawing, with one layer per body region (Tail, Body, Arms, Head, Face) and every object named, plus hidden Expressions and Poses layers. It opens in Inkscape, Figma or Illustrator; this machine's Inkscape is the Microsoft Store build, which can't run from the command line, so open the file from Inkscape (File › Open).
- **The Closet's items are in `closet/`, one Inkscape file per item** (D-026, FR-07): `closet/hats/gold_crown.svg`, `closet/neck/scarf_teal.svg` and so on, each linking Racoon underneath. Their names, tiers and prices are in `reading-racoon/content/closet.json`. **How to add or change an item: `closet/README.md`.** (Until 2026-11-17 they were all in one file, `parts/racoon_C_closet.svg`, kept in `parts/before-closet-split/`.)
- `before-inkscape-edit/` holds the older exports, from the design before the user's edit (with the scarf and hanging arms). They're kept for reference only.

`build_racoon.py` also writes every part of the drawing to `out/parts/`:
- `<part>.svg`: one file per object, 21 in all, back to front. Each file's viewBox is that part's box on the 400 × 400 page, so it goes back in exactly the same place.
- `racoon_rest.svg`: all the parts together.
- `parts.json`: each part's label, layer, drawing order and box.
(The Closet's items are each their own file already, in `closet/`.)

Left and right are as you look at him.

**To change Racoon:**
1. Edit `parts/racoon_C_inkscape.svg` (or a Closet item in `closet/`), keeping the object labels listed above. (A copy saved elsewhere, like Pictures, isn't read: save over this file, or attach the copy and ask for it to be brought in.)
2. Run `python motion-demo/build_racoon.py`. It rewrites the boards, `out/parts/`, and the game's `assets/racoon/racoon_rig.json`, `racoon_atlas.svg` and `closet/<folder>.svg`. It first checks that every Closet item in `content/closet.json` has a drawing and every drawing a line, and stops with a list if not.
3. Ask for the canvas boards to be republished. The game picks up the new JSON the next time it runs.

## In the game

Racoon is a Godot scene, `reading-racoon/scenes/companion/racoon_puppet.tscn` (D-024, "Racoon as a Godot scene"). Open it in the editor to see one node per part. To play a move, select its AnimationPlayer, pick an animation in the Animation panel and press play; edit its keyframes there too.

`build_racoon.py` writes what the scene uses:
- `reading-racoon/assets/racoon/racoon_atlas.svg`: one sheet with Racoon's 19 parts on it, 12 units apart. Godot imports it once, at 2× with mipmaps. (Until 2026-11-17 each part was its own file in `assets/racoon/parts/`; the build removes that folder.)
- `reading-racoon/assets/racoon/closet/hats.svg`, `glasses.svg`, `neck.svg`, `tops.svg`, `paws.svg`: the Closet, one sheet per slot (D-026), so a new hat changes only the hats sheet and no sheet grows too big for a phone. Each is imported the same way; the build writes a new sheet's import settings.
- `reading-racoon/assets/racoon/racoon_rig.json` (version 5): the rig's measurements, every sheet, each texture's box in the drawing, its sheet and its place there, where the cheek fur tufts are, and the colors.

The other files:

| File | What it is |
|---|---|
| `scenes/companion/racoon_puppet.gd` | the scene's script. Its exported properties are his pose (`turn`, `hop`, `squash`, `head_turn`, `raise_right`, `reach_right`, `eyes`, `mouth`, ...). Every frame it turns the pose into where each node goes, as in the motion demo, and adds breathing, blinking, ear springs and eyes that follow the pointer. |
| `assets/racoon/racoon_moves.tres` | his 28 moves as keyframed animations, plus RESET (his rest pose): the 21 for the game's moments and taps, and 7 he plays on his own (walk_around, hop_around, big_jump, look_around, stretch, dance, tail_wag; turn_around was removed in D-029) |
| `scenes/companion/raccoon.gd` | the Control every screen uses: it places the scene and plays its animations (`set_mood()`, `moment()`, `read_along()`, `point_at()`, `talk()`). With `lively` on (Home, the start screen, the Closet) he does a move of his own after 6–11 quiet seconds. Each move's walk and jump shrink to fit the box he's in. |
| `godot/make_racoon_puppet.gd` | builds the scene. With `--animations` it also records the moves into `racoon_moves.tres` from their scripts, which replaces keyframes edited in the editor. With `--add-new` it records only moves the library doesn't have yet. Run it on a scratch copy of the game (instructions at its top). |

Closet items are textures on their own nodes (D-026). Each item of silver tier or higher shines with `closet_item.gdshader`:
- HeadItems › Hat sits on top of his head and bobs with it; violet and finer hats also sway.
- HeadItems › Glasses is a mesh painted round his face.
- NeckItems › Item narrows with his neck.
- ChestItems › Pin rides on his belly.
- Book holds whatever is in his paws.
