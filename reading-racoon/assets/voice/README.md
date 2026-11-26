# Recorded buddy voices (D-035)

One MP3 per sentence, named `Speech.clip_key(buddy, language, sentence)`: the first 16 hex digits of the
SHA-1 of `buddy|language|sentence`, e.g. `roco|en|Great job!`. `scripts/autoload/speech.gd` plays a line from
these clips when every sentence of it has one; otherwise the system voice reads it.

- Voices: Gemini 3.8 Flash TTS in Google AI Studio (free tier), voice Zeno for Roco and Cleo for Rina.
- Style: a bubbly, playful seven-year-old Filipino boy or girl chatting with a younger friend who loves to read
  and play (English with a light Filipino accent; Filipino from Manila; Bisaya from Mindanao).
- Covered: the buddy's lines and the spoken menus (content/talk.json, companion_lines*.json), names read
  aloud, and login. Not lessons, tests, books or videos (the user's choice, 2026-11-19).
- Made with the voice lab outside the repo (racoon-voice-lab: manifest.py, studio.py, compress.py,
  to_game.py): batches of sentences split at `<long pause>`, loudness evened, mono 24 kHz MP3 at about 44 kb/s.
