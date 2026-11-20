---
type: learning
date: 2026-11-19
status: confirmed
tags: [learning, voice, tts, gemini, audio]
---

# Cut TTS batches by aligning sentence lengths

When many sentences are read in one text-to-speech generation and the audio is cut back into one clip per sentence, **don't cut at the n−1 longest pauses**. Choose all the cuts together so each piece's length fits its sentence, and let longer pauses count as likelier breaks. Keep a piece only if its length is plausible and no other pause would fit its cut almost as well.

**What happened:** in [[D-035 Recorded buddy voices]], Gemini read 100 Filipino lines joined by `<long pause>`.
- Its pauses between sentences came out as short as 0.40 s, while a comma pause inside a sentence was 0.38 s.
- The old cutter took a comma pause as a break. That shifted a run of clips by one line, until a merged piece put them back in step.
- A loose length check (0.45–2.2× the batch's pace) let the shifted clips through, because the neighbouring lines were nearly the same length ("1 sa 4 ang tama!", "1 sa 5 ang tama!").
- In a later batch, a few `<long pause>` tags gave only 0.18–0.30 s. Greedy cutting would have put 91 of 100 pieces in the wrong place; the aligner kept 98.

**How to apply** (`racoon-voice-lab/record.py split()`):
- **Dynamic programming over the quiet gaps (≥ 0.15 s).** Cost = Σ (log(piece length / expected length))² / 2σ², minus a reward for each chosen gap that grows with its length. Expected length = pace × the sentence's letters, with a digit counted as a short word. Re-estimate the pace from the median and run it again.
- **Keep a piece only if:**
  - its length ratio is plausible (wider when both of its cuts are long, clear pauses of 0.6 s or more);
  - moving either of its cuts to another pause would cost more than 2.0;
  - it isn't next to an off piece across an unclear cut.
- **If under 60% of a batch passes, keep none.** Small batches (15 lines) failed this way twice, when the model skipped pauses.
- **Re-recording a few short lines:** don't send them alone. Set each between lines already recorded in the same voice and language, 20–35 lines in all, starting and ending with recorded ones. Read the recorded ones again only to steady the cuts, and don't save them (`anchor:` keys in `studio.py`). That finished Rina's last 16 lines after four failed tries on their own (2026-11-20).
- **To check old clips without the batch's text order:** each clip is an exact slice of its download, so `bytes.find` locates it and gives back the real order.
