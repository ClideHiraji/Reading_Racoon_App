---
type: decision
status: decided
date: 2026-10-26
issue: 24
graphify: submitted
tags: [decision, racoon, art, animation]
---

# D-024 Racoon redesign

**Decision:** Racoon becomes **option C, "Little reader"**, from the canvas "Racoon redesign options" (board "C · Little reader").

- **Look:** Mochi's big round head on a small bean body, a thick ink outline with soft shading, grey-violet fur, a bandit mask, a ringed tail and the teal river scarf.
- **The book:** he holds an open book, which ties him to reading.
- **The drawing:** on the same 400 × 400 grid as today's Racoon.
- **What it replaces:** the paper cut-out Racoon (D-009, D-022). This settles the Racoon item left open in issue 24.
- **Source:** `reading-racoon/tools/racoon-art/make_racoons.py`.

**How we got here, all on 2026-10-26:**
1. I drew four style options (A Mochi, B Bean plush, C Little reader, D Sticker) after the Dribbble reference "Think & Play – Quiz Game Characters".
2. The user then shared their own 3D character (glasses, orange star tee, green shorts) and I drew it in 2D twice. The first pass felt creepy; the second was friendlier.
3. The user discarded that design and chose C.

**Not built yet.** The game keeps today's Racoon until the plan below is approved.

## Plan (proposed)

### 1. Art: front-view parts

The game only needs the front view (Racoon always faces the child). The generator exports one SVG per part with a tight view box, plus `parts.json` giving each part's place on the 400 × 400 grid and its pivot. The parts:

- **Body:** ground shadow, tail, feet, body and belly.
- **Arms:** left and right, hanging at his sides as the user drew them (2026-11-16, second edit), plus four poses for when he holds the book (a Closet item since 2026-11-16):
  - holding the open book
  - waving, with the book tucked under the other arm
  - both up, with the book put down
  - paw on chin, with the book in the other paw
- **The book:** its own part, so it can move with the arms.
- **Head:**
  - head base: ears, head, brows, mask, muzzle
  - eyes: open, looking up, closed (blink), happy ^^, sleepy
  - mouths: "w" smile, open, big open, flat to one side, small "o"
- **Neck:** nothing by default since the user's 2026-11-16 drawing. The teal river scarf is a Closet item.
- **Closet items:** see part 4.

### 2. Godot: the same Racoon API, drawn from textures

`scenes/companion/raccoon.gd` keeps its API (`mood`, `set_mood()`, `outfit`, `follow_saved_outfit`), so none of the 15 places that show him change.

- **Rasterising:**
  - Each part is rasterised at the size it's shown with `Image.load_svg_from_string()`, so it's sharp at any size. Checked on 2026-10-26: Godot 4.7 draws these SVGs faithfully, gradients included, in 4–6 ms for a whole character on a laptop.
  - One static cache per (part, size).
  - The start screen's warm-up can pre-rasterise the common sizes.
- **Layers:** back to front, each a child `Node2D` drawn once and moved, never redrawn per frame (the 2026-10-26 optimization):

  | Layer | Moves for |
  |---|---|
  | ground shadow | scales with the hop |
  | tail | rotates about its base for the wag |
  | feet | — |
  | body | breathing squash |
  | book and arms | pose swaps |
  | scarf | — |
  | head: base, eyes, mouth, glasses, hat | bob, tilt, nod |

- **New motion:**
  - an idle **blink**: the eyes swap to closed for about 0.12 s every 3–6 s, on a timer
  - a **nod** for encourage
  - a page turn on the book now and then, while reading

### 3. Moods (all six are used by the game)

| Mood | Eyes | Mouth | Arms and book | Motion |
|---|---|---|---|---|
| idle | open, blinking | "w" smile | holding the book | breathing, tail wag |
| happy | open | open | holding the book up | one hop |
| celebrate | happy ^^ | big open | both up, book down | two hops with a tilt |
| encourage | open, brows up | smile | one paw waves | nod twice |
| thinking | looking up | flat, to one side | paw on chin | head tilt |
| sleepy | closed | small "o" | book drooping | slow breathing, "z z" |

The canvas already shows idle, happy, thinking and sleepy.

Since 2026-11-16 the book is a Closet item. Without it, the "Arms and book" column uses his arms as drawn, hanging at his sides, with the same motion (the motion demo shows how they move); the book poses apply only while he holds it.

### 4. Closet

All 16 items are refitted to the new body and head, and the book is added (17 items). Item ids and prices stay the same, so saved profiles keep working (FR-07).

