---
type: decision
status: decided
date: 2026-11-26
issue: 42
graphify: submitted
tags: [decision, ui, settings, audio, nfr-02, d-023]
---

# D-042 Settings card

**Decision:** A gear on Home opens a Settings card (`ui/settings_card.gd`). On a laptop the gear ends the top bar, in the corner; on a phone the bar is full, so it sits under the coins. The card has:

- **Voice** and **Sounds** volume: four big chips each (Off, Soft, Medium, Loud), not a thin slider, for small fingers (NFR-02). A pick plays a sample at the new loudness.
- **Graphics: High or Low** (the user asked again after the first version left it out). High draws at the screen's own resolution with smoothed edges. Low draws the game at its base size (720 × 1280, or 1280 × 720 on a laptop), scales the picture up and drops the smoothed edges (`Window.content_scale_mode` viewport, `Smooth.enabled` off). That's lighter for slow laptops and phones, and a little softer.
- **Frame rate: 60 or 30** (`Engine.max_fps`); 30 saves battery and heat. Until one is picked, the game runs at the screen's own rate, as before.
- **Buddy and language:** opens the buddy screen, as the profile chip does.
- **Full screen: on/off:** laptops only.
- **Sign out:** two taps. It does nothing while answers are still waiting to upload (`GameState.sign_out()`); Racoon then says he's still saving.
- **Close game:** two taps, laptops only. A phone or tablet just goes Home.
- **Done:** Back or Escape works too (group `back_cancel`).

Volumes and full screen belong to the device. They're kept in `user://settings.cfg` and applied at start-up by `Screen` (`SettingsCard.apply_saved`). The buddy and language stay in the student's profile (D-033).

**Why**
- The user asked for volume settings, a quick sign-out and exit on a PC, and full screen or resolution control.

**Consequences**
- **No music slider:** the game has no music yet. It comes with the sound work the user put off until later.
- **No window-size list:** the game scales to any window. Full screen on/off and Graphics High/Low cover resolution.
- The first version put the gear under the coins on a laptop too, where it sat on the Watch tile's corner (the user's play-test).
- On a phone or tablet, Done sits beside Sign out (there's no Close game), so the card fits a tablet's 960-unit-tall screen.
- On a laptop the card has two columns, the volumes beside the buttons. In one column it was taller than the 720-unit screen, and the layout audit found Sign out, Close game and Done off its bottom.
- Medium is 80, the loudness from before Settings, so picking it changes nothing.
- The sound effects' old loudness is now "80" on the 0–100 scale, i.e. 0 dB.

**Rejected:**
- A slider for volume: harder for a 6-year-old to hit than a chip.
- Settings inside the profile chip: the user expected a settings button of its own.

Details: [[10-open-issues]] (issue 42)
