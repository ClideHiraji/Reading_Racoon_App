---
type: decision
status: decided
date: 2026-10-20
issue: 21
graphify: submitted
tags: [decision, ui, art]
---

# D-009 Art direction: Butuan storybook, paper-cut, no emoji

**Decision:** the app looks like a **paper-cut storybook set in Butuan City**, built only with Godot's own UI and 2D drawing (Controls, Theme, StyleBoxFlat, `_draw`, a paper shader) plus SVG icons. **No emoji anywhere.** This keeps the structure of [[D-007 UI direction Duolingo-style path]] and replaces its look.

- **Palette:** warm paper, river teal, mango, leaf, nipa thatch, sunset coral, bay blue, mountain plum (`reading-racoon/ui/palette.gd`). Feedback is leaf green or warm mango, never red.
- **Paper look:** flat colored cut-outs lifted on crisp drop shadows; buttons press flat; a fine paper-grain shader on backgrounds; stitched rings on path nodes; dotted footsteps between nodes.
- **Worlds are real places:** 1 Agusan River, 2 Mango Grove, 3 Bahay Kubo Village, 4 Balangay Bay, 5 Mount Mayapay, each with a layered paper landscape (`PaperScenery`) that heads its section of the path and sits under the raccoon in lessons.
- **Pictures and icons:** white SVG silhouettes from **game-icons.net (CC BY 3.0)**, tinted per object (cat mango, frog leaf, bus mango-deep…), shown on tilted paper "photo" cards. Credits in `reading-racoon/assets/icons/CREDITS.md`; the thesis must credit them too.
- **Raccoon:** redrawn as layered paper pieces with a teal river scarf.
- **Type:** Nunito Black for UI, Andika for anything a child reads.

**Why**
- The user said the first look was generic and "AI slop", and asked for Godot's built-in UI and no emoji.
- Local places give the app its own identity and match the thesis's call for culturally relevant, community-centric content ([[07-curriculum-content]]).
- Emoji render differently per phone and some don't render at all ([[Newer emoji render as boxes on Windows 10]]).

**Consequences**
- Content items name pictures by icon (`"picture": "cat"`); tests fail on missing icons or any emoji.
- Icons are CC BY: keep `CREDITS.md` and add an acknowledgment in the manuscript.
- The `school` picture was swapped for `car` in item vo2-03 (no matching icon).

**Rejected:** bold sticker style, soft clay style; drawing every picture by hand (the user chose a free pack); Kenney packs (they lack most of the needed objects).

Details: [[10-open-issues]] issue 21, [[06-game-design]].
