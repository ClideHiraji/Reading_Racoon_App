---
type: decision
status: decided
date: 2026-11-18
issue: 35
graphify: submitted
tags: [decision, companion, language, voice, fr-14, fr-20, issue-15]
---

# D-033 Buddies Roco and Rina, and the talk language

**Decision:** each student picks a buddy and a language. The buddy is **Roco** (the boy raccoon) or **Rina** (the girl). The language, English, Filipino or Bisaya, is what the buddy speaks and the menus say. Both are saved with the student's profile. The app is still called "Reading Racoon".

- **Choose your buddy** (`scenes/buddy/choose_buddy.tscn`) opens the first time a student plays: after sign-in (`login.gd`) and from Play on the start screen (`main.gd`). The profile chip on Home opens it again later.
  - It shows two cards, Roco and Rina. Below them are three language buttons and Let's go, which stays dim until a buddy is picked.
  - Tapping a card or a language makes the buddy say a sample in that voice and language. Nothing is saved until Let's go.
  - Opened from Home, it has a Home button and says whether the stars have reached school. The profile chip used to say that line.
  - It has a side-by-side layout for laptops (D-023).
- **Rina is the same raccoon with girl details**, so every Closet item fits both (`racoon_puppet.gd`, `girl`):
  - eyelashes on open, closed and happy eyes, in the eyes' light color so they show on her dark mask;
  - rosier, pinker cheeks;
  - pink inner ears;
  - a pink bow on her head by her left ear. It turns with her head, hides behind it and under a hat, and stays under a halo.
  - `Raccoon` follows the student's pick (`buddy_changed`); the chooser's cards set `buddy` directly.
- **Language:** the buddy's lines (`companion_lines.fil.json`, `companion_lines.bis.json`) and the spoken menu lines (`content/talk.json`, 77 lines in each language) come in all three languages.
  - `GameState.talk(key, args)` and `line(state)` pick the student's language and fall back to English. `{buddy}` becomes Roco or Rina.
  - `Speech.say(text)` with no language now speaks in the student's language.
  - **These stay in their own language:** lesson and test items, hints, answer explanations, and practice lines that hold a reading word (rhyme, catch, match). These follow the lesson (MATATAG bridge, FR-03; issue 15).
  - **These stay in English, read in English:** login (it's before the student is known), and the names of stickers, Closet tabs and filter chips.
  - **Visible labels stay English for now** (Library, PLAY, button words). The Closet's title is the buddy's ("Roco's Closet", "Closet ni Rina"), and the lock screen and reward cards use the table.
- **Voice:** for now it's the system voice. Roco keeps pitch 1.1. Rina speaks at 1.4 and uses a female system voice where the device has one (`Speech.pitch`, `girl_voice`; `GameState.use_buddy_voice()`). Recorded Gemini voices will replace both once a paid key is linked: Zeno for Roco and Cleo for Rina, chosen in the voice lab, `racoon-voice-lab/`.

**Why**
- The user asked for both genders for students to choose from, a girl version of the companion for girl students, and a choice of language. The user chose the details:
  - the language changes the buddy's talk and the menus;
  - the names Roco and Rina;
  - the same raccoon with girl details;
  - the system voice now, recorded voices later.

**Consequences**
- **The Filipino and Bisaya lines are a draft:** a teacher should check them before children see them (issue 15).
- A device with no Filipino or Cebuano system voice stays silent in that language. The bubble still shows the text. Recorded voices would fix this.
- A sentence can mix languages: an English game or world name inside a Filipino line ("Laruin pa ang Adventure para mabuksan ang Rhyme Pop!") is read by the Filipino voice.
- Students who already play see the chooser once, the next time they press Play.
- Tests:
  - `run_tests.gd`, 5116 checks, 0 failed: the three tables have the same lines and %s/%d slots and no emoji; the line files cover every state but the hints; Rina's details.
  - `ui_smoke.gd`, OK: the chooser end to end; picks are saved only on Let's go and come back with the profile; Rina's voice; English fallback.
  - The warning scan is clean.
  - Screenshots: the chooser (phone and laptop), Home and the Closet with Rina, and Rina's scarves and halo (D-031).
- Not committed: the user plays it in the editor first.

**Rejected:**
- A separate girl drawing: every Closet item (52) would need refitting.
- Translating the lessons too: lesson content follows MATATAG (issue 15).
- Waiting for recorded voices: the user chose the system voice now.

Details: [[10-open-issues]] (issue 35)
