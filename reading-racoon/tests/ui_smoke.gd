extends SceneTree
## UI smoke test: drives the real scenes headless (path → lesson with a rescue →
## lesson complete → path) and fails on any script error or wrong scene.
## Run from the repo root:
##   "C:\Program Files\Godot\Godot.exe" --headless --path reading-racoon -s res://tests/ui_smoke.gd -- --profile=smoke --fresh

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL ui_smoke: " + msg)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames()
	var gs := root.get_node("GameState")
	gs.reset_progress()
	change_scene_to_file("res://scenes/path/learning_path.tscn")
	await _frames(5)
	check(current_scene.name == "LearningPath", "path opens")

	gs.start_lesson(1, 0, false)
	await _frames(5)
	var lesson := current_scene
	check(lesson.name == "Lesson", "lesson opens")

	# Three wrong answers in a row -> Racoon's Rescue, answered correctly.
	for i in 3:
		lesson._task.answered.emit("__wrong__", 900)
		await _frames()
		check(lesson.sheet.visible, "feedback sheet shows after an answer")
		lesson._on_continue()
		await _frames()
	check(lesson.session.in_rescue(), "rescue started after 3 wrong answers")
	check(lesson.get_node("%Overlay").visible, "rescue intro card shows")
	lesson.get_node("%OverlayPrimary").pressed.emit()
	await _frames()
	for i in 3:
		lesson._task.answered.emit(str(lesson._item.answer), 700)
		await _frames()
		lesson._on_continue()
		await _frames()
	check(not lesson.session.in_rescue(), "rescue finished")
	check(lesson.session.hearts.hearts == 3, "hearts refilled")

	# Answer the rest correctly until the lesson completes.
	for i in 20:
		if current_scene != lesson:
			break
		lesson._task.answered.emit(str(lesson._item.answer), 800)
		await _frames()
		lesson._on_continue()
		await _frames(4)
	check(current_scene.name == "LessonComplete", "lesson-complete screen opens")
	check(gs.last_summary.total == 8, "8 items scored (got %s)" % gs.last_summary.get("total"))
	check(gs.wallet.xp > 0 and gs.wallet.coins > 0, "XP and coins credited")
	check(gs.path.world(1).done == 1, "first path node done")
	check(gs.store.read_queue().size() > 20, "events queued for sync")

	current_scene.get_node("%ContinueButton").pressed.emit()
	await _frames(5)
	check(current_scene.name == "LearningPath", "back on the path")

	gs.store.wipe()
	print("ui_smoke: %s" % ("OK" if _failures == 0 else "%d failed" % _failures))
	quit(_failures)
