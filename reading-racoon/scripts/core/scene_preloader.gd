class_name ScenePreloader
extends Node
## Loads the game's screens in the background, one at a time, after the start screen is up.
## Without this, the first visit to a screen froze the game while it loaded (worse on cheap phones).
## Waits while a lesson or test is on screen, so it doesn't slow it down.

## Most likely next first.
const SCENES := [
	"res://scenes/hub/hub.tscn",
	"res://scenes/login/login.tscn",
	"res://scenes/path/learning_path.tscn",
	"res://scenes/lesson/lesson.tscn",
	"res://scenes/lesson/lesson_complete.tscn",
	"res://scenes/shop/shop.tscn",
	"res://scenes/practice/practice.tscn",
	"res://scenes/library/library.tscn",
	"res://scenes/watch/watch.tscn",
	"res://scenes/collection/stickers.tscn",
	"res://scenes/collection/words.tscn",
	"res://scenes/collection/today.tscn",
	"res://scenes/library/reader.tscn",
	"res://scenes/watch/player.tscn",
	"res://scenes/practice/memory_match.tscn",
	"res://scenes/practice/rhyme_pop.tscn",
	"res://scenes/practice/word_catch.tscn",
	"res://scenes/practice/practice_round.tscn",
	"res://scenes/lock/lock_screen.tscn",
	"res://scenes/hub/coming_soon.tscn",
]

var _todo: Array = []
var _loading := ""
var _held := {}            # path -> loaded scene, kept so it stays in the cache


func start() -> void:
	_todo = SCENES.duplicate()
	set_process(true)


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if _loading == "":
		if _todo.is_empty():
			set_process(false)
			return
		var gs := get_node_or_null("/root/GameState")
		if gs and gs.in_lesson():
			return
		_loading = _todo.pop_front()
		if ResourceLoader.has_cached(_loading) or ResourceLoader.load_threaded_request(_loading) != OK:
			_loading = ""
		return
	match ResourceLoader.load_threaded_get_status(_loading):
		ResourceLoader.THREAD_LOAD_LOADED:
			_held[_loading] = ResourceLoader.load_threaded_get(_loading)
			_loading = ""
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading = ""


## For tests: how many screens are loaded and waiting.
func loaded_count() -> int:
	return _held.size()
