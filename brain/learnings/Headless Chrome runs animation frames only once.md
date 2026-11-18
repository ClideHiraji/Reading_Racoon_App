---
type: learning
date: 2026-10-26
status: active
tags: [learning, testing, web]
---

# Headless Chrome runs animation frames only once

With `chrome --headless=new --virtual-time-budget=<ms>`, timers (`setTimeout`) fire on virtual time, but `requestAnimationFrame` runs only once. A page that animates from a frame loop stays frozen in its first frame, so a screenshot after a click shows nothing happening.

Tested on 2026-10-26: after 3 virtual seconds a test page showed `frames=1 timer=yes`.

**To screenshot an animation at a given moment**, give the page a test clock it steps itself:
- Replace `performance.now` with a fake clock.
- Collect `requestAnimationFrame` callbacks instead of letting the browser run them.
- Start the move with a real click or pointer event.
- Loop: move the clock on 16.7 ms, run the collected frame callbacks, then `await` a `setTimeout(0)` so promises and rendering can catch up.
- Stop at the moment you want, and let the screenshot happen.

Each frame is then exact and repeatable. The Racoon motion demo was checked this way: it ran in the canvas's own board runtime, and frames were taken at set times after each click.

Also, render with `--disable-gpu` and a scratch `--user-data-dir`, so the pixels come out the same on every run. See [[Compare 3D renders with 2D art in one shared frame]].

Related: [[D-024 Racoon redesign]].