- **Hats (5):** sit between the ears. The salakot is already tested on the canvas.
- **Neck (5):** none is worn by default since 2026-11-16. The teal river scarf stays free and owned from the start; the other scarves, the bow tie and the lei are bought as before. Profiles already wearing the scarf keep it on.
- **Glasses (3):** sit over the mask.
- **Pins (3):** on his chest, above the belly, so the book doesn't cover them.
- **In his paws (new slot, 1):** the open book. Proposed: free and owned from the start, like the river scarf. Holding it switches his arms to the book poses.

### 5. Sizes and speech bubbles

Option C is drawn on today's square grid, with his feet in the same place. So his boxes on all 15 screens can stay as they are, and the speech bubbles only need a check, not a redo. His bigger head may need bubbles moved a little on Home, the map and the start screen.

### 6. Checks

- **Unit test:** every mood with every Closet item builds without errors, and the cache hands out one texture per (part, size).
- **Smoke test:** the Closet try-on test is unchanged.
- **Screenshots:** every screen in portrait, landscape and with a notch, compared against today's.
- **Performance:** per-frame cost stays about 0.02 ms per Racoon; measure the first rasterisation.
- **Cleanup:** delete the old drawing code in `raccoon.gd`.

### 7. Order of work

Each step ends with screenshots for the user to review.

1. Export the parts. Show idle Racoon in the lesson and on Home.
2. The six moods, the blink, the book and the arm poses.
3. The 16 Closet items.
4. Check every screen, phone and laptop.
5. Tests, screenshots, notes (D-022, issue 24), and the manuscript's screens (§3.4.2.4).

## Considered: a 3D Racoon (2026-10-26)

