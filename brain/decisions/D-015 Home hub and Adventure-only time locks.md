---
type: decision
status: decided
date: 2026-10-21
issue: 22
graphify: submitted
tags: [decision, ui, access, hub]
---

# D-015 Home hub and Adventure-only time locks

**Decision:** after login (and the first pre-test) the game opens a **home hub** laid out like a mobile game lobby in portrait, and **only Adventure follows the school schedule**. The user approved the wireframe on 2026-10-21 ("Reading Racoon Home Hub Wireframes" design canvas).

- **Hub** (`scenes/hub/hub.tscn`): Racoon stands big in the middle on a woven banig mat over the paper-cut river valley, with slowly turning light rays behind him. Top: the child's name, level badge and level bar, coins, XP, and a cloud that is teal when everything is saved to school. Left: Shop and Today. Right: a "For you" panel with three picks (next lesson or the Big Test, a story, a song, a brain game), which can be hidden. Bottom: Closet, Stickers and Words tabs. A big slanted gold **PLAY** button with the world crest, showing the level and world, glows softly. A dark tip bubble above it gives one hint (coins, chest waiting, minutes left).
- **Play picker** (`scenes/hub/play_picker.tscn`): diamond tiles like a game's mode screen. Adventure is always the big gold diamond in the middle; Library, Practice, Watch & Listen and Big Test sit around it. Locked tiles stay in place, grey with a lock, and Racoon says when they open.
- **Time rules** (`AccessPolicy`, FR-12):
  - **Adventure** (lessons, pre/post-test): unchanged. Open in the class window, locked in other school hours, 30 minutes after school, weekends off unless the teacher opens them.
  - **Practice, Library, Watch & Listen:** open whenever the hub is. No timer during Reading time; otherwise they share a **free-play timer, 45 minutes a day** (`free_play_minutes` in the schedule, teacher can change it).
  - **Hub, Closet, Stickers, Words, Today:** open all day.
  - **Night (9 PM–6 AM, `day_start`/`day_end`):** everything sleeps (lock screen).
  - When Adventure is closed the child stays on the hub and Racoon says "Adventure is resting now, it opens at 7:30 AM". PLAY still works; the gold diamond shows "Opens 7:30 AM".
- **Routing:** start screen and login go to the hub; after the pre/post-test the hub opens; the path's top bar has a Home button instead of the Closet button; the Closet's Back goes home. Every hub button goes through `GameState.open_section(id)`, which applies the section's rule (`HubSections`). Sections not built yet open a "Racoon is still building it" page.
- **Usage events** now also carry `free_minutes` (the server reads `date` and `minutes` and ignores the extra field).

**Why**
- The user: only lessons/Adventure should become unavailable at set times; reading stories and practice puzzles should stay available, and a landing page should show every feature.
- The user asked for the essence of a game lobby (Mobile Legends screenshots) in portrait: a central character showcase, side menus, bottom tabs and one big play button. The layout is borrowed; the art, names and content are our own Butuan storybook look (D-009).
- A shared free-play timer keeps screen time healthy for 6-year-olds without blocking reading.

**Consequences**
- The schedule from `GET /api/access/student/status` may add `free_play_minutes`, `day_start` and `day_end`; until it does, the defaults apply. With no schedule (never synced) everything stays open.
- Practice games, the Library reader, Watch & Listen, Sticker Album, Word Book and Today still need building; until then they show the "coming soon" page.
- Practice does not count toward BKT for now (wireframe question 2 is still open). Curated, downloaded content only: no open internet or YouTube (RA 10173).

**Rejected:** big stacked cards (first wireframe); tap-spots placed around a scene (second wireframe); locking the whole app outside class.

Details: [[10-open-issues]] issues 10 and 22, [[D-009 Art direction Butuan storybook]], [[D-010 Student login and automatic sync]].
