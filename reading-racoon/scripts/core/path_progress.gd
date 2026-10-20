class_name PathProgress
extends RefCounted
## Where the learner is on the Duolingo-style learning path (D-007).
##
## Each world (map level) has 5 lesson nodes, a treasure chest after node 2 and a
## trophy. BKT is the real gate (FR-04): when Level Up fires early, the trophy opens
## and unplayed nodes become optional bonus nodes. If all 5 are done without
## mastery, the last node turns into a repeatable practice node.

const LESSONS_PER_WORLD := 5
const CHEST_AFTER := 2
const CHEST_COINS := 15

## "level" -> {"done": int, "chest": bool, "bonus": Array[int]}
var worlds := {}


func world(level: int) -> Dictionary:
	var k := str(level)
	if not worlds.has(k):
		worlds[k] = {"done": 0, "chest": false, "bonus": []}
	return worlds[k]


## A lesson started from `node` (0-based) finished. `as_bonus` = the node was an
## optional bonus node when the lesson started (world already cleared).
func complete_lesson(level: int, node: int, as_bonus: bool = false) -> void:
	var w := world(level)
	if as_bonus:
		if not w.bonus.has(node):
			w.bonus.append(node)
	elif node >= w.done:
		w.done = mini(w.done + 1, LESSONS_PER_WORLD)


func chest_ready(level: int) -> bool:
	var w := world(level)
	return not w.chest and w.done >= CHEST_AFTER


func open_chest(level: int) -> bool:
	if not chest_ready(level):
		return false
	world(level).chest = true
	return true


## Path layout for one world, top to bottom. Each entry:
## {kind: "lesson"|"chest"|"trophy", node: int, state: String}
## Lesson states: done, current, practice, bonus, bonus_done, locked.
## Chest: ready, open, locked. Trophy: won, locked.
## `cleared` = BKT says every skill at this level is mastered.
## `unlocked` = the world is reachable (highest unlocked map level >= level).
func layout(level: int, unlocked: bool, cleared: bool) -> Array:
	var w := world(level)
	var out := []
	var last := LESSONS_PER_WORLD - 1
	for i in LESSONS_PER_WORLD:
		var st := "locked"
		if unlocked:
			if cleared:
				if i < w.done:
					st = "done"
				else:
					st = "bonus_done" if w.bonus.has(i) else "bonus"
			elif i < w.done:
				st = "practice" if i == last and w.done >= LESSONS_PER_WORLD else "done"
			elif i == w.done:
				st = "current"
		out.append({"kind": "lesson", "node": i, "state": st})
		if i == CHEST_AFTER - 1:
			var cs := "locked"
			if unlocked and w.chest:
				cs = "open"
			elif unlocked and w.done >= CHEST_AFTER:
				cs = "ready"
			out.append({"kind": "chest", "node": -1, "state": cs})
	out.append({"kind": "trophy", "node": -1, "state": "won" if cleared else "locked"})
	return out


func to_dict() -> Dictionary:
	return {"worlds": worlds.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	worlds.clear()
	var saved: Dictionary = data.get("worlds", {})
	for k in saved:
		var w: Dictionary = saved[k]
		var bonus := []
		for b in w.get("bonus", []):
			bonus.append(int(b))
		worlds[str(k)] = {"done": int(w.get("done", 0)), "chest": bool(w.get("chest", false)),
				"bonus": bonus}