The user asked whether C could become 3D and keep its cartoon look. Yes:
- **The model:** C is built from simple round shapes (a sphere head, a bean body, capsule limbs, a curved tail), which suits 3D. It would be modelled in Blender (installed on the user's laptop) or with an image-to-3D tool.
- **The look:** a toon (cel) shader gives soft two- or three-tone shading, and an "inverted hull" outline keeps C's thick ink line.

There are two ways to use it in the game:

1. **3D-rendered 2D (recommended if we go 3D).** Render the model in Blender, from the same front camera, into the same parts as part 1 above: the body, each arm pose, the book, the head with each set of eyes and mouth, and each Closet item.
   - The game's plan (layers, cache, moods) stays exactly the same.
   - It still costs almost nothing per frame on low-end phones.
   - Only the art source changes, from hand-drawn SVG to renders. Renders are PNGs, so they'd be made at the largest size used, and scale down cleanly.
2. **Real-time 3D in Godot.** Import the model as glTF, with a rig and animations, and show it in a small 3D viewport on each screen. Closet items attach to bones, and every movement can be animated.
   - It's the most alive option.
   - It adds a 3D render pass on every screen, which is heavier on Android 8 phones with 2 GB of RAM.
   - Rigging and animation are a big job, against the November 2026 deadline (open issue 11).

**3D model, 2026-10-26** (`tools/racoon-art/racoon_3d.py`, Blender 5.0): C built from simple shapes measured off the 2D drawing, with toon shading, an ink outline, a front-projected face texture, and an idle and a happy face. The user asked for a loop in their laptop's Blender: seven rounds of build, compare with the drawing, review, test in the game, and adjust ([[Compare 3D renders with 2D art in one shared frame]]).
- **Matches the drawing:** 95.7% of the outline overlaps, up from 91.6% in round 1. In drawing px: the ears within 4.4, the pupils within 1, the book 0.5, the feet 2, the tail tip 6 and the scarf 9.
- **Light enough:** 35,918 triangles, or 57,696 with the outline shell (round 1 had 304k); each view renders in about 1.5 s.
- **In the game:** swapped into Home, a lesson and Practice on a scratch copy, he reads well at every size, and the bolder outline suits the UI.
- **Where 3D differs:** the muzzle stands out from the face, the tail's rings wrap at an angle, and from behind the scarf reads as a thick ring.
- **Not yet:** no rig, arm poses or Closet items; only the idle and happy faces.
- **Files:** `out/3d/` holds the renders, `checks.json`, `metrics.json`, the review and in-game sheets, and `racoon_C.blend`, which opens in the toon look with the moods as Outliner collections ([[Blender opens files in Solid shading]]). `loop/round.sh` reruns a round. Canvas boards: "C in 3D" and "C in 3D · the loop".

Not decided. The 2D plan above stands until the user chooses; the model makes option 1 (rendered parts) ready to try.

## Motion demo: the 2D drawing moving in 3D space (2026-10-26)

The user found the companion's movement "too bland and boring". They asked whether the 2D drawing could act as if it were in 3D: turn around, point, come up to the screen to talk. To show that it can, I built an interactive demo on the canvas.
- **Where:** board "C · Racoon in motion (2D demo, press Play)", source `tools/racoon-art/motion-demo/Motion.dc.html`.
- **The game isn't changed.**

- **How he turns:** each part of the flat drawing has a place on his round head and body ([[Turn a flat 2D character by putting its parts on round shapes]]).
  - Face parts slide around the head and squeeze near the edge.
  - The muzzle and nose stick out, so they show in profile.
  - The tail, book, feet, arms and scarf knot turn about his middle, and each is drawn in front of or behind the body.
  - At rest he matches the 2D drawing exactly.
- **What it shows:**
  - a fake-3D head turn
  - a full turn-around, his head leading and his tail trailing
  - pointing at PLAY: eyes first, then his head, then a stretchy arm
  - walking up to the glass, knocking ("tok!") and talking with a moving mouth
  - four tap reactions: giggle, spin, peekaboo, jump
  - eyes and head that follow the pointer
- **Revised the same day, from the user's review:**
  - **The book is gone from the demo.** His paws hang at his sides, and peekaboo covers his eyes with his paws. The 2D drawing and the "C · Little reader" board still have the book.
  - **The ear movement was reworked:**
    - They sit a little forward on his head, so the near ear travels with his face in a turn, instead of the face sliding under still ears.
    - Seen from the side they stay at least 70% wide, like cones. Before, they thinned to spikes.
    - They're springy: they trail behind turns, flop on jumps and landings, fold back during peekaboo, perk up when he's happy or curious, and twitch now and then while he's idle.
- **Parts to edit:** every layer of the demo's Racoon is exported for the user to edit in Figma, Inkscape or Illustrator. They're in `tools/racoon-art/parts/`, made by `motion-demo/export_parts.py`:
  - a layered SVG
  - one SVG per part
  - `parts.json`, with each part's place on the grid and its pivot
  - Canvas board: "C · Racoon's parts".
  - This is the export in part 1 of the plan above, done from the motion demo's drawing.
- **Checked:** every pose and move was rendered with the canvas's own runtime in headless Chrome, started by real clicks and pointer events ([[Headless Chrome runs animation frames only once]]).
- **For the game:** the same works in Godot with Node2D parts. A small script places each part from his turn and tilt every frame (about 30 points), so it stays cheap on low-end phones.
  - Closet items fit the same way: hats sit on the head, and glasses go on the face like the mask.
- **Limits:** the side and back views are computed, not drawn. They read well, but an artist's own side view would be cleaner.
- **Rules from the spec still apply:**
  - He stays calm while a child reads, and acts on Home, at results, or when a hint helps (FR-14).
  - He entertains with movement, not chat ([[06-game-design]], companion guardrails).

This changes the trade-off in "Considered: a 3D Racoon": the 2D drawing can turn too, so turning around is no longer a reason to pick 3D renders.

## The user's own redesign, drawn in Inkscape (2026-11-16)

The user redrew Racoon by hand in Inkscape, in `tools/racoon-art/parts/racoon_C_inkscape.svg`, and asked for the demo to match it. Changes from the exported parts:
- **No scarf and no ground shadow.**
- **Arms:** stretched out to his sides, with dark paws and hand-drawn outlines.
- **Body:** taller and bean-shaped, with a cream bean-shaped belly.
- **Head:** the head and face sit about 4.5 px higher.
- **Outlines:** 5 px on the head, ears and tail (7 px before).
- **Tail:** its rings are reshaped.

**The drawing now drives the demo.** `motion-demo/build_racoon.py` reads the user's shapes from that file and places them on his round head and body; the demo no longer draws its own Racoon ([[Build a puppet from the artist's file, not from code]]).
- To change him: edit the Inkscape file, then run `python build_racoon.py`. Nothing writes to the user's file.
- Only his depth isn't in the drawing: the head's radius, how far forward the ears sit, and how far the tail curls behind him. These are three constants at the top of the script.
- It also writes the 21 parts to `out/parts/`: one SVG each, `parts.json`, and `racoon_rest.svg` with all of them together. The canvas board "C · Racoon's parts" shows them.
- The exports from before the user's edit moved to `parts/before-inkscape-edit/`.

**How the new parts move:**
- **Arms:** they sway as he breathes, fly up when he hops, press down when he lands, and swing low when he walks. To point, knock, wave or cover his eyes, an arm swings round its shoulder and stretches, keeping the paw's size. Turned toward you, an arm shortens to its paw. "Ta-da" throws both arms up.
- **Tail:** a centre line was fitted to the drawn tail (it covers 95.6% of it). Every point of the outline and rings rides on that line, so the tail keeps its drawn shape as he turns and curls behind him.
- **Belly:** only the part of the patch facing you shows as it slides round his body.

