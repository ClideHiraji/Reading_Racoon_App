---
type: decision
status: decided
date: 2026-10-22
issue: 23
graphify: submitted
tags: [decision, bkt, hearts, lesson, assessment]
---

# D-021 Second try, hints and finished-only progress

**Decision:** changes to the lesson, the hearts and the Reading Adventure, from the user's play-tests on 2026-10-22. A first version had a SKIP button at one heart; the user removed it the same day and set the heart rule below. *(user)* marks the user's own choices.

- **Two tries per question** *(user)*. A wrong first try: that choice greys out and Racoon gives **this question's hint** (always, not only when P(L) < 0.30), then the same question again. A wrong second try: the **answer and an explanation** on a paper sheet, read aloud. **Only the first try is BKT evidence** *(user)*; the second try rides on the same `response` event (`retry_answer`, `retry_correct`, `retry_ms`, `hint`), so the server's BKT replay is unchanged. `low_pl` keeps the thesis's hint trigger (P(L) < 0.30 after a wrong answer) for the study.
- **Hearts** *(user)*: every wrong try costs a heart; every right answer gives **one** heart back (up to three). At zero hearts Racoon's Rescue starts as before (D-004: at most twice, a third time ends the session). The per-skill streak and the refill-to-three on a right answer are gone.
- **No CONTINUE taps** *(user)*. A right answer: the green answer, a short word from Racoon ("High five!"), then the next question by itself (about a second). The test's neutral feedback works the same way. Only the answer sheet stays longer: until Racoon has read the explanation (2.5 to 6 s). The lesson waits while the stop dialog or the story is open. Racoon's Rescue, Level Up and the end of a session keep their cards.
- **Hints and explanations** come from `HintText`: built from each question's data by pattern (rhymes, first sounds, letters, word building, picture words, sentences, story order), in English or Filipino to match the question; story questions and a few others have hand-written `hint` / `explain` in the content JSON. Every lesson question has its own (unit-tested). Placeholder wording for teacher review (issue 15).
- **Finished-only progress** *(user)*. A lesson or test plays on a copy of the model and keeps its events in memory; nothing is saved until it finishes. Stopping halfway, closing the app or a crash leaves no BKT change, events, XP, coins or path progress, and the child plays it again from the start. A session the game ends itself (third Racoon's Rescue) counts as finished, so its flag reaches the teacher.
- **Adventure opens the map** *(user)*. The start screen and login go to the hub; Adventure (hub picks and the Play picker) always opens the map. Before the pre-test, the map shows a **Reading Adventure** card with START at the top and keeps the lesson nodes locked (FR-02). Stopping a test goes back to the map.
- **Test results, then home** *(user)*. After the pre-test or post-test: one bar per reading skill (correct / total), **Great!** or **Practice**, where the path starts and the coins, then **GO HOME** opens the hub. "Great!" means the BKT replay of that skill's answers reaches mastery, the placement rule. The post-test shows the pre-test score too.

**Scoring:** first-try answers earn full accuracy and XP (10), second-try answers half (5). `lesson_end` adds `second_try`. Lesson stamps: green (first try), yellow (second try), hollow (missed).

**Why**
- The user's play-tests: a hint before the answer helps a child work it out; the answer should come with a reason; tapping CONTINUE after every question is a hassle; an abandoned lesson shouldn't count; Adventure should open the map, and the pre-test should end with results and the home hub.
- First-try-only keeps BKT standard (a retry after a hint is not independent evidence) and keeps the server replay (D-008) valid without a server change: the server stores payloads as sent and only checks the event type.

**Consequences**
- Hearts drain one per wrong try, so two wrong tries on one question cost two hearts; right answers earn them back one at a time.
- Hints now follow every wrong first try, not only P(L) < 0.30: this changes FR-14 and the gameplay loop (06-game-design step 6). The P(L) trigger is still logged as `low_pl`.
- Practice, Library and Watch can be played before the pre-test (they never touch BKT); only lessons wait for it.
- Interrupted lessons lose their answers by design; the play-time counter still counts the time.

**Rejected:** a SKIP button (removed by the user); both tries as BKT evidence; hints only below P(L) 0.30; refilling all hearts on a right answer; saving after every answer; starting the pre-test automatically.

Details: [[D-003 BKT level progression]], [[D-004 Heart Recovery rules]], [[D-015 Home hub and Adventure-only time locks]], [[10-open-issues]] issue 23.
