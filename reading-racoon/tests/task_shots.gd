extends SceneTree
## Screenshots of chosen task items for visual review (needs a window):
##   Godot.exe --path reading-racoon --resolution 720x1280 -s res://tests/task_shots.gd
##       -- --profile=shots --fresh --out=C:/some/folder --items=ph3-07,fl3-02,lc3-04

var _out := "user://shots"
var _ids: Array = ["ph3-07", "fl4-01", "lc3-04", "lc4-01", "ph2-09", "pa2-11", "fl3-06"]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--items="):
			_ids = Array(a.trim_prefix("--items=").split(","))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(40)
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("saved ", name)


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset_progress()
	gs.model.highest_unlocked = 5
	for id in _ids:
		var item := {}
		for it in gs.bank.items:
			if it.id == id:
				item = it
		if item.is_empty():
			printerr("no item ", id)
			continue
		gs.start_lesson(item.level, 0, false)
		await _frames(6)
		var lesson := current_scene
		if lesson._task:
			lesson._task.queue_free()
			lesson._task = null
		lesson.session.current = item
		lesson._item = item
		lesson._shown_passage = ""
		if item.has("passage"):
			lesson._show_story(item.passage)
			await _shot("%s_story" % id)
			lesson._task.done.emit()
		else:
			lesson._start_task()
		await _shot(id)
		var wrong := "__wrong__"
		lesson._task.answered.emit(wrong, 800)
		await _shot("%s_result" % id)
	quit()
