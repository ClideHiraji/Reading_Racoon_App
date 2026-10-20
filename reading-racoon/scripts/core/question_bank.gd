class_name QuestionBank
extends RefCounted
## Task items loaded from content/levels.json (FR-09). Every item is tagged with
## sub_skill, level, competency, language, task_type and answer
## (docs/knowledge/07-curriculum-content.md).

const DEFAULT_PATH := "res://content/levels.json"

var items: Array = []


func load_file(path: String = DEFAULT_PATH) -> bool:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("QuestionBank: cannot read %s" % path)
		return false
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not data.has("items"):
		push_error("QuestionBank: %s has no items array" % path)
		return false
	load_items(data.items)
	return true


func load_items(list: Array) -> void:
	items.clear()
	for it in list:
		it.level = int(it.level)
		it.recovery = bool(it.get("recovery", false))
		items.append(it)


## Highest map level that has any content (worlds above show "coming soon").
func max_level() -> int:
	var top := 0
	for it in items:
		top = maxi(top, it.level)
	return top


## Picks an item for (skill, level). Prefers items not in `avoid` (already used
## this lesson) and never returns `last_id` when another item exists.
## Recovery picks fall back to normal items when no recovery-tagged ones exist.
func pick(skill: String, level: int, recovery: bool, avoid: Array = [], last_id: String = "",
		rng: RandomNumberGenerator = null) -> Dictionary:
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
	var i := rng.randi_range(0, fresh.size() - 1) if rng else randi_range(0, fresh.size() - 1)
	return fresh[i]


## Number of choices used for the guess rate (0 = not a choice-style item).
static func num_choices(item: Dictionary) -> int:
	return item.get("choices", []).size()


func _matching(skill: String, level: int, recovery: bool) -> Array:
	return items.filter(func(it): return it.sub_skill == skill and it.level == level \
			and it.recovery == recovery)
