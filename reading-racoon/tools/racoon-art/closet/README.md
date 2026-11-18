# Racoon's Closet: one file per item

Every Closet item (FR-07, D-026) is drawn in its own Inkscape file here, in a folder for its slot. The file's name is the item's id. Each file links Racoon's drawing underneath (locked), so you see the fit while you draw.

| Folder | Slot (in `closet.json`) | Where it sits on Racoon at rest (400 × 400 page) |
|---|---|---|
| `hats/` | `hat` | on top of his head: the head's top is at y 74, the ears near (129, 90) and (272, 90); a hat's band sits just above his brows (y ≈ 115) |
| `glasses/` | `eyes` | his eyes are at (158, 169) and (243, 169), 15.6 across; glasses are painted on his face, so they slide round his head when he turns |
| `neck/` | `neck` | under his chin: the neck is at (200, 264); a lei or medal hangs down to about y 310 |
| `tops/` | `top` | T-shirts and dresses, from under his head (y 234) down: a shirt's hem near y 350, a dress's near y 374. Draw it wider than him (x 112–289): the game trims its sides to his body's outline, so it always fits, however he moves |
| `paws/` | `paws` | held in both paws, in the open book's place: 142–260 across, centred at y 323 |

**Pets** (slot `pet`) have no file here: they're drawn in code (`scenes/companion/pet.gd`) and marked `"drawn": "code"` in `closet.json`, so the build skips them. A new pet needs a new kind in `Pet.KINDS` and its drawing in `pet.gd`.

**Windblown scarves and the Star halo** (D-031) are drawn in code too. A scarf with `"wind": "ribbon"`, `"comet"` or `"rainbow"` in `closet.json` keeps its band and knot from its drawing here, and its long ends blow in the wind behind Racoon (`scenes/companion/wind_scarf.gd`; a new style goes in `WindScarf.STYLES`). The Star halo (`"drawn": "code"`, slot `hat`) is `scenes/companion/halo.gd`.

The old pins (slot `badge`, D-026) were replaced by clothes in D-029; their drawings are kept in `../parts/retired-pins/`.

What the game knows about each item (its name, slot, tier, price, and how it's earned) is in **`reading-racoon/content/closet.json`**, one line per item.

## Add an item

1. Copy `_template.svg` into the slot's folder and rename it to the new id, for example `hats/sun_hat.svg`. Use lower case and underscores.
2. Open it in Inkscape and draw on the **Item** layer, where the item sits on Racoon.
3. Add one line to `reading-racoon/content/closet.json`, under `"items"`:
   ```json
   "sun_hat": {"name": "Sun hat", "slot": "hat", "tier": "silver", "price": 35},
   ```
   - For an item that's earned instead of bought, use `"price": 0` and add, for example, `"earn": ["books", 10]`. The kinds are `lessons`, `books`, `days`, `goal_days`, `games`, `worlds` and `stickers`.
4. Run `python motion-demo/build_racoon.py`. It checks that every line has a drawing and every drawing has a line, then rebuilds the game's sheets. The item shows in the Closet the next time the game runs.

To **change** an item, edit its file and run the build again.

## Tiers and prices

| Tier | Looks | Coins (bought) | Earned by |
|---|---|---|---|
| copper | flat colours, one highlight | 0 | a first step |
| silver | trims and patterns | 20–40 | a few days' work |
| violet | flowers, small gems | 60–90 | playing |
| gold | gold leaf, gems | 150–250 | (bought) |
| diamond | crystal facets | 400–500 | one big goal |

The game adds each tier's shine on top. The unit tests check these price ranges.

## A new colour of a scarf (or of any item)

A recolour needs no drawing, only a line that names the item it copies and the colours to swap:

```json
"scarf_plum": {"name": "Plum scarf", "slot": "neck", "tier": "silver", "price": 30, "scarf": true,
  "recolor": {"of": "scarf_teal", "colors": {"#45b8a9": "#b48fd0", "#2a9d8f": "#8e6aa0", "#1d7166": "#684c7a"}}},
```

Add `"rainbow": true` inside `recolor` to turn every gradient into rainbow stripes (the Rainbow scarf).

## Special items

- **Scarves** (`"scarf": true`): label the parts that wrap his neck **Band** and **Stripe**. They narrow as he turns, and everything else (the ends, the **Knot**) travels with the knot. See `neck/scarf_teal.svg`.
- **Paws items**: put what shows from behind in a group labelled **Back view** and hide it in Inkscape. The open book uses its **Cover** for that, and the left and right edges of the Cover are where his paws hold it.
- **Hats** can have a **Back view** group too: what the hat looks like when he turns his back. A hat without one shows its front mirrored, which suits round, even hats (party hat, salakot, crowns). Draw one when the front would look wrong from behind, like the cap's peak; see `hats/cap.svg` and `hats/star_crown.svg`.
- **Hats and neck items turn round him in 3D** in the game. The build measures how wide each one is at every height, so draw them at their true width: a hat as wide as it sits on his head, a lei as wide as it hangs.

## What the build reads

Paths (no arcs: convert them with Path › Object to Path in Inkscape), ellipses and circles, linear and radial gradients, opacity, and the transforms translate, scale, rotate and matrix. Text and images aren't read.

## Where it ends up

`build_racoon.py` packs each slot's items onto one sheet in the game: `reading-racoon/assets/racoon/closet/hats.svg`, `neck.svg` and so on. Godot imports each sheet once, at 2× with mipmaps. `racoon_rig.json` says which sheet each item is on and where.
