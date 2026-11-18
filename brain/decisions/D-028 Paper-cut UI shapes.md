---
type: decision
status: decided
date: 2026-11-18
issue: 29
graphify: submitted
tags: [decision, ui, art, d-009, d-022]
---

# D-028 Paper-cut UI shapes

**Decision:** the UI's boxes are cut from paper, so the game looks livelier and more crafted without losing its calm palette or its layout ([[D-009 Art direction Butuan storybook]], [[D-022 Full UI redesign]]).

- **Hand-cut edges.** Cards, buttons, chips and panels have slightly uneven corners and gently wavy sides (up to 3 px), cut differently for each box. The crisp paper shadow stays.
  - One style box does this everywhere: `ui/paper_box.gd` (`PaperBox`). It takes StyleBoxFlat's settings (colour, corners, shadow, border or top lip, expand margins), so it replaced StyleBoxFlat in `Kit.box`, `ChunkyButton` and the screens that built their own.
  - A button keeps its cut in every state (`cut`).
- **Circles stay round.** A circle or a pill (every corner fully round) is drawn perfectly round, never cut. The user asked for this after seeing blob-shaped discs.
- **Stitches on the special pieces only.** The Home tiles, Practice game cards, the lesson's picture card and album panels (`Kit.card`) are sewn round like felt patches, matching the path's stitched nodes (`stitch`, `ChunkyButton.stitched`). Lists, tabs and answer cards stay plain; stitching everything was too busy.
- **The Home tiles tilt a little** (−2°, +1.5°, −1.5°), like patches pinned on (`ChunkyButton.tilt`).
- **Washi tape** holds the lesson's picture card to the page (`ui/washi_tape.gd`), striped like a banig mat.
- **Paper confetti** on section pages (`ui/paper_confetti.gd`): pale cut-paper leaves, stars, dots, rings and banig zigzags. They're drawn once and never move.
- **A crayon squiggle** under each section's title (`ui/squiggle.gd`).

**Why**
- The user wanted the UI livelier, consistent, soft-coloured and fun, "not just full squares and rectangles or circles", based on research into what children like.
- Children prefer curved contours to sharp angles, from newborns to Grade 8 (2024 study in *Behavioral Sciences*; Bar & Neta).
- Children aged 7–11 liked light colours most, and liked colours more as they got more saturated. So the grounds stay soft and the accents stay bright.
- For ages 6–8: big targets, a picture with each label, a friendly character, one main action per screen (NN/g, 156 guidelines from tests with ages 3–12). The layout keeps all of these; only the material changed.
- Paper is the game's own world. Tearaway built its UI from paper prototypes, and banig mats (stripes, checks, zigzags) give it local patterns.

**Consequences**
- New boxes should use `PaperBox` (via `Kit.box`); code that copies a box from a button or card types it as `PaperBox`.
- Some boxes defined inside scene files are still straight: the lesson's top bar and sheet, the overlay card. Speech bubbles stay straight on purpose, because their tail joins a straight edge.
- Drawing cost: each shape is worked out once per size and drawn as a triangle fan.

**Rejected:**
- Blob-shaped discs: the user wants circles to stay circles.
- Stitches on every card and button: too busy.
- Pastel-tinted Practice cards: card-style buttons are cream paper by design (D-022), and cream discs on cream cards disappeared.
- Moving confetti: it would cost frames on slow phones (D-025) for little gain.

Details: [[10-open-issues]] (issue 29)
