---
type: learning
date: 2026-10-17
tags: [learning, graphify, tooling]
---

# Graphify doesn't index markdown docs

- After pushing only docs, the Graphify graph for `ClideHiraji/Reading_Racoon_App` had **1 node, 0 edges**, and a search for "BKT" found nothing.
- Graphify builds its graph from **code** (functions, classes, calls, imports, tests) in what's **pushed to GitHub**. Local unpushed work is invisible to it.
- It re-indexed within minutes of the first push.

**So:** to make knowledge retrievable through Graphify, save it as **memory** with `remember`, one fact per note. New notes may wait under Memory › Needs review. Keep the readable version in this vault.

Related: [[D-006 Project brain workflow]].
