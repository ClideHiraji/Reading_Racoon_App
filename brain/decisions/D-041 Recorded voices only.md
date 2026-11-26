---
type: decision
status: decided
date: 2026-11-26
issue: 36
graphify: submitted
tags: [decision, voice, tts, fr-20, d-035, d-033]
---

# D-041 Recorded voices only

**Decision:** The game speaks only with the recorded voices of [[D-035 Recorded buddy voices]]: the student's buddy (Roco or Rina) in the line's language. The device's text-to-speech is gone. A line plays only when every sentence of it is recorded in that voice and language; otherwise it stays silent, with its words still on screen (the user's choice).

- `scripts/autoload/speech.gd` has no `DisplayServer.tts_*` calls left, and `project.godot` no longer turns on `audio/general/text_to_speech`.
- No fallback ever crosses over: not to the other buddy, not to another language (Bisaya never borrows a Filipino voice), and not to the device.
- A new line replaces the one playing. Leaving a screen or a new question stops it at once, as before (D-032).
- **Read-along (FR-20):** a recorded page lights its words by spreading each sentence's words over its clip, since the recordings carry no word timings. An unrecorded page lights them at a steady pace, silently. The Library's "Read to me" starts by itself only when the book's first page is recorded.
- The lesson's speaker button shows only when the question is recorded.
- `Speech.has_line(text, language)` tells a screen whether a line would be heard.
- Practice lines built from templates ("Pop the balloon that rhymes with %s!", "Catch the word: %s!") were changed to say the item's own question or the word alone, so they use recordings the voice lab already lists.
- The buddy's pitch and the "female voice" name hints are gone. `GameState.use_buddy_voice()` now sets only `Speech.buddy`.

**Why**
- In play-tests the device voice was often a woman's for Roco. Android voice names don't say a voice's sex, so `FEMALE_HINTS` couldn't tell. It also talked over the recordings: on Windows a cut line kept speaking for about 0.4 s while it stopped on a worker thread.
- The HP laptop has English voices only, so Filipino and Bisaya lessons were silent there anyway, or read by an English voice.

**Consequences**
- **Not recorded yet: 937 sentences per buddy (1,874 clips).** That's 586 lesson, test, book and video sentences plus 351 answer words. The voice lab's `manifest.json` already lists them (kinds `content` and `word`). At about 100 sentences a generation, that's about 19 AI Studio batches. Until then, lessons, tests, books and videos are silent.
- Word Catch (Practice and lesson) needs its words recorded to be playable.
- Spoken chip names ("Soft", "Loud", the language names) are silent unless recorded.
- Tests: `ui_smoke` checks that an unrecorded line is silent and stops the line before it, an unrecorded read-along paces itself, and the device voice setting is off.

**Rejected:**
- Device voice for lessons until they're recorded: still the wrong gender on Android, and two voices in one lesson.
- A paid Gemini TTS key to record everything now: the user chose AI Studio's free tier (D-035).

Details: [[10-open-issues]] (issue 36)
