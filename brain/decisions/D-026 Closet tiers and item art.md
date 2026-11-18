---
type: decision
status: decided
date: 2026-11-17
issue: 27
graphify: submitted
tags: [decision, closet, rewards, fr-07, art, godot]
---

# D-026 Closet tiers and item art

**Decision:** every Closet item (FR-07) belongs to one of five tiers: **copper, silver, violet, gold, diamond**. The tier sets three things:

- how the item is drawn and how it moves (copper is plain and still; diamond is crystal with a rainbow shimmer);
- its card in the Closet;
- how a child gets it.

Some items are earned, never sold. Every item is now drawn art, not code: it lives in the Closet's own Inkscape file, has its own texture sheet in the game, and has one file per item in `out/parts/`.

The user asked for:

- the accessories (book, scarf) separated from Racoon's sheet;
- the shop items turned into files next to the existing ones;
- items "more exciting, beautiful, animated, captivating to buy", ranked in tiers from copper (free or easy) to diamond (very expensive, with one or two earned by a hard achievement);
- research on how games do this.

## The tiers

| Tier | Stars | How it looks and moves | How a child gets it | Coins |
|---|---|---|---|---|
| Copper | 1 | flat colours, one highlight; still | free, or earned with a first step | 0 |
| Silver | 2 | two-tone, patterns and trims; a shine sweeps across every 5 s | a few coins, or earned | 20–40 |
| Violet | 3 | layered, flowers and small gems; a soft glow breathes, the shine comes every 4 s, hats sway | saved up for, or won by playing | 60–90 |
| Gold | 4 | gold leaf, gems, Butuan-gold spirals; a brighter gleam every 3 s and glints that twinkle | lots of coins | 150–250 |
| Diamond | 5 | crystal facets; all of the above plus a slow rainbow drifting over it | the most coins, or a very big goal | 400–500 |

- The stars say the tier without relying on colour. Each card and the reward card show it as a divider in the tier's colour: a thin line, 1–5 stars, a thin line (the user's design, 2026-11-17: no tier word; it replaced a pill with the stars and the tier's name). The selected item shows only its name.
- A child earns about 30 coins on a full day: 15 for a lesson, up to 5 for a game, 5 for a book, 10 for finishing all three goals. So silver costs about a day, violet 2–3 days, gold about a week, and diamond 2–3 weeks.

## The 27 items

