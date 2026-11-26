---
type: decision
status: decided
date: 2026-11-26
issue: 43
graphify: submitted
tags: [decision, practice, lessons, fr-09, d-017]
---

# D-043 Practice games come from the adventure

**Decision:** Every Practice game is also a lesson task in the adventure, so a child recognises it in Practice (the user's request).

- **Rhyme Pop** comes in World 1. Two rhyme questions (`pa1-02`, `pa1-04`) carry `"variant": "rhyme_pop"`, and their answers ride on Practice's balloons (`scenes/tasks/rhyme_pop_task.gd`).
- **Word Catch** comes in World 2. Three "which word says…" questions (`ph2-04`, `ph2-06`, `vo2-07`) carry `"variant": "word_catch"`, and their word cards drift down like Practice's leaves (`scenes/tasks/word_catch_task.gd`).
- **Spin the Words, Syllable Train and Story Shuffle** were already lesson tasks.
- **Memory Match left Practice:** it tests memory, not reading (the user's choice). My Word Book's "Practice my words" still plays it with the child's own words.
- The items stay `tap_choice`, so scoring (BKT), hints, Word Book words and the server are unchanged. Only the look differs: `lesson.gd` picks the scene by `variant` when one exists.
- Speed never decides: the balloons only bob in place, and the word cards settle and wait. A tap answers, mid-fall too (D-007).

**Why**
- The user wanted Practice to replay games the child has met, "not some random ones".

**Consequences**
- `run_tests.gd` checks that every Practice game has items in the adventure, and opens in Practice by the world it's in.
- The pre-test and post-test keep plain cards, so the two tests stay alike.
- The Practice games' moving balloons and leaves stay as they were (a game there may be fast; a lesson's isn't).

**Rejected:**
- All three as lesson tasks: Memory Match would mix memory into a reading score.
- Removing the three from Practice: the user wanted them in levels.
- New task types: a `variant` keeps every other part of the game working as before.

Details: [[10-open-issues]] (issue 43), [[D-017 Practice Library Watch and collections]]
