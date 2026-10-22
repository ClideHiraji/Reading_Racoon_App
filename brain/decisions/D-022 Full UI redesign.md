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
- **The animated star** (the team's `Animated - Star.svg`) plays wherever a star is **earned**: lesson complete, Today's finished goals, the reward card's "goals done" line and the good-day lock screen. Flat stars stay where a star is only a symbol: tabs, goal slots, path nodes, the results footer. Godot cannot play SMIL animation, so its 46 frames were rendered from the SVG and play at 30 fps (`ui/animated_star.gd`).
- **Screens:** path banner without skill bars; the Reading Adventure card with three skill tiles; flat picture cards that say their word when tapped; story pages that read themselves with the words lighting up; lesson complete shows coins only (XP and % stay in the data). Library chips with language dots and soft language tags; the reader with big words, page dots, round arrows and a big blue Read to me; Watch kinds with icons; the player's stage on the words card with blue controls; Practice as two columns of picture cards, open games first; Word Catch with bigger, slower words; Stickers with picture tabs; My Word Book with picture-and-word cards and a speaker; the Closet with the Home button, picture tabs and a 120 px Buy/Wear button; the login keypad at 100 px keys; the switch-student button 96 px.
- **[[D-021 Second try hints and finished-only progress]] wins** where the canvas differs: no SKIP button, no CONTINUE after answers, no pre-test intro card (the Reading Adventure card on the map instead), the test results keep their bars with Great! / Practice, and the start screen and login go to the hub.

**Why**
- The design critique: tap targets and labels below kid sizes, colors meaning many things (green buttons next to green right answers, yellow everywhere), PLAY needing two steps, crowded headers.
- Grade 1 children mostly can't read the labels yet, so tabs and chips carry pictures and Racoon says their names.

**Consequences**
- `scenes/hub/play_picker.*` is gone; `DiamondTile` stays for the tests.
- XP is still earned and synced, just not shown after a lesson.
- New icons drawn for the game: play, pause, dot, two arrows, glasses, scarf (`assets/icons/CREDITS.md`). The animated star's source and license must be confirmed before release.
- The manuscript's screens (§3.4.2.4) need new screenshots.
- Not in this pass: Racoon's redesign (options on the canvas) and the Apple-style motion plan on the canvas's Rules board (springs, drag, calm motion), which waits for the user's go-ahead.

**Rejected:** redesigning Racoon now (the user asked to leave him); building the motion plan now (the user said not yet); keeping PLAY as a separate picker screen; one animated star everywhere (too busy where a star is only a label).

Details: [[D-009 Art direction Butuan storybook]], [[D-016 Thesis color palette]], [[D-017 Practice Library Watch and collections]], [[10-open-issues]] issue 24.
