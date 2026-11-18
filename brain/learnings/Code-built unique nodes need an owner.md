---
type: learning
date: 2026-10-22
status: confirmed
tags: [learning, godot]
graphify: submitted
---

# Code-built unique nodes need an owner

`%Name` (and `get_node("%Name")`) only finds nodes whose `owner` is the scene root. A node made in code with `unique_name_in_owner = true` has no owner, so the lookup returns null. Tests that asked the new hub for `%PlayButton` and `%LibraryTile` failed this way.

**Fix:** after building, set the owner on the unique nodes:

```gdscript
for n in find_children("*", "", true, false):
	if n.unique_name_in_owner:
		n.owner = self
```

Two related traps from the same pass:
- A node can be unique in code but not in the `.tscn` (the lock screen's `Disc`), so check the scene file before using `%`.
- A node that is built and never added to the tree leaks; the smoke test only showed it as "ObjectDB instances were leaked at exit". Running with `--verbose` lists the leaked classes, which pointed at Rhyme Pop's word card that had lost its `add_child`.

Seen while building [[D-022 Full UI redesign]].
