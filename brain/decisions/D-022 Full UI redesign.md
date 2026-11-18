---
type: decision
status: decided
date: 2026-10-22
issue: 24
graphify: submitted
tags: [decision, ui, design, accessibility]
---

# D-022 Full UI redesign

**Decision:** the game follows the redesign canvas the user reviewed on 2026-10-22 (claude.ai design canvas "Reading Racoon redesign": every screen critiqued and redrawn, with the flows), on every screen **except Racoon**, who stays as drawn until the user picks one of the Duolingo-style options on the canvas.

- **Home merges the Play picker** (replaces the diamond picker of [[D-015 Home hub and Adventure-only time locks]]). Top bar: the child's profile (level and a small level bar), **Today** with three goal stars, coins. Three big tiles: Library, Practice, Watch. One big **PLAY**: yellow for Adventure ("World · Level N"), plum **BIG READING DAY** when the teacher opens the post-test, grey with the opening time when Adventure rests. Bottom tabs: Closet, Stickers, Words.
- **One meaning per color:** yellow = Adventure and PLAY only; orange = the main button on a screen (START, I READ IT!, CONTINUE, Buy); **green = a right answer only** (no green buttons); blue = listening (speakers, Read to me, Pause, chips that are picked); plum = Big Reading Day and night. Languages: English blue, Filipino orange, Bisaya teal.
- **Sizes (NFR-02):** every tap target at least 96 px (48 dp), main buttons 120 px, text at least 22 px, corner radii 12 / 20 / 28.
- **Headers:** the round Home button on a section, ✕ on an activity (it asks first), the title, coins. Games show **round dots** instead of coins: green when right the first time, orange after help, a blue ring on the round being played.
- **The animated star** (the team's `Animated - Star.svg`) plays wherever a star is **earned**: lesson complete, Today's finished goals, the reward card's "goals done" line and the good-day lock screen. Flat stars stay where a star is only a symbol: tabs, goal slots, path nodes, the results footer. It now plays from the team's `Star.lottie` (see below).
- **The animated heart** (the team's `Regain Heart.svg`) fills in the heart slot when a heart comes back after a right answer or Racoon's Rescue (FR-13, [[D-021 Second try hints and finished-only progress]]). Its frames use the lesson hearts' colors (ink outline, coral) so it matches the flat hearts beside it. A lost heart plays the team's `Broken Heart.svg` the same way: the coral heart cracks, its halves fall away and the pale empty heart is left, the rightmost heart first. Regain Heart is timed like the team's `Regain Heart.mp4` (3.25 s, a grey empty heart that fills, bounces and bursts). The still hearts in the row are the animations' end frames, so every heart has one shape. Both hearts and the star play from the team's Lottie files through `ui/lottie_player.gd`, a small Lottie player written for the game: live vector shapes, sharp at any size, no frames. The animated SVG exports had dropped the Lottie files' time stretch (`sr`), which emptied the star and slowed Regain Heart; played from the Lottie, the star pops and bursts and the heart fills, bounces and sparks as designed. Each half-frame is worked out once and shared; a lesson warms the hearts and the star up when it starts, so their first play is smooth on slow phones. Since 2026-10-24 the star is **baked**: `tools/lottie-bake` saves all 111 half-frames to `star_bake.res`, which the player loads in 21 ms instead of 63 ms of loading plus 400 ms of building (laptop), with identical triangles. A test fails if `star.json` changes without a new bake.
- **Screens:** path banner without skill bars; the Reading Adventure card with three skill tiles; flat picture cards that say their word when tapped; story pages that read themselves with the words lighting up; lesson complete shows coins only (XP and % stay in the data). Library chips with language dots and soft language tags; the reader with big words, page dots, round arrows and a big blue Read to me; Watch kinds with icons; the player's stage on the words card with blue controls; Practice as two columns of picture cards, open games first; Word Catch with bigger, slower words; Stickers with picture tabs; My Word Book with picture-and-word cards and a speaker; the Closet with the Home button, picture tabs and a 120 px Buy/Wear button; the login keypad at 100 px keys; the switch-student button 96 px.
- **[[D-021 Second try hints and finished-only progress]] wins** where the canvas differs: no SKIP button, no CONTINUE after answers, no pre-test intro card (the Reading Adventure card on the map instead), the test results keep their bars with Great! / Practice, and the start screen and login go to the hub.

**Why**
- The design critique: tap targets and labels below kid sizes, colors meaning many things (green buttons next to green right answers, yellow everywhere), PLAY needing two steps, crowded headers.
- Grade 1 children mostly can't read the labels yet, so tabs and chips carry pictures and Racoon says their names.

**Consequences**
- `scenes/hub/play_picker.*` is gone; `DiamondTile` stays for the tests.
- XP is still earned and synced, just not shown after a lesson.
- New icons drawn for the game: play, pause, dot, two arrows, glasses, scarf (`assets/icons/CREDITS.md`). The animated star's and heart's source and license must be confirmed before release.
- The star's SVG export of 2026-10-22 was empty (its main layer stayed at scale 0, because the exporter dropped the time stretch); the Lottie file is complete and is what the game plays.
- The manuscript's screens (§3.4.2.4) need new screenshots.
- Not in this pass: Racoon's redesign (options on the canvas) and the Apple-style motion plan on the canvas's Rules board (springs, drag, calm motion), which waits for the user's go-ahead.

**Rejected:** redesigning Racoon now (the user asked to leave him); building the motion plan now (the user said not yet); keeping PLAY as a separate picker screen; one animated star everywhere (too busy where a star is only a label).

Details: [[D-009 Art direction Butuan storybook]], [[D-016 Thesis color palette]], [[D-017 Practice Library Watch and collections]], [[10-open-issues]] issue 24.
