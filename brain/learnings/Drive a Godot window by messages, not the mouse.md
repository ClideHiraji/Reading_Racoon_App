---
type: learning
date: 2026-11-26
status: confirmed
graphify: submitted
tags: [learning, godot, testing, windows]
---

# Drive a Godot window by messages, not the mouse

To play-test the Windows build automatically, send input to the game's own window and capture that window, instead of moving the real mouse or using screen-control tools:

- **Find it** by title: `FindWindowW(None, "Reading Racoon (DEBUG)")`.
- **Screenshot** with `PrintWindow(hwnd, dc, 3)` (client area, full content). It captures the OpenGL window even behind other windows.
- **Click** with `PostMessageW` `WM_MOUSEMOVE`, `WM_LBUTTONDOWN`, `WM_LBUTTONUP` at client pixels. **Keys** with `WM_KEYDOWN`/`WM_KEYUP` (Escape is Back, F12 the developer menu). **Wheel** with `WM_MOUSEWHEEL`, which wants screen coordinates.
- Run the exported `*.console.exe` with `-- --profile=<name> --fresh`, so the game's prints land in a log file and the real profile isn't touched.

Watch out:
- **Moving targets** (Rhyme Pop's balloons): find them by colour in the same script and click at once; a human-paced screenshot-then-click misses.
- **Timing:** time between tool calls includes the tester's own thinking. Measure speeds with a timed burst of screenshots in one script, never across calls. A read-along looked "5× too fast" until a burst showed the right 0.55 s a word.
- **Small screenshots mislead:** check details (eyelashes, thin borders) at full size before calling a bug.
- **Drag and drop can't be posted.** Godot reads the held button from the real mouse, so every posted `WM_MOUSEMOVE` arrives with `button_mask` 0 and a drag never starts (taps and touch-scroll still work). Instead, run a `-s` script in the window that sends the finger with `Input.parse_input_event` (button and motion events with `button_mask` set) and saves frames with `root.get_texture().get_image()`. Window pixels for a control: `root.get_final_transform() * (ctrl.get_global_transform_with_canvas() * local)`.
- **Godot's mouse position is the system cursor** (`get_global_mouse_position`, `Viewport.get_mouse_position`), not the last injected event. Code that asks "where did the finger let go?" should track it itself: `LetterTile` follows its drag preview, which Godot moves with every pointer event (2026-11-26).

The helper scripts used (`win.py`, `monkey.py`) were scratch files; a monkey test of 3,200 random clicks, Back presses and double-taps ran this way in about 15 minutes.

Seen while bug-hunting the game, [[2026-11-26]].
