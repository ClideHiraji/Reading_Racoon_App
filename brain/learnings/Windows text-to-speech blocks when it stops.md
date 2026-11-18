---
type: learning
date: 2026-11-17
status: confirmed
tags: [learning, godot, performance, speech, windows]
---

# Windows text-to-speech blocks when it stops

On Windows, Godot's `DisplayServer.tts_stop()` blocks the main thread for about 210 ms while a line is being spoken. So does `tts_speak(..., interrupt = true)`, which stops first. Starting a line is instant, and stopping when nothing is speaking is free. Android's and iOS's voices stop asynchronously.

**What happened:** a profiling tour of the game ([[D-025 Performance no freezes]]) found a 210 ms freeze on Windows whenever a child answered while the question was still being read. The feedback line interrupted the question.

**What didn't help:**
- calling the voice from a worker thread: still 246 ms, the end-of-line events stopped arriving, and Godot crashed on exit. (That moved every call. Moving only the stop works; see below, 2026-11-18.)
- `tts_pause()` before `tts_stop()`: still 208 ms

**What works:** never interrupt. Hand the voice one sentence at a time, keeping the rest in your own queue. A new line drops the sentences not yet started and lets the current one finish. Since the system voice only ever gets a new sentence when it's idle, it never has to purge one being spoken. Word highlighting keeps working if each sentence's offset in the whole text is added to the boundary positions. Add a fallback that moves on if the voice goes quiet without reporting the end.

**Update 2026-11-18 ([[D-032 A new question stops the voice]]): run only `tts_stop()` on a worker thread.**
- The game's thread pays 0.1 ms; the stop takes about 0.45 s on the worker. Worst game frame meanwhile: 19 ms.
- Keep every other voice call (`tts_speak`, `tts_is_speaking`) on the game's thread, and start no new line until the worker is done. The voice's events still arrive: they come deferred to the game's thread.
- The stop needs the window's messages handled to finish. At exit, waiting on the thread hangs the game, so keep calling `DisplayServer.process_events()` until it's done, with a time limit.
- **Starting is not instant after all:** a line that starts from quiet costs one slow frame, 130–175 ms on the dev laptop, whatever the voice, pitch or speed. `tts_speak()` returns at once, and Godot's Windows voice starts it later, on the game's thread. Earlier tests timed only the call, which is why they called starting instant.

**Also found the same day:**
- Opening and closing a file to append one line costs about 9 ms on Windows (antivirus scanning on close). Append a burst of lines in one open ([[D-025 Performance no freezes]]).
- A Control that sets many theme overrides should wrap them in `begin_bulk_theme_override()` / `end_bulk_theme_override()`, and rebuild once, not on every property set.
- `ResourceLoader.load_threaded_request()` loads scenes on a worker thread without hitching the game; `change_scene_to_file()` then finds them loaded.
- `-d` is needed to see GDScript warnings in headless runs ([[Headless test runs hide GDScript warnings]]).
