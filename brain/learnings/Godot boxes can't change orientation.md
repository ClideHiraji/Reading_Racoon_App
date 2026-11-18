---
type: learning
date: 2026-10-24
status: active
tags: [learning, godot, ui]
---

# Godot boxes can't change orientation

Setting `vertical = false` on a `VBoxContainer` (or `true` on an `HBoxContainer`) fails at runtime with "Can't change orientation of VBoxContainer", and the box stays as it was.

**Do instead:** when a row has to stack on a phone and sit side by side on a laptop, make it a plain `BoxContainer` and set `vertical` from `Kit.landscape()`. In a `.tscn`, use `type="BoxContainer"` with `vertical = true`, and have the script `extends BoxContainer`. Used for the tap-choice task, the story page, the Library reader and the Watch player ([[D-023 Laptop layouts Back and safe areas]]).
