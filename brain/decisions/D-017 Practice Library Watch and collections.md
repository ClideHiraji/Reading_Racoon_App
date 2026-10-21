---
type: decision
status: decided
date: 2026-10-21
issue: 22
graphify: submitted
tags: [decision, practice, library, watch, stickers, words]
---

# D-017 Practice, Library, Watch & Listen and collections

**Decision:** every hub section is now built in the game, following the approved wireframes ([[D-015 Home hub and Adventure-only time locks]]). The open wireframe questions were answered with the defaults the wireframe suggested; the user can still change them.

- **Practice** (`scenes/practice/`): six games that reuse Adventure content from the worlds the child has unlocked (`PracticePool`): Rhyme Pop (balloons), Memory Match (picture and word cards that say their word), Spin the Words, Syllable Train and Story Shuffle (the lesson task screens in a five-round, no-hearts mode), and Word Catch (opens after Level 1). A locked card says what opens it. **Practice never changes BKT**; it pays 2 to 5 coins and logs a `practice` event for the teacher (wireframe question 2).
- **Library** (`scenes/library/`): 8 short picture books written for the app (3 English, 3 Filipino, 2 Bisaya, Butuan settings; placeholders for teacher review, issue 15), filtered by language, easiest first. The reader shows the page's paper scene and pictures; **Read to me** reads the page and lights each word (TTS word boundaries, or a steady pace with no voice) and turns pages by itself; tap any word to hear it. After the last page: two picture questions, the book's credit, a sticker and the book's words.
- **Watch & Listen** (`scenes/watch/`): 4 songs and chants (ABC sounds, rhymes, Filipino letter sounds, counting) and 3 read-alongs of Library books, sung line by line with the words lighting up, then a two-picture check. **Videos** are teacher-picked Ogg Theora files that play only once downloaded to `user://content/` (wireframe question 6: curated and downloaded, no YouTube, no open internet). None are bundled yet.
- **Collections** (`Collection`): a 40-sticker **Sticker Album** in six groups (adventure, books, games, watch, days, goals; one games and one adventure sticker a day, one per new book or song, one per new day, one for finishing today's goals); **My Word Book** (words practiced correctly in lessons, matched in games and met in books, with their pictures; tap to hear; "Practice my words" plays Memory Match with them); **Today** (read a story, play a game, finish a lesson or a song: all three give a goals sticker and 10 coins, plus the days played this week). Nothing is ever taken away; no leaderboards (D-007).
- **Shared pieces:** `Kit` (page, header, chips, cards, reward card), `ReadAlong` (lit words), `Balloon`, `MediaLibrary` (bundled + teacher content), Bisaya voice fallback (Cebuano, else Filipino).
- **Sync events:** `practice`, `book`, `media`, `sticker`, `word`, `goal`. The backend must add them to `SyncEventType` before release (asked of the dashboard session); until then the server rejects and the client drops them.

**Why**
- The user asked to complete the missing features behind the hub.
- Reusing Adventure's content keeps Practice aligned with what the child is learning without extra content or BKT side effects.
- Original placeholder books avoid copyright questions until teachers pick openly licensed titles (StoryWeaver, Let's Read) in the dashboard.

**Consequences**
- Teachers review the 8 books and 7 Watch items (English, Filipino and especially the Bisaya ones).
- The Laravel side still needs: the new event types, a teacher screen to pick books and videos and an endpoint that sends them (the client already reads `user://content/library.json` and `watch.json`), and the schedule keys from D-015.
- "Record yourself reading" (wireframe question 5) is not built.

**Rejected:** counting Practice toward BKT; streaming videos online; giving stickers for every game (the album would fill in a week).

Details: [[10-open-issues]] issue 22.
