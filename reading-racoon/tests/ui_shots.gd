extends SceneTree
## Saves screenshots of key moments for visual review (needs a window, not headless):
##   "C:\Program Files\Godot\Godot.exe" --path reading-racoon --resolution 720x1280
##       -s res://tests/ui_shots.gd -- --profile=shots --fresh --out=C:/some/folder

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
	await _frames(20)
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("saved ", name)


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset_progress()
	change_scene_to_file("res://scenes/path/learning_path.tscn")
	await _shot("a_path")
	current_scene.scroll.scroll_vertical = 1700
	await _shot("a_path_worlds")
	gs.start_lesson(1, 0, false)
	await _frames(5)
	var lesson := current_scene
	lesson._task.answered.emit(str(lesson._item.answer), 800)
	await _shot("b_sheet_correct")
	lesson._on_continue()
	await _frames(3)
	# Find a drag task for the screenshot, answering others correctly.
	for i in 3:
		if lesson._item.task_type == "drag_letter":
			break
		lesson._task.answered.emit(str(lesson._item.answer), 800)
		await _frames(2)
		lesson._on_continue()
		await _frames(3)
	await _shot("c_task")
	for i in 3:
		lesson._task.answered.emit("__wrong__", 800)
		await _frames(2)
		if i < 2:
			lesson._on_continue()
			await _frames(3)
	await _shot("d_sheet_wrong")
	lesson._on_continue()
	await _shot("e_rescue_intro")
	lesson.get_node("%OverlayPrimary").pressed.emit()
	await _shot("f_rescue_task")
	quit()
