---
type: decision
status: decided
date: 2026-11-18
issue: 31
graphify: submitted
tags: [decision, closet, fr-07, racoon, art, d-026]
---

# D-029 Clothes and pets in the Closet

**Decision:** the Closet's pins become **clothes** (T-shirts and dresses), a new **pet** slot adds a little animal that floats by Racoon's head and plays with him, and his slow **turn-around** move is removed. All three were the user's requests (FR-07, [[D-026 Closet tiers and item art]]).

- **Clothes (slot `top`, the Clothes tab with a shirt picture).** 11 items in `tools/racoon-art/closet/tops/`, drawn by `draw_tops.py`:
  - Tees and tops: River tee (copper, earn 3 days), Striped tee (silver 20), Book tee (silver, earn 5 books), Basketball jersey (silver 35), Dino tee (violet, earn 10 lessons), Cozy hoodie (violet 70), Sailor top (violet, earn 10 games), Barong (gold 200).
  - Dresses: Sundress (silver 35), Party dress (violet 85), Filipiniana dress (gold 230).
  - A top is drawn wider than Racoon and **trimmed to his body's outline in the game** (`scenes/companion/racoon_clothes.gdshader`: the belly's clip and the tier shine in one shader). So a shirt fits him in every pose and never covers his outline.
  - Shirts reach his hips (hem near y 350), dresses to above his feet (y 374). The first, shorter shirts showed his tummy below the hem.
- **Pets (slot `pet`, the Pets tab with a bird picture).** 6 pets, drawn in code in `scenes/companion/pet.gd` (`Pet`), in Racoon's ink style:
  - Maya bird (copper, earn 2 lessons), Busy bee (silver, earn 5 games), Blue butterfly (silver 30), Alitaptap, a firefly (violet 75), Little dragon (gold 220), Star sprite (diamond 460, with a rainbow trail).
  - It floats beside his head, bobbing and flapping, and now and then flies over to his other side.
  - **It plays with him:** when he's tapped it does a happy loop with hearts; when he dances, celebrates or jumps it circles his head (in front over his forehead, behind his ears); now and then it lands on his head for a rest; when he's sleepy it sleeps there, with z's.
  - On the Closet's still cards it's drawn once and bigger, since the pet is what the child is choosing.
  - Pets are marked `"drawn": "code"` in `content/closet.json`, so the build doesn't look for a drawing.
- **Pins retired.** The `badge` slot is gone. An old save's pins are dropped when it loads (`Wardrobe.from_dict` already drops unknown items). The seven pin drawings are kept in `tools/racoon-art/parts/retired-pins/`.
- **No turn-around.** `turn_around` is gone from his moves (`racoon_moves.tres`), his ambient list, the move recorder (`make_racoon_puppet.gd`) and the Closet's gold show-off, which is now `dance`.
- The Closet has 49 items, 14 of them earned. Tiers and price bands are unchanged.

**Why**
- The user asked for upper-body clothing instead of pins, "maybe dress for girls", and for a small animated pet beside or above his head "with small interaction to each other".
- Pins were small on his chest and hard to see. Clothes cover his whole body, so the change shows from across the room.
- Clothes span what boys and girls asked for (a jersey, a hoodie, a dino tee, dresses), plus two Filipino formal wear pieces, the barong and the Filipiniana, like the salakot and jeepney (D-009).
- Drawing pets in code keeps the art pipeline unchanged (no new sheet or rig parts), and lets them move freely around his head.

**Consequences**
- A new top is an Inkscape file in `closet/tops/` plus one catalogue line, like any item. A new pet needs a new kind in `Pet.KINDS` and its drawing in `pet.gd` (`tools/racoon-art/closet/README.md`).
- `run_tests.gd` checks: no badge slot, at least 10 tops, every pet kind is in the catalogue, an old save's pin is dropped.
- The orbit moves the pet behind his body by reordering it among the puppet's children; nothing else uses that order.

**Rejected:**
- Keeping pins next to clothes: two chest items fight, and the user asked to replace them.
- Pets as drawn sprite sheets: a new sheet and rig parts for a small floating animal; code drawing is lighter and can animate freely.
- An orbit around his whole body: in the first try the pet crossed his chest and face.

Details: [[10-open-issues]] (issue 31)
