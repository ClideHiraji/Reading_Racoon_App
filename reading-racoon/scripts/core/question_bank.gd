class_name QuestionBank
extends RefCounted
## Task items and stories from content/levels*.json.
## Each item has sub_skill, level, competency, language, task_type and answer.
## Story questions point to a passage by id.

const FILES := [
	"res://content/levels.json",      # levels 1-2 (English placeholders)
	"res://content/levels_3.json",    # level 3, Filipino
	"res://content/levels_4.json",    # level 4, Filipino
	"res://content/levels_5.json",    # level 5, English
]

var items: Array = []
var passages := {}


func load_file(path: String = "") -> bool:
	items.clear()
	passages.clear()
	var ok := true
	for p in ([path] if path != "" else FILES):
		ok = _load_one(p) and ok
	return ok


func _load_one(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("QuestionBank: missing %s" % path)
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or not data.has("items"):
		push_error("QuestionBank: %s has no items array" % path)
		return false
	_add_items(data.items)
	for id in data.get("passages", {}):
		passages[id] = data.passages[id]
		passages[id].id = id
	return true


func load_items(list: Array) -> void:
	items.clear()
	_add_items(list)


func _add_items(list: Array) -> void:
	for it in list:
		it.level = int(it.level)
		it.recovery = bool(it.get("recovery", false))
		items.append(it)


func passage(id: String) -> Dictionary:
	return passages.get(id, {})


## An item by id ({} if unknown).
func item(id: String) -> Dictionary:
	for it in items:
		if it.id == id:
			return it
	return {}


## Highest map level with any content (higher worlds show "coming soon").
func max_level() -> int:
	var top := 0
	for it in items:
		top = maxi(top, it.level)
	return top


## Picks an item for (skill, level). Prefers items not in `avoid` (used this lesson)
## and never repeats `last_id` if there is another choice.
## With `prefer_passage`, that story's questions come first, so the child
## answers them together instead of re-reading.
## Rescue picks use normal items when there are no rescue items.
func pick(skill: String, level: int, recovery: bool, avoid: Array = [], last_id: String = "",
		rng: RandomNumberGenerator = null, prefer_passage: String = "") -> Dictionary:
	var pool := _matching(skill, level, recovery)
	if pool.is_empty() and recovery:
		pool = _matching(skill, level, false)
	if pool.is_empty():
		return {}
	var fresh := pool.filter(func(it): return not avoid.has(it.id))
	if fresh.is_empty():
		fresh = pool.filter(func(it): return it.id != last_id)
	if fresh.is_empty():
		fresh = pool
	if prefer_passage != "":
		var same := fresh.filter(func(it): return it.get("passage", "") == prefer_passage)
		if not same.is_empty():
			fresh = same
	var i := rng.randi_range(0, fresh.size() - 1) if rng else randi_range(0, fresh.size() - 1)
	return fresh[i]


## Number of choices for the guess rate (0 = not a choice item; ordering tasks keep the table rate).
static func num_choices(entry: Dictionary) -> int:
	return entry.get("choices", []).size()


## The key for a tile in an ordering task: its id, or its text.
static func tile_key(tile) -> String:
	return str(tile.id) if tile is Dictionary else str(tile)


func _matching(skill: String, level: int, recovery: bool) -> Array:
	return items.filter(func(it): return it.sub_skill == skill and it.level == level \
			and it.recovery == recovery)
