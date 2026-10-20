extends Node
## Global game state (autoload "GameState"): the learner's model, path, wallet and
## content, loaded from and saved to the device after every answer (FR-11).
## There is one local profile until the student login method is decided (open issue 9).

signal wallet_changed

const LINES_PATH := "res://content/companion_lines.json"

var model := StudentModel.new()
var path := PathProgress.new()
var bank := QuestionBank.new()
var store: SaveStore
var wallet := {"xp": 0, "coins": 0}
var flags: Array = []
var lines := {}

## Set by the path before opening a lesson.
var lesson_world := 1
var lesson_node := 0
var lesson_as_bonus := false
## Set by the lesson for the lesson-complete screen.
var last_summary := {}

var _args := {}


func _ready() -> void:
	_args = _parse_args()
	store = SaveStore.new(_args.get("profile", ""))
	bank.load_file()
	var data = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
	lines = data if typeof(data) == TYPE_DICTIONARY else {}
	load_profile()
	if _args.has("fresh"):
		reset_progress()
	_debug_hooks()


func load_profile() -> void:
	var data := store.load_profile()
	model.from_dict(data.get("model", {}))
	path.from_dict(data.get("path", {}))
	var w: Dictionary = data.get("wallet", {})
	wallet = {"xp": int(w.get("xp", 0)), "coins": int(w.get("coins", 0))}
	flags = data.get("flags", [])


func save_profile() -> void:
	store.save_profile({
		"version": 1,
		"model": model.to_dict(),
		"path": path.to_dict(),
		"wallet": wallet,
		"flags": flags,
	})


func reset_progress() -> void:
	model.reset()
	path = PathProgress.new()
	wallet = {"xp": 0, "coins": 0}
	flags = []
	save_profile()


## Highest map level with content; worlds above it show "coming soon".
func content_max_level() -> int:
	return bank.max_level()


func world_cleared(level: int) -> bool:
	return model.is_level_complete(level)


func world_unlocked(level: int) -> bool:
	return level <= model.highest_unlocked and level <= content_max_level()


func start_lesson(world: int, node: int, as_bonus: bool) -> void:
	lesson_world = world
	lesson_node = node
	lesson_as_bonus = as_bonus
	get_tree().change_scene_to_file("res://scenes/lesson/lesson.tscn")


func new_session() -> LessonSession:
	return LessonSession.new(model, bank, lesson_world)


## Called after every answer: queue the events for sync and save (FR-11).
func record(session: LessonSession) -> void:
	for ev in session.drain_events():
		store.queue_event(ev.type, ev.payload)
	save_profile()


func finish_lesson(session: LessonSession) -> void:
	record(session)
	last_summary = session.summary()
	if not session.ended_early:
		path.complete_lesson(lesson_world, lesson_node, lesson_as_bonus)
	wallet.xp += last_summary.xp
	wallet.coins += last_summary.coins
	for f in session.flags:
		flags.append(f)
	store.queue_event("lesson_end", {"level": lesson_world, "node": lesson_node,
			"correct": last_summary.correct, "total": last_summary.total,
			"stars": last_summary.stars})
	save_profile()
	wallet_changed.emit()


func open_chest(world: int) -> int:
	if not path.open_chest(world):
		return 0
	wallet.coins += PathProgress.CHEST_COINS
	store.queue_event("chest", {"level": world, "coins": PathProgress.CHEST_COINS})
	save_profile()
	wallet_changed.emit()
	return PathProgress.CHEST_COINS


## A random raccoon line for a state, from the bundled fallback library
## (docs/knowledge/08-ai-integration.md: offline companion dialogue).
func line(state: String) -> String:
	var options: Array = lines.get(state, [])
	if options.is_empty():
		return ""
	return options[randi_range(0, options.size() - 1)]


# --- Debug hooks (desktop testing only) ---------------------------------------
# Usage: Godot.exe --path reading-racoon -- --profile=demo --fresh
#        --scene=res://scenes/lesson/lesson.tscn --shot=user://shot.png --shot-delay=1.5

func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var parts := a.trim_prefix("--").split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else ""
	return out


func _debug_hooks() -> void:
	if not OS.is_debug_build():
		return
	if _args.has("demo"):
		_seed_demo()
	if _args.has("scene"):
		get_tree().change_scene_to_file.call_deferred(_args.scene)
	if _args.has("shot"):
		await get_tree().create_timer(float(_args.get("shot-delay", "1.5"))).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(_args.shot)
		print("Saved screenshot to ", ProjectSettings.globalize_path(_args.shot))
		get_tree().quit()


func _seed_demo() -> void:
	path.world(1).done = 2
	wallet = {"xp": 120, "coins": 25}
	for i in 3:
		model.record(SkillCatalog.PA, 1, true, 3)
	last_summary = {"level": 1, "correct": 7, "total": 8, "accuracy": 0.875, "stars": 2,
			"xp": 70, "coins": 30, "level_up": true, "ended_early": false,
			"results": [{"correct": true}, {"correct": true}, {"correct": false},
				{"correct": true}, {"correct": true}, {"correct": true},
				{"correct": true}, {"correct": true}]}
