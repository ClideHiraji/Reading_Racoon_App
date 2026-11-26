---
type: decision
status: decided
date: 2026-11-19
issue: 37
graphify: submitted
tags: [decision, watch, video, d-017, d-020, d-023, nfr-02]
---

# D-040 Full screen for teacher videos

**Decision:** a teacher video in Watch & Listen can go full screen, and a phone turns sideways for it (the user's choice).

- **Opening it:** a 96 px round button in the stage's bottom-right corner, or a tap on the picture.
- **What it shows:** the same video over the whole player, in its own shape, on dark ink (`Palette.INK`).
  - Playback never stops or starts again. Full screen draws the playing video's picture a second time; the video node stays where it is.
- **Its buttons:** a tap shows a big Pause/Play (160 px) in the middle and a close button (112 px) at the top right, inside the safe area.
  - While the video plays, they fade after 3 s. While it's paused, they stay.
- **Turning sideways:** on a phone (`OS.has_feature("mobile")`), the screen turns to landscape while full screen is open, either way up (`SCREEN_SENSOR_LANDSCAPE`). It turns back to how it was when full screen closes.
  - Laptops and the editor don't turn: the Windows game already fills the screen ([[D-023 Laptop layouts Back and safe areas]]).
- **Closing it:** the close button, Android Back (the player's new `go_back()`), or the video's end, before the quick check.
  - Leaving the player always turns a phone back upright (`_exit_tree`).
- **Only videos:** songs and read-alongs have no full screen, because the words card is the point of them ([[D-017 Practice Library Watch and collections]]).
- **Icons:** `full_screen` and `full_screen_exit`, drawn for the project like play and pause (white strokes on a 512 grid).
- Code: `scenes/watch/player.gd` ("Full screen" part). Test: `tests/ui_smoke.gd`, with `tests/fixtures/wide_clip.ogv`.

**Why**
- The user asked for a full-screen video, with the phone turning sideways.
- The game is portrait, so upright full screen would only widen a 16:9 video from 672 to 720 px. Sideways it fills about 1280 × 720, about 3.6 times the area it has on the stage.

**Consequences**
- Tested on a laptop only. A probe resized the window to 1280 × 720 and back, which is what the game sees when a phone turns: full screen refit and the video played on. The real turn on an Android phone or tablet is untested.
- When full screen closes, the phone starts turning back. During the turn, the player may briefly show its upright layout stretched wide. Check this on a phone.
- `ui_smoke` checks the button, that full screen covers the screen and the video plays on, its own Pause, Back closing it, and the end closing it before the quick check.

**Rejected:**
- Moving the video node into the full-screen layer: a `VideoStreamPlayer` that leaves the tree stops and goes back to 0 s (checked: playing at 0.99 s, stopped at 0.0 after `reparent`).
- Upright full screen on phones: barely bigger.
- The window's own full-screen mode on laptops: the exported game already runs full screen, and in the editor the window would jump.

Details: [[10-open-issues]] (issue 37)