| Slot | Copper | Silver | Violet | Gold | Diamond |
|---|---|---|---|---|---|
| Hats | River cap (earn: a lesson) | Party hat 30 · Salakot (earn: World 1) | Flower crown 80 (sampaguita, waling-waling orchid) | Gold crown 220 (Butuan gold) | Star crown 500 |
| Neck | River scarf (free) | Sunset scarf 25 · Mango scarf (earn: today's goals) · Bow tie 35 | Sampaguita lei 70 | Sun medal 180 | **Rainbow scarf (earn: all 40 stickers)** |
| Glasses | Reading glasses (earn: a book) | Sunglasses 40 | Star glasses 85 | Golden hearts 200 | Prism shades 450 |
| Pins | Star pin (earn: 3 days) | Heart pin 20 · Book pin (earn: 5 books) | Balangay pin (earn: 10 Practice games) | Gold rosette 160 | none |
| In his paws | Open book (free) | none | Parol lantern 90 | Golden book 240 | **Crystal storybook (earn: all 5 worlds)** |

- **Earned** items count real reading: lessons and worlds on the path, books in the Library, days played, stickers, Practice games, and days with all goals done. Nothing is random.
- **Two diamonds are earned and two are bought,** as asked. The hard goals are "collect every sticker" and "finish every world".
- **Local touches:** the salakot, sampaguita, the waling-waling orchid, the balangay (Butuan's boat), Butuan gold and the parol ([[D-009 Art direction Butuan storybook]]).

## 12 more items (2026-11-18): sports, builders, explorers, space

The user found the Closet's items leaned toward what girls like (crowns, flowers, hearts, scarves) and asked for more that would make boys want to buy or earn them. The game never labels an item for boys or girls; the catalogue just got wider, with themes many boys love: sports, vehicles, builders, pirates and captains, pilots, heroes, rockets and dinosaurs. Now 39 items, 11 of them earned.

| Slot | Copper | Silver | Violet | Gold | Diamond |
|---|---|---|---|---|---|
| Hats | | Builder's hard hat 30 (a headlamp) | Pirate hat 80 (anchor, gem, feather) | Captain's hat 210 (gold badge, laurels, braid) | |
| Neck | Explorer bandana (earn: 3 Practice games) | Coach's whistle 25 | | | |
| Glasses | | Hero mask (earn: 5 days) | Pilot goggles 75 | | |
| Pins | | Rocket pin 20 | Dino pin (earn: 10 lessons) | | |
| In his paws | | Basketball 40 | | Toy jeepney 230 | Galaxy rocket 480 |

- Local touches: the jeepney, and basketball, the Philippines' favourite sport.
- First drawn by `tools/racoon-art/closet/draw_more_items.py` (code; the .svg files are the source now) into one file each, in his ink style. The hats and paws items have Back views. The mask and goggles leave his eyes showing.

## In the game

- **Files:**
  - Art source: `tools/racoon-art/parts/racoon_C_closet.svg`. It has one Inkscape layer per slot (Hats, Glasses, Neck, Pins, In his paws) and one group per item, labelled with its id. The scarf and book layers are unchanged. A paws item's hidden "Back view" group is what shows when he turns his back.
  - `build_racoon.py` packs every item onto its own sheet, `assets/racoon/racoon_closet.svg` (35 textures, 1112 × 547). Racoon's sheet, `racoon_atlas.svg`, now holds only his 19 parts.
  - `racoon_rig.json` (version 4) lists both sheets and which sheet each texture is on.
  - The build also writes one file per item to `out/parts/closet_<id>.svg`.
- **On Racoon** (`racoon_puppet.gd`): the items drawn in code are gone. Each item is its texture on a node:
  - **Hat** sits on the top of his head, narrows in profile, bobs behind quick moves (the ears' spring), and sways gently from violet up.
  - **Glasses** are a mesh painted round his face, so they slide round as he turns.
  - **Item** (neck) narrows with his neck.
  - **Pin** rides on his belly.
  - Anything in **his paws** takes the book's place and is held by its edges.
  - Silver and up get `closet_item.gdshader` with their tier.
- **The Closet** (`shop.gd`):
  - Cards are sorted copper to diamond. Each has its tier's frame and badge, and from silver up a shine sweeps across it (`ui/tier_card.gdshader`). Gold and diamond frames twinkle; the diamond frame is a slow rainbow.
  - An item to earn shows a lock and "Earn it". Choosing it shows the goal and progress ("Read 5 books: 2 of 5"), and Racoon says it aloud.
  - Trying an item on makes Racoon react by tier: happy, giggle, a turn-around for gold, a big jump for diamond.
- **Colours (fixed the same day):** `closet_item.gdshader` multiplied the texture in twice, so silver and finer items showed darker and more saturated than drawn. They now match `racoon_closet.svg` ([[Godot canvas COLOR already holds the texture]]).
- **Earning** (`game_state.gd`): `earn_progress()` counts from what the save already holds; only Practice games and all-goals days need new counters. `grant_items()` runs after a lesson, a game, a book, a song, on a new day, and when the Closet opens. An earned item appears on the reward card ("New for Racoon's Closet!", with its tier) and is sent as an `item_earned` event.

## Organised: one file per item, a catalogue, a sheet per slot (2026-11-17)

The user asked why the Closet was in one file, and how items would be updated and added. All 27 were in one Inkscape file and one game sheet, and adding an item meant editing GDScript in three places.

- **Art: one Inkscape file per item**, in a folder per slot: `tools/racoon-art/closet/hats/`, `glasses/`, `neck/`, `pins/`, `paws/`. The file's name is the item's id. Each file links Racoon underneath (locked), and draws on a layer named **Item**. `closet/_template.svg` starts a new one, with guides at his head, eyes, neck and chest. `closet/README.md` says how to add or change an item. The old single file is kept in `parts/before-closet-split/`.
- **Catalogue: `reading-racoon/content/closet.json`**, one line per item: name, slot, tier, price, and how it's earned. A scarf is marked `"scarf": true`. A new colour of an item is a line with `"recolor": {"of": ..., "colors": {...}}` and no drawing (the Sunset, Mango and Rainbow scarves). `wardrobe.gd` loads `ITEMS` from it; the scarf lists that were in `raccoon.gd` and `racoon_puppet.gd`, and the scarf colours in the build, are gone.
- **Game: one sheet per slot**, `assets/racoon/closet/hats.svg`... (6, 5, 11, 5 and 8 textures). A new hat changes only the hats sheet, and no sheet grows past a phone's texture limit. The build writes a new sheet's import settings (2×, mipmaps) and removes the old single sheet. Textures are named `<id>`, `<id>.back`, `<id>.band` and `<id>.knot`; the rig is version 5.
- **The build checks the Closet first.** Every catalogue line needs a drawing, every drawing a line, and every recolour an item to copy. Otherwise it stops with a list and writes nothing (tried: removing the River cap's line).
- **Adding an item now:** draw a file, add one line, run `build_racoon.py`. No code.
- **Checked:** the canvas boards are byte-identical. All 27 items render from the new sheets at rest and turned, and the Closet tabs look as before. Unit tests (4,152, now including the catalogue and its recolours), `ui_smoke` and the warning scan pass.
- **The scene builder now saves his head as plain quads.** The game rebuilds the fine mesh round the cheek fur when the scene loads, so `racoon_puppet.tscn` keeps short lines (20,785 characters otherwise).

## Items turn in 3D (2026-11-17)

The user asked for items that look less flat when Racoon moves, especially when he turns around. Before this, a hat only narrowed in profile and showed its front even from behind, and neck items squashed sideways.

- **The build measures each hat and neck item:** how wide it is at every height from his middle (a `profile` in the rig, every 4 units).
- **Neck items (bow tie, lei, medal) wrap round his neck.** Each point of the drawing sits on an oval as wide as the item at that height (his body's depth), turned with his body. As he turns, they slide round and go behind him.
- **Hats turn with his head in two views.** A flat drawing can't show a hat's side, and a full wrap put the drawing's two outlined edges in the middle of the hat at 90°, so it looked split. So:
  - the front turns half as far as he does: its dots, gems and flowers slide, and it narrows toward the turned side and fades round the back;
  - between 84° and 96° it swaps to the back view, which turns the same way.
- **Back views:** the River cap (its strap and opening; the peak points forward) and the Star crown (its star from behind) have their own "Back view" drawings. Symmetric hats show their front mirrored.
- **Shading:** everything wrapped is shaded from full brightness in front to 78% at its edges, so it reads as round. At rest the items look as drawn; they fade only once they pass behind him.
- **Checked:** every hat and neck item filmed at 0°, 30°, 45°, 60°, 80°, 100°, 120°, 135° and 180°. Unit tests, `ui_smoke` and the warning scan pass.
- **Not done:** side drawings, which would make a hat's 90° view truer. Glasses (already painted round his face), pins (on his belly) and paws items (held by his paws) were already 3D and weren't changed.

## Why

- **Research on tier conventions:**
  - Colour-coded rarity is a convention players learn across games, from Diablo and World of Warcraft to today. A higher tier usually means more visual work, not a gameplay advantage.
  - Riot's skin tiers are the clearest model of each tier adding something: more animation, effects and sound (Valorant's Select to Ultra; League's Epic, Legendary, Ultimate, Prestige).
  - Hearthstone gives its rarest, animated "Diamond" cards for collector achievements. That is the model for earned diamonds.
  - Card games make premium cards look premium in layers: a base glow, a moving shine, then sparkles at the top. The shaders follow that.
- **Research on children:**
  - **Fixed prices and earned items, no random rewards.** Children's-code guidance (the UK ICO) singles out randomised rewards and time-limited offers. The FTC fined Epic for purchase "dark patterns". A complaint to the FTC about Prodigy describes premium items marketed to children.
  - The Closet has no real money, no loot boxes, no timers and no "only today" offers. Every way to get an item is shown before the child chooses.
  - Studies of rewards in educational games find they don't harm motivation when tied to the learning itself. So earned items count reading (books, lessons, worlds) rather than time spent.
- **Within the game's rules:** rewards stay personal: no leaderboards, nothing to compare ([[06-game-design]] reward cautions).
- **Effects stay soft:** nothing flashes faster than a slow sweep, everything stays on the item, and the tier never relies on colour alone.

## Consequences

- **Backend gap (not new):** `SyncEventType` (Laravel) accepts only the lesson events. The game's Closet and collection events (`purchase`, `outfit`, `sticker`, `goal`, `book`, `media`, `practice`, `word`, and now `item_earned`) would be rejected by `/api/sync` until it lists them. Recorded in [[10-open-issues]] issue 27.
- **Older saves change in one way:** items a child already bought stay theirs. But the River cap, salakot, Mango scarf, reading glasses and two pins can no longer be bought; they are earned instead.
- **Art to check with children:** the pins are small on the 150 px Closet cards.
- **The manuscript's** reward-shop description (FR-07) can quote the tiers and the earning rules.

**Rejected:**
- **Random rewards (loot boxes, gacha):** not for six-year-olds, and flagged by children's-code guidance.
- **Diamond items only for coins:** the user asked for one or two earned by a hard goal.
- **Keeping the code-drawn items:** they couldn't be edited in Inkscape, and they were too plain to show tiers.
- **One file per item in the game:** the sheet keeps it to one import, the same reason as Racoon's own sheet ([[Pack a Godot puppet's SVG parts onto one sheet]]).

**Sources** (web, 2026-11-17):
- [Color-coded item tiers (TV Tropes)](https://tvtropes.org/pmwiki/pmwiki.php/Main/ColorCodedItemTiers)
- [Loot (video games), Wikipedia](https://en.wikipedia.org/wiki/Loot_(video_games))
- [Valorant skin tiers](https://www.valorant-spind.de/en/valorant-skin-tiers.html)
- [League of Legends skin tiers](https://leagueoflegendstools.com/data/skin-tiers/)
- [Hearthstone card quality (wiki)](https://hearthstone.wiki.gg/wiki/Quality)
- [Hearthstone rewards (wiki)](https://hearthstone.wiki.gg/wiki/Reward)
- [Godot Card FX Kit](https://reeboolabs.itch.io/godot-card-fx-kit)
- [ICO: nudge techniques](https://ico.org.uk/for-organisations/advice-and-services/audits/data-protection-audit-framework/toolkits/age-appropriate-design/nudge-techniques/)
- [ICO top tips for game designers (Mishcon)](https://www.mishcon.com/news/ico-publishes-new-top-tips-for-games-designers)
- [FTC order against Epic Games](https://www.ftc.gov/news-events/news/press-releases/2023/03/ftc-finalizes-order-requiring-fortnite-maker-epic-games-pay-245-million-tricking-users-making)
- [Fairplay's FTC complaint about Prodigy](https://fairplayforkids.org/feb-19-2021-advocates-to-ftc-prodigy-math-game-preys-on-kids-and-families/)
- [Incentives in educational games (ScienceDirect)](https://www.sciencedirect.com/science/article/abs/pii/S0360131514000426)
- [The role of rewards in motivation (ScienceDirect)](https://www.sciencedirect.com/science/article/pii/S095947522400183X)
- [Virtual economy design: sinks and sources (Yu-kai Chou)](https://yukaichou.com/gamification-analysis/economy-design-sources-sinks-confidence/)

Details: [[10-open-issues]] issue 27, [[D-024 Racoon redesign]], [[D-017 Practice Library Watch and collections]].
