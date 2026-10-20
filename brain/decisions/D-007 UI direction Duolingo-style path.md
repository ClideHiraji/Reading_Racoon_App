---
type: decision
status: decided
date: 2026-10-20
issue: 20
graphify: submitted
tags: [decision, ui, game-design]
---

# D-007 UI direction: Duolingo-style path, mixed with kids'-app patterns

**Decision:** the student app takes its structure from Duolingo and mixes in patterns from kids' learning apps (Duolingo ABC, Khan Academy Kids, Teach Your Monster to Read). We take ideas only: no Duolingo art, names or mascot. The app is **portrait 720×1280** (this updates [[D-005 Game engine Godot]], which said landscape).

| Idea | From | In Reading Racoon |
|---|---|---|
| Vertical learning path of round nodes in colored units | Duolingo | Each map level is a world (Sound Forest, Word River, Sentence Hills, Story Village, Reading Castle) with 5 lesson nodes, a chest after node 2 and a trophy |
| Jump ahead | Duolingo | BKT is the real gate ([[D-003 BKT level progression]]). An early Level Up opens the trophy; unplayed nodes become optional bonus nodes. After 5 lessons without mastery, the last node becomes a repeatable practice node |
| Skill crowns | Duolingo | A mastery ring per sub-skill on each world banner; 👑 when mastered |
| Lesson layout: ✕, progress bar, hearts; feedback sheet + Continue | Duolingo | Same. The sheet is green or **soft orange** ("Almost!"), never red, and there's no buzzer |
| Chunky 3D buttons, rounded bold type | Duolingo | `ChunkyButton`; Nunito for the UI, **Andika** (SIL, single-story *a*/*g*) for words children read |
| Lesson-complete stat cards | Duolingo | Stars, XP, accuracy, coins, one dot per answer, confetti |
| Audio first, icon navigation | Duolingo ABC, Khan Academy Kids | Every prompt read aloud (device TTS for now) with a 🔊 replay button |
| Answer on tap/drop, no "Check" step | Kids' apps | Tapping a card or dropping a tile submits |
| Character guide reacting to every answer | Khan Academy Kids, Teach Your Monster | The raccoon's moods + bubble lines from the offline library |
| Heart Recovery as a themed round | — | "Racoon's Rescue": blue background, 3 easy items, hearts refill one by one ([[D-004 Heart Recovery rules]]) |

**Not copied:** leagues/leaderboards (the spec forbids global competition), streak-loss guilt (absenteeism is common), timers, ads, paywalls, red ✗ marks.

**Why**
- The user asked for the app to resemble Duolingo and other kids' apps without copying them.
- Duolingo's path makes progress visible; kids' apps add audio-first, no-reading navigation that 6-year-olds need.
- Reviews of other apps point at fixes we built in: Teach Your Monster feels repetitive (we mix task types), Duolingo ABC can't place a child (our pre-test placement will mark nodes done).

**Consequences**
- Fonts are bundled under `reading-racoon/assets/fonts/` with their OFL licences.
- Emoji are placeholder art. Newer emoji (🪙 Unicode 13, 🛟 Unicode 14) don't render on Windows 10, so stick to older ones until real art lands.

**Rejected:** landscape layout (kept from D-005), a separate "Check" button.

**Updated 2026-10-20:** the look (world names, emoji pictures, flat colors) is replaced by [[D-009 Art direction Butuan storybook]]. The structure above stays.

Details: [[06-game-design]], [[10-open-issues]] issue 20.
