# SVG animation to frames

> **The game now plays the team's Lottie files directly** (`ui/lottie_player.gd`, JSON in
> `reading-racoon/assets/anim/lottie/`), so the star and hearts no longer use these frames.
> Keep this tool for animations that only exist as animated SVG. Note that SVG exports can
> drop a Lottie's time stretch; prefer the `.lottie` file when there is one.

Godot can't play animated SVGs (SMIL), so the team's animations are sampled into
PNG frames and played by `ui/frame_animation.gd` (D-022). Run from the repo root,
with Python 3 and Godot 4.7. With `--path reading-racoon`, Godot reads the paths after `--`
from inside `reading-racoon/`. The frame folders in the game are overwritten in place.

**Before you render, play the SVG in a browser.** If a layer stays hidden or at scale 0
there, it will be empty in the game too.

## Star (`AnimatedStar`)

```bash
python tools/svg-frames/smil_frames.py "reading-racoon/assets/icons/Animated - Star.svg" build/star_svg star 30
"C:\Program Files\Godot\Godot.exe" --headless --path reading-racoon -s ../tools/svg-frames/render_frames.gd -- ../build/star_svg assets/anim/star 1.28
```

Then:
- Render the last frame again at scale `3.84` and save it as `assets/anim/star/star_settled.png` (with mipmaps on in its import settings).
- Set `FRAMES` in `ui/animated_star.gd` to the new frame count.

## Heart (`AnimatedHeart`)

The heart is recolored to the lesson hearts (ink outline, coral heart) and rendered at 128 px, its size on screen:

```bash
python tools/svg-frames/smil_frames.py "reading-racoon/assets/icons/Regain Heart.svg" build/heart_svg heart 30 "#000000=#3a2a1f,#ff3e3e=#e9801f,#ff7b7b=#f0a662"
"C:\Program Files\Godot\Godot.exe" --headless --path reading-racoon -s ../tools/svg-frames/render_frames.gd -- ../build/heart_svg assets/anim/heart 0.64
```

Then set the `regain` count in `KINDS` in `ui/animated_heart.gd` to the new frame count. For the original red heart, leave out the color map.

## Broken heart (`AnimatedHeart`, kind `break`)

Recolored to coral and the pale empty heart. `pad=0.3` widens the canvas so the falling halves aren't cut off; its 160 px frames match the heart's size on screen:

```bash
python tools/svg-frames/smil_frames.py "reading-racoon/assets/icons/Broken Heart.svg" build/heartbreak_svg heartbreak 30 "#ff0000=#e9801f,#b9a2a2=#d9cfa2" pad=0.3
"C:\Program Files\Godot\Godot.exe" --headless --path reading-racoon -s ../tools/svg-frames/render_frames.gd -- ../build/heartbreak_svg assets/anim/heartbreak 0.1
```

Then set the `break` count, heart width and center in `KINDS` if they changed (measure the drawn heart in the first frame).

`build/` is scratch space; delete it afterwards. Run `--import` on the project after new frames.
