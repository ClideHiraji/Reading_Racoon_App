---
type: decision
status: decided
date: 2026-11-19
issue: 36
graphify: submitted
tags: [decision, voice, tts, gemini, fr-14, fr-20, d-033]
---

# D-035 Recorded buddy voices

**Decision:** Roco and Rina speak with recorded voices: Gemini 3.8 Flash TTS's **Zeno** for Roco and **Cleo** for Rina, made in Google AI Studio on the free tier. The system voice stays as the fallback.

- **Played by `Speech.say()`** (`scripts/autoload/speech.gd`).
  - A line is split into sentences, the way the game already splits it.
  - Each sentence's clip is `assets/voice/<key>.mp3`, where the key is `Speech.clip_key(buddy, language, sentence)`: the first 16 hex digits of the SHA-1 of `buddy|language|sentence`.
  - If every sentence of the line has a clip, the clips play in order with a 0.15 s breath between them. Otherwise the system voice reads the whole line, so one line never mixes two voices.
  - `speaking()`, `stop()`, `cut()` and `new_question()` cover the recorded voice too.
  - `GameState.use_buddy_voice()` sets `Speech.buddy`, so the buddy chooser's previews use the right voice.
- **What's recorded:** the buddy's own lines and the spoken menus (`companion_lines*.json`, `content/talk.json`), names read aloud, and login, in English, Filipino and Bisaya, for both buddies. That's 1,465 sentences in all.
  - **Not recorded:** lessons, tests, books and videos (the user's choice). They keep the system voice.
- **Style:** lively and chatty (the user's choice), "a bubbly, playful seven-year-old Filipino boy (girl) chatting happily with a younger friend who loves to read and play". English has a light Filipino accent, Filipino is from Manila, Bisaya from Mindanao. Measured pitch is about 230 Hz, in a 6–8-year-old's range.
- **No names in spoken lines:** greetings say "reader" ("mambabasa" in Filipino, "magbabasa" in Bisaya) instead of the student's name, so every greeting can be recorded (the user's choice). Home's profile chip still shows the name.
  - Lines with a clock time ("opens at 3:00 PM") stay with the system voice.
- **Size:** each clip is mono, 24 kHz, about 44 kb/s MP3, roughly 7 KB a line. Loudness is evened across clips and edges fade over 15 ms. The 169 clips so far take 1.25 MB, and all 1,465 should come to about 11 MB.
  - MP3, not Ogg: for clips about a second long, an Ogg Vorbis file's ~4 KB header made it bigger.
- **Made with the voice lab**, outside the repo, in `racoon-voice-lab/`:
  - `manifest.py` lists every sentence.
  - `studio.py` prepares each batch of up to 50 sentences joined by `<long pause>`, then cuts the downloaded audio at the pauses and checks each piece's length against its sentence.
  - `compress.py` makes the MP3s, and `to_game.py` copies them into `assets/voice/`.
  - `voice_hooks.py` holds the game changes.

**Why**
- The user wanted natural kid voices and chose Gemini's Zeno and Cleo after the voice tests (D-033). They chose the free tier, the AI Studio website, and the lively style.

**Consequences**
- **Partly recorded so far:** 169 of 1,465 sentences, all Roco in English. Every other line still uses the system voice until it's recorded.
- **AI Studio's free limit is about 6 generations a day**, about 300 sentences, so finishing takes about 5 more days. The limit resets at midnight Pacific time, which is 4 PM in the Philippines.
- **Changing a line's wording means recording it again.** The key changes with the text, and the old clip is simply not used.
- Read-along in books (FR-20) still uses the system voice and its word timings.
- **Tests:**
  - `run_tests.gd` (5,119 checks, 0 failed): clip names match the voice lab's, and a known clip exists.
  - `ui_smoke.gd` (OK): a recorded line plays and a cut stops it; a line with an unrecorded sentence falls back; clips are kept per language; the voice follows the buddy.
  - A timed check: a two-sentence line played both clips in 1.91 s, as expected.
  - The warning scan is clean.
- The audio is Gemini output from AI Studio's free tier. It's the game's own lines, with no student data.

**Rejected:**
- Paid API key: the user chose the free tier.
- Qwen3-TTS: free and open, but no Filipino or Cebuano.
- Recording lessons too: the user left them out. Their content also changes after teacher review.

Details: [[10-open-issues]] (issue 36), [[D-033 Buddies Roco and Rina and talk language]]
