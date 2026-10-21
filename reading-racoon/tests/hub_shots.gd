extends SceneTree
## Screenshots of the home hub and Play picker in each time state (D-015), for
## visual review (needs a window, not headless):
##   "C:\Program Files\Godot\Godot.exe" --path reading-racoon --resolution 720x1280
##       -s res://tests/hub_shots.gd -- --profile=shots --fresh --out=C:/some/folder

var _out := "user://shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(40)
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("saved ", name)


func _at(weekday: int, hour: int, minute: int) -> Dictionary:
	return {"year": 2026, "month": 10, "day": 19 + weekday - 1, "weekday": weekday, "hour": hour,
			"minute": minute, "second": 0}


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset_progress()
	gs.device = {"token": "", "student_name": "Ana", "student_id": 0}
	gs.assessments = {"pre": {"total": 20}}
	gs.wallet = {"xp": 140, "coins": 120}
	gs.model.highest_unlocked = 2
	gs.access.schedule = AccessPolicy.DEFAULTS.duplicate()

	gs._debug_now = _at(1, 7, 45)   # Monday, Reading time
	change_scene_to_file("res://scenes/hub/hub.tscn")
	await _shot("hub_reading_time")
	change_scene_to_file("res://scenes/hub/play_picker.tscn")
	await _shot("picker_reading_time")

	gs._debug_now = _at(2, 18, 0)   # Tuesday evening: Adventure closed, free play on
	gs.usage = {"date": gs.today(), "minutes": 0.0, "free_minutes": 20.0}
	change_scene_to_file("res://scenes/hub/hub.tscn")
	await _shot("hub_after_hours")
	change_scene_to_file("res://scenes/hub/play_picker.tscn")
	await _shot("picker_after_hours")

	gs.soon_section = "library"
	change_scene_to_file("res://scenes/hub/coming_soon.tscn")
	await _shot("coming_soon")
	gs.access.schedule = {}
	gs._debug_now = {}
	quit()
