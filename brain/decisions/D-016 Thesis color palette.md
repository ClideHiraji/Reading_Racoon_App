---
type: decision
status: decided
date: 2026-10-21
issue: 21
graphify: submitted
tags: [decision, ui, color, accessibility]
---

# D-016 Thesis color palette

**Decision:** the game uses the user's palette, which is also the thesis palette: **light blue `#74a6cb`, cream `#fefde0`, sunny yellow `#ffc918` and orange `#e9801f`** (`ui/palette.gd`: `BLUE`, `CREAM`, `YELLOW`, `ORANGE`). Text on any colored button is the **dark brown ink `#3a2a1f`**. This updates the colors of [[D-009 Art direction Butuan storybook]]; the paper-cut look stays.

- **Core UI:** cream pages, cards and bubbles; yellow for PLAY, stars and the Adventure diamond; orange for main actions (LET'S READ, Library, "Almost!"); blue for secondary buttons, panels, letter tiles and the sky.
- **Kept:** leaf green for right answers ("Great job!") and nature; the five world accents (river teal, mango leaf, nipa thatch, bay blue, mountain plum) for scenery, world badges and Racoon's teal scarf; a light plum for the Big Test and night overlays.
- **Readable text:** `Palette.text_on(face)` picks dark ink whenever it reaches WCAG 4.5:1 (it does on all four core colors, green, light plum and locked grey); `Palette.readable(color)` darkens colored numbers and titles until they read on cream. Unit tests check both.
- Old names (`MANGO`, `CORAL`, `BAY`) now point at the new colors, so existing code follows; UI that used teal moved to blue, orange or yellow. Scene files and `theme.tres` were updated to the new values.

**Why**
- The user asked whether the palette suits the game, then asked to apply it with dark text on colored buttons, keeping leaf green and the world accents.
- White text fails contrast on all four colors (1.0 to 2.8:1); dark ink passes on all (4.9 to 13.3:1). Grade 1 readers need clear text (NFR-02).

**Consequences**
- The manuscript's screens (§3.4.2.4) should show the new colors.
- New UI should take colors from `Palette` and text colors from `text_on()` / `readable()`, never raw values.

**Rejected:** white text on colored buttons; replacing the world accents with the four core colors (the worlds would look alike).

Details: [[10-open-issues]] issue 21, [[D-015 Home hub and Adventure-only time locks]].
