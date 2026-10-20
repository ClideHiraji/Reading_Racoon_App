---
type: learning
date: 2026-10-20
tags: [learning, godot, ui]
---

# Godot containers reset a child's rotation and scale

What happened: a picture card was given `rotation_degrees = -2.5` inside a CenterContainer, but it never tilted. Containers call `fit_child_in_rect()` on every re-layout, which sets the child's rect and resets its rotation and scale.

**So:** to tilt or scale something that lives in a container, wrap it in a plain `Control` that copies the inner node's minimum size, and rotate the inner node (see `reading-racoon/ui/picture_card.gd`). Tweens on `scale` of a container child work only until the next re-layout.

Also: positions read inside a `resized` callback can be stale after the parent re-sorts. Read `position` again right before using it (the path's auto-scroll bug).

Related: [[D-009 Art direction Butuan storybook]], [[Godot MCP cannot set Vector2]]
