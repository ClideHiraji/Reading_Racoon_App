---
type: learning
date: 2026-10-20
tags: [learning, godot, ui]
---

# Newer emoji render as boxes on Windows 10

What happened: Godot draws emoji through the system font fallback (Segoe UI Emoji on Windows). 🪙 coin (Unicode 13) and 🛟 ring buoy (Unicode 14) showed up as boxes with hex codes; older emoji like 💰 ⭐ 🐱 rendered in color.

**So:** while emoji are placeholder art, use emoji from Unicode 12 or older, and check a screenshot (`tests/ui_shots.gd`) after adding new ones. Android phones on old OS versions have the same limit. Real art replaces them later.

Related: [[D-007 UI direction Duolingo-style path]]
