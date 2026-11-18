extends SceneTree
## In-game test (scratch copy only): every Racoon on a real screen shows the 3D
## render instead of his drawing, swapped at runtime; no game file changes.
##   Godot --path <scratch copy> --resolution 576x1024 -s ingame.gd -- <render.png> <out_dir>

var _tex: Texture2D
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_tex = ImageTexture.create_from_image(Image.load_from_file(args[0]))
	_out = args[1]
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _walk(n: Node, found: Array) -> void:
	if n is Raccoon:
		found.append(n)
	for c in n.get_children():
		_walk(c, found)


func _swap() -> void:
	var found := []
	_walk(root, found)
	for r: Raccoon in found:
		if r.has_meta("swapped"):
			continue
		r.set_meta("swapped", true)
		for c in r.get_children(true):
			if c is Node2D:
				c.visible = false
		var t := TextureRect.new()
		t.texture = _tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(t)


func _shot(path: String, name: String) -> void:
	change_scene_to_file(path)
	await _frames(10)
	_swap()
	await _frames(30)
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset_progress()
	gs.device = {"token": "", "student_name": "Ana", "student_id": 0}
	gs.access.schedule = AccessPolicy.DEFAULTS.duplicate()
	gs._debug_now = {"year": 2026, "month": 10, "day": 19, "weekday": 1, "hour": 7, "minute": 45, "second": 0}
	gs.usage = {"date": gs.today(), "minutes": 0.0, "free_minutes": 0.0}
	await _shot("res://scenes/hub/hub.tscn", "ingame_home")
	gs.lesson_mode = "lesson"
	gs.lesson_world = 1
	gs.lesson_node = 0
	gs.lesson_seed = 5
	await _shot("res://scenes/lesson/lesson.tscn", "ingame_lesson")
	gs._debug_now = {"year": 2026, "month": 10, "day": 20, "weekday": 2, "hour": 18, "minute": 0, "second": 0}
	gs.usage = {"date": gs.today(), "minutes": 0.0, "free_minutes": 0.0}
	await _shot("res://scenes/practice/practice.tscn", "ingame_practice")
	quit()
