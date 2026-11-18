---
type: decision
status: decided
date: 2026-11-17
issue: 26
graphify: submitted
tags: [decision, performance, nfr-01, speech, godot]
---

> **Changed 2026-11-18 by [[D-032 A new question stops the voice]]:** a new question now stops the voice at once, on Windows too, and on Windows every such stop (a new question, leaving a screen) runs on a worker thread, so it no longer freezes the game.

# D-025 Performance: no freezes when a child taps

**Decision:** the game must not freeze when a child taps, finishes a lesson or opens a screen (NFR-01). A tour of every screen and moment (`tools/perf/`) found where it did, and each cause was fixed. One fix changes behaviour, and the user chose it: **on Windows, Racoon's read-aloud is never cut off mid-sentence.** A new line, or leaving the screen, lets the current sentence finish (spoken lines go out a sentence at a time), and the next line follows. Android and iPhone cut off at once, as before.

**What was slow, and the fix** (dev laptop; a 2 GB phone is several times slower):

| Cause | Cost before | Fix |
|---|---|---|
| Windows' system voice blocks while it stops a line it's speaking (Godot's Windows text-to-speech empties its queue synchronously). It hit every answer tapped while the question was being read, and every screen that stopped speech. | 210 ms each time | `Speech` (Windows only): a line is spoken a sentence at a time, and a new line drops only the sentences not yet started. It never interrupts, so it never blocks. Read-along word highlighting and `finished` still work. Tried and rejected: calling the voice from a worker thread (it still blocked, broke the end-of-line events, and crashed on exit) and pausing before stopping (still 208 ms). |
| Finishing a lesson opened and closed the event queue file once per event (answers, words, sticker, goal): about 9 ms each on Windows. | 237 ms | `SaveStore.hold()` / `release()`: a burst of events is written in one go. Used by `finish_lesson`, `record`, `learn_words` and the Practice, book and video finishes. |
| `ChunkyButton` (every button) rebuilt its look, about 17 theme overrides, on every property set, several times per new button. | ~5 ms per new button; 13 ms for the Closet's 5 tabs on each switch | Built once in `_ready` inside `begin_bulk_theme_override()`; later changes merge into one rebuild at the end of the frame. |
| First visits loaded the screen's scene, scripts and pictures on the spot. | 70–530 ms | `ScenePreloader` (a child of GameState) loads the 19 screens on a worker thread, one at a time, once the start screen is up; it waits during lessons. It finished in under 2.5 s, and the worst frame meanwhile was 13.5 ms. |
| Racoon: the rig math looked up the head's size and position thousands of times a frame, a new Racoon ran the rig twice, and the circles for his face were rebuilt in GDScript. | rig 2.1 ms per update; ~10 ms per new Racoon | Cached rig measurements and unit circles, a lighter sleeve outline for the shoulder rim, and one update per new Racoon. The rig now takes 1.2 ms. |
| Practice checked each game's unlock state (a search of the question bank) twice per comparison while sorting. | ~50 ms per open | Worked out once per game. |
| Each path node drew its stitched ring as 18 separate anti-aliased arcs. | 56 ms for 40 nodes' first frame | One `draw_multiline` call: 28 ms. |

**Result (worst frame, before → after):**
- finishing a lesson 237 → 15–21 ms
- the Closet 137 → 63 ms, a tab switch 144 → 49–62 ms
- first visits to the games 75–103 → 7–15 ms
- other first visits 74–109 → 21–34 ms
- steady lesson frames 6.6 → 5.3 ms

**Checked on a scratch copy:**
- 4,044 unit checks pass.
- `ui_smoke` passes, and a scan of every script with the debugger on shows no warnings.
- 28 screenshots were compared with the code from before. They are the same apart from Racoon's animation timing and random content (shuffled cards, picked words, confetti).

**Why**
- The children are 6–7 and anxious about mistakes (PRODUCT.md). A freeze right as they tap an answer reads as "it's broken" or "I did something wrong".
- The advanced section plays on Windows laptops, where the voice freeze happened on most quick answers. The regular section plays on 2 GB phones, where every laptop millisecond is several.

**Consequences**
- On Windows, spoken feedback can start up to about 1–2 s after a quick tap: the rest of the sentence being read is heard first. The screen and Racoon react at once. Lines of several sentences take about 0.6 s longer to say (a short pause at each sentence break).
- ~~When a child leaves a screen mid-sentence on Windows, the sentence finishes on the next screen.~~ **Changed 2026-11-17 (the user's choice): leaving a screen stops Racoon's voice at once, on every device.** What he was saying belonged to that screen. On Windows the stop blocks for about 0.2 s, but it happens while the screen changes (measured: Home to the Closet took 400 ms including the stop). Inside a screen, Windows still lets the current sentence finish, so answering in a lesson stays freeze-free. Rejected alternatives: cutting at once on every tap (a 0.2 s pause on each answer on Windows), and keeping today's behaviour. `Speech.cut()` does it; `Speech` notices the screen it was speaking for is gone.
- **Rapid taps can't pile up (2026-11-17, the user's request):**
  - **Every `ChunkyButton`:** a second tap on the same button within 0.45 s, or a tap on any button within 0.2 s of another, does nothing. A quick double tap can't open a screen twice, buy twice or start two things at once. Only mouse presses are counted, because a phone touch reaches a button as one.
  - **Android Back and Escape:** a second press within 0.45 s does nothing.
  - **Racoon on Home:** a tap is taken only once he has finished his last reaction and what he's saying, and 0.7 s after the last tap. A move he's doing on his own can still be cut into. Six taps 80 ms apart gave one reaction; the next was taken after he finished (2.6 s).
  - **Lessons:** answer tiles already lock after a tap (`_locked` in each task), so nothing changed there.
- Screens stay loaded after the first background load, which uses more memory but well within 2 GB.
- `tools/perf/perf_tour.gd` can measure the game again after future changes.

**Not done (smaller, or phone-only):**
- Library and Watch draw 6–8 ms of render CPU a frame on the laptop (many rounded, shadowed cards).
- The very first screen takes about 0.5 s during startup, behind the splash.
- Shader warm-up for phones' GPUs; none of this has been measured on a real phone.

**Rejected:** keeping instant cut-off on Windows (the user chose the sentence finish); see the table for the two voice workarounds that didn't work.

Details: [[10-open-issues]] issue 26, [[D-024 Racoon redesign]], [[Windows text-to-speech blocks when it stops]].
