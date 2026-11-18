# Lottie bake

`LottiePlayer` (`reading-racoon/ui/lottie_player.gd`) can play a Lottie `.json` live, but
reading, preparing and building every half-frame costs time on the device. For the star
(`AnimatedStar`) that was about 63 ms to load plus 400 ms of frame building on a laptop,
done while a lesson or Home starts, and more on a phone. A bake does that work once, ahead
of time: `bake.gd` saves every half-frame's draw commands as a `LottieBake`
(`reading-racoon/ui/lottie_bake.gd`) next to the `.json`, and the player uses it instead.

| | Live from `star.json` | From `star_bake.res` |
|---|---|---|
| Load | 63 ms (read, parse, prepare) | 21 ms |
| Frame building | 111 half-frames, 400 ms (warm-up 2 per game frame) | none |
| File | 205 KB minified (560 KB indented) | 147 KB |
| Drawing | the same triangles | the same triangles |

Measured on the team laptop, 2026-10-24. Every baked half-frame matches what the player builds
from the `.json` exactly (all 111 compared), so the star looks the same.

## When to bake again

After any change to a baked `.json` (`assets/anim/lottie/star.json`). The unit test
`test_star_bake` fails until you do: the bake keeps the SHA-256 of the file it came from.
Only animations without recoloring use a bake; the hearts are recolored at load and play live.

## How

From the repo root, with Godot 4.7. **If the Godot editor is open on `reading-racoon/`, run it
on a copy** (the project guard hook blocks Godot editor runs next to the open editor, and a
second Godot on the same folder freezes it), then copy `star_bake.res` back:

```bash
"C:\Program Files\Godot\Godot.exe" --headless --path reading-racoon -s ../tools/lottie-bake/bake.gd -- res://assets/anim/lottie/star.json
```

It writes `assets/anim/lottie/star_bake.res` and prints the half-frame count and size. A new
copy of the project needs `--import` once first (run it twice if the first one crashes).
