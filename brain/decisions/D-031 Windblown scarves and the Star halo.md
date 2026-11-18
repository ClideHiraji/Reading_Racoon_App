---
type: decision
status: decided
date: 2026-11-18
issue: 33
graphify: submitted
tags: [decision, closet, fr-07, racoon, animation, d-026]
---

# D-031 Windblown scarves and the Star halo

**Decision:** the diamond scarves blow in the wind behind Racoon, with two new designs, and the hats get an animated **Star halo** behind his head ([[D-026 Closet tiers and item art]], FR-07).

- **Starlight ribbon** (neck, diamond, 470 coins): two pink ribbon tails with little white stars, a lilac back that shows when they twist, notched ends and twinkles. Its band and knot are a pink recolour of the River scarf.
- **Comet scarf** (neck, diamond, 470 coins): a long red hero tail and a short one, a gold lightning stripe, a forked end and orange sparks. Its band and knot are a red and gold recolour.
- **Rainbow scarf** (earned, all 40 stickers): its tails blow too, in drifting rainbow colours.
- Neither new scarf is labelled by gender: one leans soft and sparkly, the other bold and heroic, as the user asked for one of each.
- **How the wind moves** ("moving circles", from the user's reference): each point along a tail goes round a small circle, a little later than the point before it, so waves run down to the tip and the tip flicks. The ribbon also twists (narrowing and showing its back colour), the wind comes in gusts, and a bright shimmer runs along it now and then (the diamond shine). Code: `scenes/companion/wind_scarf.gd` (`WindScarf.STYLES`).
- **Star halo** (hat, diamond, 490 coins, `"drawn": "code"`): a golden ring with four little gems and a ring of beads, a star on top that rocks, three small stars travelling round it, twinkles, a breathing glow, and a gentle bob. Our own design: the user's picture was only a guide. Code: `scenes/companion/halo.gd`.
- **Both turn with him** (`racoon_puppet.gd`):
  - The tails leave from behind his neck and blow to your left. They're behind him when he faces you and in front when he turns away.
  - The halo floats behind his head, narrows as his head turns side-on, and is in front of his head when he faces away.
  - Side-on it stands clear of the back of his head (132 units behind his head's middle; his head is 108 to the side), a thin ring like the user's reference shows. At first it was only 34 behind and looked like a line through his head (the user spotted it the same day).
- On the Closet's still cards both are drawn once; the tails are shorter there, so they fit the card.
- The Closet has 52 items, 14 earned.

**Why**
- The user asked for the diamond scarf to wave behind him "like there's a wind", in a girls' and a boys' design, and for an animated diamond halo in the hats, designed by us from their reference.
- Drawing in code (like the pets, D-029) lets the tails and the halo move every frame without new sprite sheets or rig parts. Each is a handful of polygons a frame (NFR-01).

**Consequences**
- A new windblown style is an entry in `WindScarf.STYLES` plus `"wind": "<style>"` on a scarf in `closet.json`; the band and knot still come from a drawing or a recolour.
- A halo replaces any hat (same slot).
- `run_tests.gd` checks: every wind style exists and belongs to a scarf, at least three windblown diamond scarves, the halo is a hat, and code-drawn items are pets or halos.

**Rejected:**
- Copying the reference's halo (a ring with four long spikes and thorny swirls): the user asked for our own design.
- Labelling scarves "for girls" and "for boys": the Closet never labels items by gender (D-026).
- Tails as a drawn sprite animation: fixed frames can't follow his turns or his scarf's position.

Details: [[10-open-issues]] (issue 33)
