---
type: decision
status: decided
date: 2026-11-20
issue: 38
graphify: submitted
tags: [decision, ui, branding, opening, icon, d-028]
---

# D-037 Animated opening and app icon

**Decision:** the game opens with its own animation instead of Godot's logo, and it has its own app icon.

- **The opening** (`scenes/intro/intro.gd`, class `Intro`, about 3.3 s):
  1. A sheet of paper in the boot screen's cream (read from the project setting, so there's no flash).
  2. A mango sunburst opens.
  3. Racoon pops up and waves. It's the live puppet, so it's Rina if the student chose her.
  4. "Reading" and "Racoon" drop in letter by letter, in the start screen's title colours.
  5. The crayon squiggle draws in under "Racoon".
  6. The sheet lifts away like a page, with a hand-cut bottom edge and a soft shadow (D-028), and shows the start screen that was ready underneath.
  - A tap or a key skips straight to the lift.
- **When it plays:** the start screen (`scenes/main.gd`) adds it over itself the first time it opens in a run (`Intro.played`). Racoon's greeting waits until the sheet has lifted, so the voice never talks over the opening.
  - It doesn't play in test or debug runs (`--no-intro`, `--profile`, `--scene`, `--shot`).
- **No Godot logo:** `application/boot_splash/show_image=false`, so the boot screen is plain cream.
- **App icon:** `assets/brand/app_icon.svg` is Racoon's head and shoulders, from the user's own drawing (`tools/racoon-art/parts/racoon_C_inkscape.svg`), on a mango rounded square with soft rays. It's set as `config/icon`.
  - It's used for the phone launcher, Android 12's own launch screen, and the Windows `.exe`.
  - `tools/racoon-art/brand/make_icon.py` rebuilds it from the drawing, keeping every line short.

**Why**
- The user asked for an animated opening with a logo and the app name, then a transition, rather than Godot's default look.
- An overlay on the start screen, not a separate intro scene: the start screen is already built and warming up underneath, so the lift reveals it with no scene change mid-animation.
- Tweens, not an AnimationPlayer: it's a one-off, code-built sequence like the rest of the game's UI.

**Consequences**
- It costs about 3.3 s on the first screen of a run; a tap skips it.
- Game scripts stay warning-free.
- **Tests:**
  - `run_tests.gd`: plays once per launch; test runs skip it; it's under 3.5 s.
  - `ui_smoke.gd`: a test run opens the start screen without it; added on purpose, it lifts away by itself, and a tap skips it.
- **Checked in captured frames,** portrait and 1280×720 landscape.
  - The sunburst is clipped to the sheet, so its rays don't paint over the start screen during the lift.
- **The editor keeps its own copy of `project.godot` and `export_presets.cfg`.** After these files change on disk, use Project → Reload Current Project, or the editor may save its old copy over them.
- The Android preset's Splash Screen › Background Color should match the boot cream (`#FFF6E0`).

**Rejected:**
- A separate intro scene that then changes to the start screen: the scene change would land mid-transition.
- A static logo as the boot-splash image: it's drawn in window pixels, so its size wouldn't match the animation's canvas units, and it would jump at the handoff.
- Godot's default icon: it shows Godot's robot on the phone and in Android 12's launch screen.

Details: [[10-open-issues]] (issue 38), [[D-028 Paper-cut UI shapes]], [[D-024 Racoon redesign]]
