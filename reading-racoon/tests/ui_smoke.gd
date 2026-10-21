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
	check(current_scene.name == "Hub", "the home hub opens after the test (D-015)")

	# Home hub and Play picker (D-015).
	var hub := current_scene
	check(hub.get_node("%List").get_child_count() == 4, "For you: a header and three picks")
	hub.get_node("%PlayButton").pressed.emit()
	await _frames(5)
	var picker := current_scene
	check(picker.name == "PlayPicker", "PLAY opens the picker")
	check(picker.tiles.size() == 5, "five diamond tiles")
	check(not picker.tiles.adventure.locked, "Adventure open with no schedule yet")
	check(picker.tiles.post.locked, "Big Test locked until the teacher opens it")
	picker._on_tile("adventure")
	await _frames(5)
	check(current_scene.name == "LearningPath", "the gold diamond opens the path")
	current_scene.get_node("%HomeButton").pressed.emit()
	await _frames(5)
	check(current_scene.name == "Hub", "Home on the path goes to the hub")
	gs.soon_section = "library"
	change_scene_to_file("res://scenes/hub/coming_soon.tscn")
	await _frames(5)
	check(current_scene.name == "ComingSoon", "the coming-soon page loads")
	current_scene.get_node("%HomeButton").pressed.emit()
	await _frames(5)
	check(current_scene.name == "Hub", "coming-soon Home goes to the hub")

	# Racoon's Closet: try on, buy, wear (FR-07).
	gs.wallet.coins = 100
	current_scene.get_node("%ClosetTab").pressed.emit()
	await _frames(5)
	var shop := current_scene
	check(shop.name == "Shop", "shop opens from the hub's Closet tab")
	shop._show_slot("hat")
	shop._select("salakot")
	await _frames(2)
	check(shop.raccoon.outfit.get("hat") == "salakot", "trying on shows the hat")
	shop._on_action()
	await _frames(2)
	check(gs.wardrobe.is_worn("salakot") and gs.wallet.coins == 40, "bought and wearing the salakot")
	shop.get_node("%BackButton").pressed.emit()
	await _frames(5)
	check(current_scene.name == "Hub", "back from the shop to the hub")

	# Only Adventure follows the school schedule (D-015). Monday 10:00 = other class.
	gs.access.schedule = AccessPolicy.DEFAULTS.duplicate()
	gs._debug_now = {"year": 2026, "month": 10, "day": 19, "weekday": 1, "hour": 10,
			"minute": 0, "second": 0}
	gs.open_section("adventure")
	await _frames(5)
	check(current_scene.name == "Hub", "Adventure closed: stays on the hub")
	check(gs.notice == "", "the hub explained why (notice read)")
	change_scene_to_file("res://scenes/hub/play_picker.tscn")
	await _frames(5)
	check(current_scene.tiles.adventure.locked, "gold diamond locked in other class hours")
	check(not current_scene.tiles.library.locked, "Library open in other class hours")
	gs.open_section("watch")
	await _frames(5)
	check(current_scene.name == "Watch", "free play opens with the timer running")
	gs.usage = {"date": gs.today(), "minutes": 0.0, "free_minutes": 45.0}
	gs.open_section("practice")
	await _frames(5)
	check(current_scene.name == "Hub", "free-play timer used up: back on the hub")
	gs._debug_now.hour = 22
	gs.go_home()
	await _frames(5)
	check(current_scene.name == "LockScreen", "the hub sleeps at night")
	gs._debug_now = {}
	gs.access.schedule = {}
	gs.usage.free_minutes = 0.0

	# Practice, Library, Watch & Listen and the collections (D-017).
	gs.reset_progress()
	gs.assessments = {"pre": {"total": 20}}
	gs.model.highest_unlocked = 3
	var coins := int(gs.wallet.coins)
	gs.open_section("practice")
	await _frames(5)
	check(current_scene.name == "Practice", "Practice opens from the hub")
	check(current_scene._list.get_child_count() == PracticePool.GAMES.size(), "six game cards")

	gs.practice_game = "memory_match"
	gs.practice_words = []
	change_scene_to_file("res://scenes/practice/memory_match.tscn")
	await _frames(6)
	var mm := current_scene
	check(mm.name == "MemoryMatch" and mm._pairs >= 3 and mm._cards.size() == mm._pairs * 2,
			"Memory Match deals picture and word cards")
	for pair in mm._pairs:
		var two: Array = mm._cards.filter(func(c): return c.pair == pair)
		mm._tap(two[0])
		mm._tap(two[1])
	await _frames(3)
	check(mm._matched == mm._pairs, "every pair matched")
	check(gs.wallet.coins > coins, "Memory Match pays coins")
	check(gs.collection.count("games") == 1, "a games sticker")
	check(gs.collection.words.size() >= mm._pairs, "matched words land in My Word Book")
	await create_timer(1.0).timeout

	gs.practice_game = "rhyme_pop"
	change_scene_to_file("res://scenes/practice/rhyme_pop.tscn")
	await _frames(8)
	var rp := current_scene
	check(rp._balloons.size() >= 2, "Rhyme Pop balloons float up")
	var first: Dictionary = rp._rounds[rp._round]
	var right_b: Balloon = rp._balloons.filter(func(b): return b.word == first.rhyme.word)[0]
	var wrong_b: Balloon = rp._balloons.filter(func(b): return b.word != first.rhyme.word)[0]
	rp._tap(wrong_b, {"word": wrong_b.word}, false)
	check(rp._missed and rp._round == 0, "a wrong balloon only wobbles")
	rp._tap(right_b, first.rhyme, true)
	await create_timer(1.8).timeout
	check(rp._round == 1, "the next round comes after a pop")

	gs.practice_game = "word_catch"
	change_scene_to_file("res://scenes/practice/word_catch.tscn")
	await _frames(8)
	var wc := current_scene
	check(wc._leaves.size() == 4, "Word Catch drops four word leaves")
	var target: Dictionary = wc._targets[0]
	wc._catch(wc._leaves.filter(func(l): return l.text == target.word)[0], target, true)
	await create_timer(1.2).timeout
	check(wc._round == 1 and wc._first_try == 1, "a caught word moves on")

	gs.practice_game = "syllable_train"
	change_scene_to_file("res://scenes/practice/practice_round.tscn")
	await _frames(6)
	var pr := current_scene
	check(pr.name == "PracticeRound" and pr._items.size() >= 2, "Syllable Train has rounds")
	for i in pr._items.size():
		pr._task.answered.emit(str(pr._items[pr._i].answer), 500)
		await create_timer(1.7).timeout
	check(pr._right == pr._items.size(), "lesson tasks work in practice")
	check(gs.model.highest_unlocked == 3, "practice never changes the level (no BKT)")

	gs.open_section("library")
	await _frames(5)
	var lib := current_scene
	check(lib.name == "Library" and lib._grid.get_child_count() >= 8, "the Library shows its books")
	lib._pick_lang("bis")
	await _frames(3)
	check(lib._grid.get_child_count() == 2, "the Bisaya filter shows the Bisaya books")
	gs.open_book = "racoon-boat"
	change_scene_to_file("res://scenes/library/reader.tscn")
	await _frames(6)
	var rd := current_scene
	check(rd._text._labels.size() == 5, "page 1 words are ready to light up")
	for i in 6:
		rd._turn(1)
		await _frames(2)
	check(not rd._controls.visible, "two questions after the last page")
	var qs: Array = rd._book.questions
	for q in qs.size():
		var ans: Dictionary = qs[q].choices.filter(func(c): return c.id == qs[q].answer)[0]
		var btn: Button = rd._body.find_children("*", "Button", true, false) \
				.filter(func(b): return b.tooltip_text == str(ans.get("label", ans.id)))[0]
		btn.pressed.emit()
		await create_timer(1.6).timeout
	check(gs.collection.is_finished("racoon-boat") and rd._right == 2, "the book is finished")
	check(gs.collection.words.has("boat"), "the book's words land in My Word Book")
	check(gs.collection.count("books") == 1, "a books sticker")

	gs.open_section("watch")
	await _frames(5)
	check(current_scene.name == "Watch" and current_scene._list.get_child_count() >= 6, "Watch & Listen lists songs")
	gs.open_media = "abc-chant"
	change_scene_to_file("res://scenes/watch/player.tscn")
	await _frames(6)
	var pl := current_scene
	check(pl._lines.size() == 7 and pl._i == 0, "the song starts on its first line")
	pl._end()
	await _frames(3)
	var ball: Button = pl.find_children("*", "Button", true, false) \
			.filter(func(b): return b.tooltip_text == "ball")[0]
	ball.pressed.emit()
	await create_timer(1.6).timeout
	check(gs.collection.is_finished("abc-chant") and gs.collection.count("watch") == 1, "the song is finished")
	check(gs.collection.goals_left(gs.today()) == 0 and gs.collection.count("goals") == 1,
			"a story, a game and a song: all of today's goals and a goals sticker")

	gs.open_section("stickers")
	await _frames(5)
	check(current_scene.name == "Stickers", "the Sticker Album opens")
	gs.open_section("today")
	await _frames(5)
	check(current_scene.name == "Today", "Today opens")
	gs.open_section("words")
	await _frames(5)
	var wb := current_scene
	check(wb.name == "Words" and not wb._practice.disabled, "My Word Book can practice its words")
	wb._play()
	await _frames(6)
	check(current_scene.name == "MemoryMatch" and current_scene._from_words, "Memory Match with my words")
	current_scene._back()
	await _frames(5)
	check(current_scene.name == "Words", "back to My Word Book")
	gs.go_home()
	await _frames(5)
	check(current_scene.name == "Hub" and not current_scene.get_node("%Dot").visible,
			"the Today dot is gone once the goals are done")

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