**Checked:**
- At rest, the demo matches the drawing except for 0.1% of pixels, all thin edge slivers.
- 36 poses and every move were rendered with the canvas runtime in headless Chrome, started by real clicks.

**Second edit, saved 16:20 the same day** (the user's copy in Pictures, attached in chat): the arms now hang down at his sides, the foot outlines are thinner (4.8 px), the head has small cheek tufts, and the body and tail rings are touched up.
- **Now the drawing the build reads:** it was copied into `parts/racoon_C_inkscape.svg`. The 10:52 version is kept as `parts/before-inkscape-edit/racoon_C_inkscape_2026-11-16_1052.svg`.
- **Rig fixes for any arm pose:**
  - An arm's direction is now measured from the sleeve toward the paw, where before it assumed the arm pointed sideways.
  - An arm never drops past hanging straight down, so it can't swing in across his body.
  - Moves set arm poses as angles ("raise to 23° above level" for "ta-da"), so they work whether the arms are drawn out or down.
- **Checked:**
  - At rest, the demo matches the new drawing except for 0.12% of pixels, all edge slivers.
  - 24 poses and every move, with and without the Closet items.
  - With the book, his hanging paws already sit at its edges.

**From the user's review of the motion demo, the same evening:**
- **Ears turn in 3D.** The user found the ears "a little bit off" in "Look around". Both were always drawn behind the head, so the ear swinging toward the front sank behind the dome.
  - Now, while his face is turned toward you, that ear also draws in front of the head. It's shown down to a line that slides from the dome's edge to the ear's base as it comes forward, and the base blends into the fur.
  - In a head turn the ears lag a little and catch up, swinging round the head, instead of leaning sideways together.
  - Seen from behind, both stay behind the head.
- **Arms stay joined to the body.** A lifted arm's root used to cut the body's outline and leave gaps at the shoulder; arms over the face left lines in the chest.
  - Once an arm swings away from its drawn pose, its drawn outline is hidden near the shoulder.
  - Wherever the root pokes out of the body, it gets a rim matching the drawn outline (4.4 px inside the edge).
  - At rest nothing changes: the demo differs from the drawing in 0.15% of pixels, edge slivers.
- **The drawing wasn't changed:** both fixes are in the rig, so they keep working after the user's next edit.
- **Tail in front of the arms from behind.** The user asked why an arm showed in front of the tail when he turned around. The arms' drawing order only knew "behind the body" or "in front of it". Facing away, his tail is nearer to you than his hanging arms, so an arm further back than the tail now draws behind it (a slot between the body and a nearer tail).

**Racoon in the game: animations for the game's moments (same evening).** The user asked for more animation, based on the game. A second interactive canvas board, "C · Racoon in the game", rebuilds the laptop lesson screen at its real size (1280 × 720, D-023), with Racoon in his 200 px box at the foot of the left column and his bubble above him.
- **Everything is the game's own:**
  - the questions (pa1-01 to 03: rhymes with cat, bee and star)
  - his lines (`content/companion_lines.json`)
  - the hints and explanations, built the way `HintText` builds them
  - the rules: a heart lost per wrong try and one back per right answer (FR-13); a hint after a wrong first try (FR-14); the answer and why on a sheet after a second; Racoon's Rescue when the hearts run out
- **Ten moments, each with its game mood:**

  | Moment | Mood | What he does |
  |---|---|---|
  | Lesson starts | happy | a wave and the intro line |
  | Reading the question | calm | his eyes follow each word as it's lit, with a small nod; no words of his own |
  | Right answer | happy | a hop and a paw pump |
  | Wrong, first try | thinking | eyes up, paw on chin, the hint, a point at the question |
  | Wrong again | encourage | a gentle nod and a point at the right picture |
  | Racoon's Rescue | encourage | a surprised start, then arms up; the hearts come back one by one |
  | Level up | celebrate | a spinning jump, with the banner and confetti |
  | Lesson complete | celebrate | three claps and a little dance, with the star |
  | Waiting for an answer | helps | points at the speaker, which bounces |
  | Time to rest | sleepy | the kind goodbye, a yawn and a stretch, then asleep, z z z |

  The child can also answer the question on the board by tapping a picture. While the child thinks, he now and then glances at the pictures without a word.
- **Shared Racoon:** the board runs the Motion board's own Racoon code, with the lesson screen and these moves added on top. `build_racoon.py` builds both boards, so a fix to Racoon reaches both.
- **Proposals, not yet in the game:**
  - the "Waiting" nudge line ("Tap the speaker to hear it again.") isn't in the line library yet
  - the idle glances
  - showing the arms up and out for a stretch (straight up hides them behind his head)

**Decided the same day: the scarf and the book come back as Closet items** (FR-07). The user chose this over leaving them out. His default look is the drawing: no scarf and no book. The plan above is updated to match (parts 1, 3 and 4).
- **River scarf:** stays in the Closet, free and owned from the start, but no longer worn by default. Profiles already wearing it keep it on.
- **Open book:** a new Closet item, with a new slot for things he holds. While he holds it, his arms take the book poses in part 3.
- My proposals, not yet confirmed by the user: the book is free and owned from the start like the River scarf (it's what makes him the reading Racoon); the new slot is called "In his paws"; pins move to his chest.
- The game is unchanged until the plan is approved. (Approved and built later that day: see "In the game".)

**Drawn the same day, at the user's request,** in `tools/racoon-art/parts/racoon_C_closet.svg`: an Inkscape file whose bottom layer links the user's drawing as a locked reference, so the items can be edited in place.
- **River scarf:** a teal band with a light wavy "river" stripe, tied in a knot with two fringed ends. Ink outlines match his body.
- **Open book:** an orange cover, cream pages with lines of text, and a teal bookmark ribbon.
- **In the motion demo:** "Try on from the Closet" buttons put each item on with a reaction ("My river scarf!", "Story time!").
  - **The book:** his paws hold its edges. It lifts for "ta-da" and jumps, hangs from one paw when he points or knocks, covers his face for peekaboo, and goes edge-on, then behind him, as he turns.
  - **The scarf:** the band narrows with his neck as he turns, and the knot travels round it.
- **Checked:** 24 poses and every move wearing them, plus the buttons themselves. Plain Racoon at rest is unchanged.
- **Built:** `build_racoon.py` reads this file too (never writes it) and exports `closet_river_scarf.svg` and `closet_open_book.svg` to `out/parts/`. The parts board shows them as dashed "Closet item" cards.

## In the game (2026-11-16)

At the user's request ("can you put it in the game"), the new Racoon replaces the old one on every screen. Nothing is committed yet: the user plays it in the editor first.

- **How he's drawn:** `scenes/companion/raccoon.gd` is rewritten inside. Its API stays (`set_mood`, `mood`, `outfit`, `follow_saved_outfit`, `hop`/`tilt`/`squash`), so every screen that shows him works unchanged. It's the motion demo's rig, ported to GDScript:
  - `build_racoon.py` also writes `assets/racoon/racoon_rig.json` (117 KB, short lines): 27 part textures as SVG, the rig's measurements, the colors, and the Closet items, with the scarf in all three colors.
  - Each part is rasterised once per size he's shown at, and cached and shared by every Racoon on screen. The face decals, arms, tail and scarf are warped meshes; the ear fronts are clipped polygons; a small shader clips the face to his head.
  - Part 2 planned layers drawn once and only moved. The rig moves points inside the parts, which moving a layer can't do, so he's redrawn while he moves (about 1.3 to 1.6 ms per frame on the dev laptop) and 20 times a second when idle.
  - In the editor he's drawn at rest, with no work every frame.
- **The lesson's moments (FR-14, FR-13; `lesson.gd`):**
  - a wave with the intro line
  - reading the question along: he waits for the wave to end, then his eyes follow the prompt's words with a small nod, without a word
  - the hint (a paw on his chin, then a look at the question)
  - the answer (he points at the right card or letter)
  - Racoon's Rescue and winning it
  - level up
  - a silent point at the task after 20 s on one question ("waiting"; the nudge line is still only a proposal)
  - Lesson complete uses the celebrate mood, which is his clapping dance
  - His mouth moves while a bubble shows a line.
- **Home:** he waves with "Hi! Shall we read today?", and a tap makes him giggle, spin, peek or jump while the bubble says the hello line.
- **Closet (FR-07):** the user's go-ahead covered the proposals, so they're built: the open book is free and owned from the start, in a new slot "In his paws", and pins sit on his chest.
  - New profiles wear nothing. Older saves keep their scarf on and get the book.
  - The tabs show the icon above the name, so five tabs fit a phone (and the laptop's right column).
  - Item cards draw a still Racoon (`still`), so a screen of cards costs nothing per frame.
  - Hats, glasses, the bow tie, the lei and the pins are drawn in code, fitted to his new head and chest, and follow his turn.
- **Checked on a scratch copy:**
  - 4,044 unit checks pass, including new Closet checks: the defaults, the book slot, and older saves.
  - `ui_smoke` passes.
  - Screenshots: Home, the lesson's hint, answer and lesson complete on a laptop, and the Closet on a phone and a laptop.
  - Films: the first seconds of a lesson, and all 24 moves (with and without the book and scarf).
  - Eight poses match the canvas demo.
- **Not checked:** a real phone (look and speed). `ui_shots` stopped at the lock screen because the real clock was after hours (the test doesn't fix the time; unrelated to Racoon). `content_e2e` needs the Laravel server.

**Fixed after the user played it:**
- **The arm's outline is joined to the body's (2026-11-16).** The drawn arm outline is an open band with no line across the arm's rounded top, which sits inside the body. When the arm swung, that top poked out unlined and the band's ends faded short of the body. Godot now draws the canvas demo's rim: a line just inside the sleeve's edge, cut where the arm goes into the body (its outline pulled in to the inner edge of its line), so it runs on into the body's outline. `build_racoon.py` exports each arm's rim width and sleeve index, and the body's line width. Also, part textures get `fix_alpha_edges()`, which removed a dark hairline round the top of the arm.
- **A raised paw never slips behind his head (2026-11-17).** The arm's layer (behind the body, under the head, or in front of the head) was judged from the arm's hanging pose, and "in front of the head" needed a paw well above the shoulder. So:
  - pointing while turned put the reaching arm behind his body and head
  - the paw pump went behind his cheek
  - the paw on his chin dropped behind the head just before clearing it

  Now an arm that points counts as in front of him (he faces what he points at), and an arm whose paw end overlaps the head (the paw and the end of the sleeve, each as wide as the arm) is drawn in front of the head. The root by his shoulder doesn't count, so it stays under his jaw and the clap keeps both paws on one layer. The same rule is in the canvas boards (version 43) and `raccoon.gd`.
- **Checked:**
  - shoulder close-ups in eight poses
  - six pointing poses, the same on the canvas and in Godot
  - board traces of every moment's arm layers
  - close-ups of the board moments
  - a lesson filmed in Godot
  - all 24 moves
  - 4,044 unit checks and `ui_smoke` pass

## Racoon as a Godot scene, animated with AnimationPlayer (2026-11-17)

The user asked for him to be "modeled in game" and animated with the game engine's own animation, so he can be opened, shown and edited in the Godot editor. They chose this over a flat Skeleton2D cut-out rig, which would have lost the 3D turn.

- **The parts are files:** `build_racoon.py` writes each part of the drawing to `assets/racoon/parts/<part>.svg` (27 files). Godot imports them at 2× with mipmaps, so they stay sharp large and smooth small. `racoon_rig.json` keeps only the rig's measurements and each part's box.
- **The scene:** `scenes/companion/racoon_puppet.tscn` (root `RacoonPuppet`, script `racoon_puppet.gd`) has one node per part:
  - Shadow
  - Body: Tail, Book, ArmLeft and ArmRight (each with Fill, Rim and Outline), FootLeft, FootRight, Torso, Belly, ChestItems, ScarfBand, ScarfKnot and NeckItems
  - Body › Head: EarLeft and EarRight (each with Inner), MuzzleSide, Skull, Face, HeadLine, EarFronts, Muzzle, Nose, Mouth and HeadItems
  - Body › Head › Face (clipped to the head by `racoon_face_clip.gdshader`): BrowLeft, BrowRight, Mask, Eyes and Blush
  - Parts that only move are textured quads, and parts that bend (tail, arms, brows, mask) are meshes. All are Polygon2D. The eyes, blush, nose, mouth, ear fronts, rims and the code-drawn Closet items are drawn by the script on their own nodes.
- **The pose is properties:** the root's exported properties, in groups Body, Head, Arms, Spot on screen and Closet. They are `turn`, `hop`, `squash`, `head_turn`, `head_up`, `look_x`, `raise_right`, `reach_right`, `reach_right_to`, `eyes`, `mouth` and so on, in degrees and drawing pixels. Every frame the script turns them into where each node goes (the same 3D rig) and reorders the nodes as he turns.
- **The moves are animations:** an AnimationPlayer with `assets/racoon/racoon_moves.tres`. It holds 21 animations (idle, look, point, greet, read, happy, thinking, hint, encourage, answer, rescue, rescue_won, level_up, celebrate, nudge, sleepy, asleep, giggle, spin, peek, jump) and a RESET pose.
  - Each keys the pose properties, so it plays and can be edited in the editor's Animation panel.
  - Moves aimed at something on screen key how much he looks or points at it (`look_at_spot`, `point_at_spot`, `read_along`); the game gives the spot when it plays them.
  - With `deterministic` on and the RESET pose, a move that interrupts another blends from where he is (0.18 s), and anything the new move doesn't key settles back to rest. This was checked by cutting a hint off with a jump.
- **What stays in code:** breathing, blinking, the ears' springs and twitches, his eyes following the pointer, and the mouth while he talks. These are reactions, not acted moves. The scarf and book go on or off with a Godot Tween.
- **How the animations were made:** `tools/racoon-art/godot/make_racoon_puppet.gd` builds the scene. With `--animations`, it plays each move's script (the one the canvas boards use) on a pretend clock and writes every step as keyframes, with the move's easing as the keys' transition curve (an overshoot gets an extra key at its peak). After that the `.tres` is the source: edits made in the editor stay unless the builder is run with `--animations` again.
- **`raccoon.gd`** is now a small Control that places the scene and plays its animations. Its API is unchanged (`set_mood`, `moment`, `read_along`, `talk`, `busy`, `outfit`, `react_to_taps`, `still`), so no screen changed.
- **Checked on a scratch copy:**
  - rest and profile renders identical to the code-drawn version
  - all 24 moves filmed through the AnimationPlayer, with and without the book and scarf
  - an interrupted move returns to rest
  - Home, the Closet and a lesson filmed
  - 4,044 unit checks and `ui_smoke` pass
  - the scene opens in the editor without errors
- **Not checked:** playing the animations inside the user's open editor, and a real phone.

## One texture sheet, and a livelier Racoon (2026-11-17)

The user asked why Racoon had so many imported parts, whether they could be fewer without changing how he moves, and for more moves made with Godot's own animation tools, to make him "lively": jumping on the screen, walking around, and more. ("Scream" was read as "screen"; nothing listens to the microphone.)

- **Why there were so many:** each of the drawing's 27 parts was its own SVG in `assets/racoon/parts/`, so Godot kept 54 files (each SVG and its `.import`) and loaded 27 textures.
- **Now one sheet:** `build_racoon.py` packs all 27 parts onto one SVG sheet, `assets/racoon/racoon_atlas.svg` (1012 × 442 drawing units, 12 units apart so mipmaps don't bleed). It imports at 2× with mipmaps, as before.
  - `racoon_rig.json` (version 3) gives each part's place on the sheet, and the build removes the old `parts/` folder.
  - `racoon_puppet.gd` maps each quad and mesh to its part's rectangle on the sheet. The face clip shader reads the head's alpha from its spot on the sheet (`head_uv`) and cuts anything outside the head's box.
  - The scene has 4 resources: the script, the sheet, the shader and the moves.
  - A render at rest matches the 27-file version; the only differences are in the tail's sway, which depends on the time.
- **8 new moves**, recorded into `racoon_moves.tres` by the builder like the others, so each one plays and can be edited in the Animation panel:

  | Move | Length | What he does |
  |---|---|---|
  | walk_around | 10.1 s | walks right, a hop, walks left, looks around, walks home |
  | hop_around | 3.7 s | three hops to one side, then a big one back |
  | big_jump | 2.1 s | a huge jump with a full spin at the top |
  | look_around | 3.7 s | looks left, right and up, ears twitching |
  | stretch | 2.2 s | arms up, standing tall |
  | dance | 3.2 s | side to side, paws up in turn, tail swinging |
  | tail_wag | 1.5 s | a happy tail wag |
  | turn_around | 2.6 s | turns all the way round (shows off his outfit), then a hop |

  - **Walking is keyed too.** Two new pose properties: `steps` (the walk cycle, so his feet step in time with the animation) and `stroll` (how far he has moved sideways, shadow and all). The old walk cycle ran on its own clock.
  - The builder's new `--add-new` option records only the moves the library doesn't have yet, so keyframes edited in the editor stay.
- **His own little life (`lively`).** On Home, the start screen and the Closet's stage, after 6–11 seconds with no tap he does one of his moves on his own. These are mostly looking around and tail wags, and sometimes a stretch, a walk, hops, a dance or a turn, never the same one twice in a row.
  - He waits while a tap reaction plays, and while he's sleepy or asleep.
  - Any tap or click on the screen restarts the wait, so he never acts while the child is busy.
  - Never in a lesson or while a child reads (his guardrails).
- **Taps:** each tap on him on Home plays the next of 8 reactions: giggle, spin, peekaboo, jump, then a dance, hops, a big jump and a tail wag.
- **He stays inside his box.** Before a move, `raccoon.gd` reads from its keys how far it walks and how high it jumps. If that would carry him past the edge of the nearest parent that clips (else the screen), the move is scaled down for this box with `roam` and `rise` on the puppet.
  - His reach was measured in every move: 190 drawing units left, 210 right (the tail mid-turn) and 400 up (paws raised).
  - Where it matters: the Closet's stage on a laptop (walks to 93%, hops to 69%) and on a phone (the big jump to half height).
  - The change eases over the move's 0.18 s blend, so cutting into a walk never makes him jump sideways.
- **Checked on a scratch copy:**
  - the 8 moves filmed, each ending back at rest
  - 40 seconds of `lively`: a move every 7–10 s, and a tap cutting in with a reaction
  - sleepy for 14 s: no moves of his own
  - Home and the Closet, phone and laptop, at the far ends of the walk, the hops and the big jump: nothing cut off
  - 4,044 unit checks, `ui_smoke` and the warning scan (debugger on) pass
- **Not checked:** the user's open editor, a real phone, and whether children find the extra movement on Home distracting.
- **Fixed after the user watched him walk (2026-11-17):**
  - **His arm no longer flickers in front of and behind the scarf when he walks left.** Walking left, his tail sticks toward you. One rule sends an arm further back than the tail behind it (slot `mb`), and his swinging near arm crossed that line every step (18 flips in one walk). `mb` arms were drawn before the scarf, so the arm slipped behind the scarf each time. Now the scarf and neck items are drawn before both arm slots: the arm only ever changes places with the tail, and stays in front of the scarf. As a side effect, when the tail faces you it is drawn over the scarf.
  - **His speech bubble walks with him.** `SpeechBubble.speaker` (set on the start screen, Home and the Closet) moves the bubble by `Raccoon.walk_offset()`, from wherever its layout put it. It keeps 8 px inside its box (the Closet's stage, or the screen). Only sideways: it doesn't jump with him.
  - **The bubble's point always points at him, on every screen.** Each screen used to place the tail by hand, often at the bubble's bottom-left wherever he was. Now the tail is aimed every frame at his head (`Raccoon.speak_point()`), from whichever edge of the bubble faces him: bottom, top, left or right. It stays off the round corners. Screens that don't name the speaker get the nearest live Racoon on the screen (not the Closet's still pictures). Checked on the path, Practice, Memory Match, Today, the pre-test map, a lesson, lesson complete, Home, coming soon, the start screen and the Closet.
  - **His belly no longer covers his outline when he turns.** Turned 45° or more, the belly slid to the body's edge and its white painted over the ink line. `racoon_belly_clip.gdshader` now uses the body's own texture as a mask: the belly draws only where the body is grey fill, not where it's ink or empty.
  - **The little tufts of fur on his cheeks move.** The build finds the two tufts on the head's outline (the outermost point low on each side) and writes them to the rig (`art.cheekFur`). In the game, his head and its outline are a mesh that's fine round the tufts. `racoon_cheek_fur.gdshader` bends each tuft about its root, and a spring per tuft drives it: they flick behind quick turns and hops, droop as he lands, and stir a little on their own (at most ±0.6 rad). Only a shader setting changes each frame, so the fur doesn't keep the rig busy.
  - **Taps:** on Home he takes a tap only after finishing his last reaction and what he's saying, and 0.7 s after the last tap (D-025, "Rapid taps").
  - **Shader colours fixed (a bug since D-024).** In Godot 4, `COLOR` already includes the texture, and the face clip shader multiplied it in again. So his brows were drawn too dark and his mask near-black; they now show the drawing's own colours ([[Godot canvas COLOR already holds the texture]]).

## Why

- **The user chose C:** the book makes him "the reading Racoon", and the thick outline matches the game's bold UI.
- **Children:** a round, friendly face reads at every size the game uses; it was checked at 56 px on the canvas.
- **Less work:** he's on the same square grid as today's Racoon, so screens and bubbles barely change.
- **Performance:** SVG parts rasterised at their real size stay sharp, and moving layers keeps the per-frame cost near zero.

## Consequences

- About 40 part SVGs to draw: moods, arm poses with the book, and the 16 Closet items fitted to the new head.
- `raccoon.gd` is rewritten inside; its API stays.
- The manuscript's screenshots (§3.4.2.4) and its description of the companion need updating.

**Rejected:**
- **Options A, B and D:** the user picked C.
- **The team's 3D design, drawn in 2D:** the user discarded it after two passes.
- **Drawing Racoon in GDScript code:** slow to redraw, and hard to match the art.
- **Importing the SVGs as fixed-size textures:** soft at small sizes. This stays the fallback if runtime rasterising ever looks wrong.

Details: [[10-open-issues]] issue 24, [[D-022 Full UI redesign]], [[D-009 Art direction Butuan storybook]], [[Animate drawn shapes by moving a layer, not redrawing]].
