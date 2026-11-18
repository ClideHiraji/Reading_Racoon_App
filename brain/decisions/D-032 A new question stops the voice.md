---
type: decision
status: decided
date: 2026-11-18
issue: 34
graphify: submitted
tags: [decision, voice, tts, nfr-01, fr-20, d-025]
---

# D-032 A new question stops the voice

**Decision:** when a new question shows, whatever Racoon is still saying about the last one stops at once, on every device. This applies in a lesson, after a lesson's story, in Practice, and in a book's or a video's questions. It changes [[D-025 Performance no freezes]], which on Windows let the sentence being spoken finish whenever a new line came, within a screen.

- `Speech.new_question()` cuts the voice if it's speaking. It's called:
  - in `lesson.gd`: `_next()` and `_after_story()` (a story's reading stops when its question starts)
  - in `practice_round.gd`, before each item's prompt
  - in `reader.gd` and `player.gd`, before each question's prompt
- Everything else stays as D-025 set it: within a question, a new line (a hint, "Great job!") still waits for the current sentence on Windows, and leaving a screen still stops the voice at once.

**Why**
- The user noticed the voice running on into the next question: on Windows a new line waited for the current sentence, so the last question's words played over the new one.

**Consequences**
- ~~On Windows the cut blocks for about 210 ms, just before the new question shows.~~ **Optimised the same day (the user asked):** on Windows the stop runs on a worker thread, so a cut costs the game 0.1 ms instead of a 210 ms freeze. Leaving a screen uses the same cut, so its 0.2 s stop is gone too. Android and iPhone stop without a freeze anyway.
  - The new line starts once the stop is done, about 0.15–0.4 s later (`Speech._pump` waits for `_stopper`).
  - Only the stop runs on the thread; every other voice call stays on the game's thread, and the voice's events still arrive. Checked live: 5 of 5 words highlighted and `finished` on the line after a cut.
  - Closing the game while a stop is running used to hang (the stop needs the window's messages handled). `Speech._exit_tree()` now handles them until the stop is done (at most 2 s); the game exits cleanly (exit code 0).
  - **Still there:** starting any line from quiet costs Windows' voice one slow frame on the game's thread (130–175 ms measured, whatever the voice, pitch or speed). That's inside Godot's own Windows voice code, every line pays it, and GDScript can't move it. Recorded narration (planned, `speech.gd`) would remove it.
- The lesson already waits up to 8 s for Racoon to finish before moving on (D-021), so the cut only matters when a line runs past that, or when a story or story peek was still being read.

**Rejected:**
- Cutting every new line at once on Windows: a 0.2 s freeze on every quick tap (word cards, choices), the reason D-025 chose the gentle queue.

Details: [[10-open-issues]] (issue 34)
