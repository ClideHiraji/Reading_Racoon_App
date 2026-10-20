---
type: learning
date: 2026-10-17
tags: [learning, godot, tooling]
---

# The Godot MCP `add_node` tool can't set Vector2 properties

Passing `position: {x, y}` to `mcp__godot__add_node` reports success, but the property is silently dropped from the `.tscn` file.

**Fix:** after adding nodes, edit the `.tscn` text directly for Vector2, anchors and layout values, then run the project to confirm. Godot scenes are plain text, so this is safe.

Also: Godot runs headless for these tools and prints harmless "RID allocations ... leaked at exit" errors.

Related: [[D-005 Game engine Godot]].
