---
type: decision
status: decided
date: 2026-11-18
issue: 32
graphify: submitted
tags: [decision, racoon, closet, fr-07, animation, d-024, d-026]
---

# D-030 Stiff items in his paws

**Decision:** whatever Racoon holds in his paws (the open book, a basketball, a toy jeepney...) is stiff. It never stretches or squeezes between his paws. When one arm moves away, the item rides in his other paw ([[D-024 Racoon redesign]], [[D-026 Closet tiers and item art]], FR-07).

- **In both paws** (standing, reading, walking, hopping) it keeps its drawn width, centred between his paws, and may tilt a little.
- **In one paw** when his paws move apart or together, or one goes much higher than the other: a wave, a point, a paw at his chin, a dance. It hangs from that paw by its near edge, tipped a little (12 px) at the far end. The handover blends smoothly as the arm moves.
- **Which paw:** the left, unless the left arm is the busy one (its paw is further from where it holds the item). `right_paw_free` in a move still hands it to the left paw on purpose.
- **Tilted, not skewed:** it turns like a stiff card in his plane, then narrows as he turns (`racoon_puppet.gd`, `_rig_frame`). Before, a tilt sheared it, so a paw at his chin turned a ball into a thin diagonal sliver.
- Only the paw holding it is drawn over it when it's in front of him.

**Why**
- The user saw the item stretching when he moved his arms and asked for it to be held in either paw during arm-moving animations.
- Measured with a basketball over all 28 moves, the worst stretch was 74% (peek), 31–32% (hint, thinking) and 10–13% (dance, happy, greet, walk_around). Afterwards: none, apart from the turn's own narrowing.

**Consequences**
- No move needed changing: the puppet decides the grip from where his paws are each frame, so new moves get it for free.
- `run_tests.gd` checks the item keeps its shape in five poses, and which paw holds it in each.
- `f.book` carries `grip` (0 both paws, 1 one paw) and `byRight` (0 left paw, 1 right paw), for tests and tuning.

**Rejected:**
- Adding `right_paw_free` keys to every arm move: many moves, and every new move would need them too.
- Always one paw: reading and standing look right with both paws on the item.

Details: [[10-open-issues]] (issue 32)
