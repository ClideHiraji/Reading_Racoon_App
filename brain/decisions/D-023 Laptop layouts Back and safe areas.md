---
type: decision
status: decided
date: 2026-10-24
issue: 25
graphify: submitted
tags: [decision, ui, devices, accessibility]
---

# D-023 Laptop layouts, Back and safe areas

**Decision:** the game adapts to the two ways the classes will play (issue 25). The user picked **real landscape layouts** for the school laptops, not the portrait game in a strip.

- **Laptops (Windows, mouse, landscape):**
  - **Canvas:** a landscape window draws the game on a **1280×720** canvas instead of 720×1280, so it fills the screen at full size. The `Screen` autoload switches the canvas, and each screen lays itself out side by side when `Kit.landscape()` is true. A Windows build opens full screen.
  - **Side-by-side screens:**
    - Lesson and practice rounds: Racoon in a column beside the prompt and task.
    - Home: Racoon on his mat, with the tiles and PLAY in a column on the right.
    - Adventure map: Racoon beside the trail.
    - Lesson complete and test results: Racoon left, results right.
    - Story page, Library reader and Watch player: picture beside the words.
    - Today: Racoon and the week beside the goals.
    - Start, login, lock and Closet: two columns.
  - **Wider grids:** Library 3 columns, Practice 3, Watch 2, Words 3, Stickers 7, Memory Match in two long rows.
  - **Tasks that don't fit:** a task that needs more room than the shorter screen has is scaled down just enough to fit (`ui/fit_box.gd`). It never grows, so it can't push the screen off the edge. This also fixed portrait: the three-letter row was 10 px wider than the phone screen and shifted the whole lesson; it now shrinks 1.5% instead.
  - **Mouse:** every button shows the pointing hand. Buttons lift 2 px and brighten under the mouse on desktop builds only.
  - **Keyboard:** the login code can also be typed (letters, numbers, Backspace, Enter).
- **Phones (Android, iPhone):** portrait as before.
  - **Back:** Android's Back button or gesture, and Escape on a laptop, do what the screen's own ✕ or Home does.
    - An open card first takes its safe answer (OK, KEEP PLAYING, the reward's OK).
    - In a lesson, Back asks "Stop now?" first.
    - Only Home, the start screen, login and the lock screen let Back leave the game.
    - `quit_on_go_back` is off.
  - **Notches:** the notch, rounded corners and home indicator are kept clear on every screen (`Screen.insets()`, `Kit.fit_safe()`).

**Why**
- Child's confidence first (`PRODUCT.md`). On a laptop, the portrait layout stretched across the wide screen hid Racoon behind the tiles and cut off the reader, lesson complete and the results. A thin portrait strip would have shown everything at a small size.
- A child pressing Back lost their place: Godot quit the game.
- On notched phones the top bar and Home button sat under the notch.

**Consequences**
- **Two layouts per screen:** every screen now has a portrait and a landscape arrangement to keep working. New screens should check `Kit.landscape()`, and use `Kit.page()` (insets and margins built in) or `Kit.fit_safe()`.
- **Scene files untouched where possible:** the landscape arrangement is made in each screen's script, so scenes the editor has open don't change. The exceptions: the lesson's `TaskHolder` is now a `FitBox`, and the tap-choice task's root is a `BoxContainer` so it can turn sideways.
- **iOS build:** needs a Mac with Xcode and an Apple developer account. Not done.
- **Windows voices:** Windows text-to-speech may have no Filipino or Bisaya voice. Check on the school laptops.
- **Manuscript:** §3.4.2.4 needs laptop screenshots too, and the device list in Chapter 3 should name the Windows laptops.

**Rejected:**
- The portrait game centered in a strip with paper margins. Simplest, but small on a laptop and wastes the screen.
- Scaling the portrait layout to fill the width. It cuts off the bottom.
- Rotating laptops to portrait. Not possible.

Details: [[10-open-issues]] issue 25, [[D-022 Full UI redesign]], `PRODUCT.md`.
