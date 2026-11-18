---
type: learning
date: 2026-11-17
status: active
tags: [learning, godot, animation, racoon]
---

# Record coded tweens as AnimationPlayer keyframes

To move a character's code-driven moves (tweens and waits in a script) into Godot's AnimationPlayer without re-animating them by hand, run each move's script on a pretend clock and write every tween as keyframes.

**What happened:** Racoon's 21 moves were scripts of `tw(props, ms, easing)` and `wait(ms)` calls (D-024). `tools/racoon-art/godot/make_racoon_puppet.gd` runs each one with a clock that jumps from event to event instead of waiting. Each tween becomes two keys (its start and end), and a newer tween of the same value cuts the older one where it takes over. The result is an `AnimationLibrary` (`assets/racoon/racoon_moves.tres`) that plays the same timing and can then be edited in the Animation panel.

**How the easing carries over:** Godot's key `transition` is an exponent for its `ease()` curve:
- `1/3` is cubic ease-out, `3` is cubic ease-in, and `-3` is cubic in-out.
- An overshoot ("back") has no transition, so it gets an extra key at the peak: 9% past the target at 59% of the time.

**What else made it work:**
- A value set at once (like a spin's turn snapping from 360° back to 0) needs a key a millisecond later, so the track doesn't animate between the two.
- Animate the node's own exported properties (`.:turn`, `.:hop`), not other nodes, and let a `@tool` script turn them into the drawing. The animations then preview in the editor, and the 3D math stays in one place.
- Turn on the AnimationPlayer's `deterministic` and add a `RESET` animation with the rest pose. When a move interrupts another (`play(name, 0.18)`), anything the new move doesn't key settles back to rest instead of staying stuck halfway.
- Keep things the game supplies at play time (the spot to point at) out of the keys. Key only how much he points at it, and let the game set the spot.
- Keep what isn't acting in code: blinking, breathing, ear springs, and following the pointer.
