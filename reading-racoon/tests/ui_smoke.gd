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

	# Level 3: story pages and the new task types run through the real scenes.
	gs.lesson_seed = 7   # repeatable picks
	gs.model.highest_unlocked = 3
	gs.start_lesson(3, 0, false)
	await _frames(5)
	lesson = current_scene
	var seen := {}
	for i in 40:
		if current_scene != lesson:
			break
		var t = lesson._task
		if t is StoryPage:
			seen["story"] = true
			t.done.emit()
			await _frames(3)
			continue
		seen[lesson._item.task_type] = true
		t.answered.emit(str(lesson._item.answer), 900)
		await _frames(2)
		lesson._on_continue()
		await _frames(4)
	check(current_scene.name == "LessonComplete", "level 3 lesson completes")
	check(seen.has("story"), "a story page was shown (%s)" % str(seen.keys()))
	check(seen.has("order_tiles") or seen.has("spin_words"),
			"a new task type was played (%s)" % str(seen.keys()))
	gs.lesson_seed = -1

	# Reading Adventure (pre-test): intro card, 20 neutral items, placement card.
	gs.reset_progress()
	gs.start_assessment("pre")
	await _frames(5)
	lesson = current_scene
	check(not lesson.get_node("%Hearts").visible, "no hearts in the test")
	lesson.get_node("%OverlayPrimary").pressed.emit()
	await _frames(3)
	for i in 60:
		if current_scene != lesson:
			break
		var t = lesson._task
		if t is StoryPage:
			t.done.emit()
			await _frames(3)
			continue
		t.answered.emit(str(lesson._item.answer), 900)
		await _frames(2)
		check(lesson.get_node("%SheetTitle").text == "Thank you!", "test feedback is neutral")
		lesson._on_continue()
		await _frames(4)
	check(current_scene.name == "LessonComplete", "test complete screen opens")
	check(gs.assessments.has("pre") and gs.assessments.pre.total == 20, "pre-test stored")
	check(gs.model.highest_unlocked == 2, "placed at level 2 after a perfect test")
	current_scene.get_node("%ContinueButton").pressed.emit()
	await _frames(3)
	check(current_scene.get_node("%Unlock").visible, "placement card shown")
	current_scene.get_node("%GoButton").pressed.emit()
	await _frames(5)
	check(current_scene.name == "LearningPath", "back on the path after the test")

	# Racoon's Closet: try on, buy, wear (FR-07).
	gs.wallet.coins = 100
	current_scene.get_node("%ShopButton").pressed.emit()
	await _frames(5)
	var shop := current_scene
	check(shop.name == "Shop", "shop opens from the path")
	shop._show_slot("hat")
	shop._select("salakot")
	await _frames(2)
	check(shop.raccoon.outfit.get("hat") == "salakot", "trying on shows the hat")
	shop._on_action()
	await _frames(2)
	check(gs.wardrobe.is_worn("salakot") and gs.wallet.coins == 40, "bought and wearing the salakot")
	shop.get_node("%BackButton").pressed.emit()
	await _frames(5)
	check(current_scene.name == "LearningPath", "back from the shop")

	# Login (D-010): the keypad fills the code; LET'S GO waits for 8 characters.
	change_scene_to_file("res://scenes/login/login.tscn")
	await _frames(5)
	var login := current_scene
	check(login.name == "Login", "login screen loads")
	check(login.get_node("%Keys").get_child_count() == LoginCode.ALPHABET.length() + 1,
			"keypad has every code character and a delete key")
	for ch in "K7PM3QX":
		login._type(ch)
	check(login.get_node("%GoButton").disabled, "LET'S GO waits for the 8th character")
	login._type("A")
	login._type("B")   # ignored: a code has 8 characters
	check(login._code == "K7PM3QXA" and not login.get_node("%GoButton").disabled, "8 characters typed")
	login._delete()
	check(login._code == "K7PM3QX", "delete removes the last character")

	# Switch student: never while answers are still waiting to upload.
	gs.device = {"token": "t", "student_name": "Ana", "student_id": 999}
	gs.store.queue_event("response", {"n": 1})
	check(not gs.sign_out(), "can't switch student with unsent answers")
	check(gs.signed_in(), "still signed in")
	gs.store.wipe()
	check(gs.sign_out() and not gs.signed_in(), "switches once everything is saved")

	# Lock screen loads (FR-12).
	change_scene_to_file("res://scenes/lock/lock_screen.tscn")
	await _frames(5)
	check(current_scene.name == "LockScreen", "lock screen loads")

	gs.store.wipe()
	print("ui_smoke: %s" % ("OK" if _failures == 0 else "%d failed" % _failures))
	quit(_failures)
