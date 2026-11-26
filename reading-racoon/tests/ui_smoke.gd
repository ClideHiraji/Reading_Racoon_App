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


## The open card's way out (Screen.back's "back_cancel"), or null when no card is open.
func _top_cancel() -> BaseButton:
	var found: BaseButton = null
	for n in get_nodes_in_group("back_cancel"):
		if n is BaseButton and n.is_visible_in_tree() and current_scene.is_ancestor_of(n):
			found = n
	return found


func _run() -> void:
	await _frames()
	var gs := root.get_node("GameState")
	gs.reset_progress()
	gs.access.schedule = {}   # open at any hour: the default school day closes Adventure after 5 PM
	change_scene_to_file("res://scenes/path/learning_path.tscn")
	await _frames(5)
	check(current_scene.name == "LearningPath", "path opens")

	gs.start_lesson(1, 0, false)
	await _frames(5)
	var lesson := current_scene
	check(lesson.name == "Lesson", "lesson opens")
	var model_before: Dictionary = gs.model.to_dict()
	var queued_before: int = gs.store.read_queue().size()

	# D-021: a wrong first try: Racoon's hint and the same question, no answer yet.
	var first_item: Dictionary = lesson._item
	lesson._task.answered.emit("__wrong__", 900)
	await _frames()
	check(not lesson.sheet.visible and lesson._item == first_item, "a wrong first try: same question again")
	check(lesson.session.hearts.hearts == 2, "a heart goes")
	var lost_row: HBoxContainer = lesson.get_node("%Hearts")
	check(lost_row.get_child(2).name.begins_with("BrokenHeart")
			and lost_row.get_child(2).get_child(0) is AnimatedHeart
			and lost_row.get_child(2).get_child(0).kind == "break", "the lost heart breaks (Broken Heart)")
	check(lesson.bubble._label.text == HintText.hint(first_item), "Racoon gives the question's hint")
	# A wrong second try: the answer and why, then the lesson moves on by itself.
	lesson._task.answered.emit("__wrong__", 900)
	await _frames()
	check(lesson.sheet.visible and lesson.get_node("%SheetTitle").text.begins_with("The answer is"),
			"the answer shows after the second try")
	check(lesson.get_node("%SheetDetail").text == HintText.explain(first_item), "with the explanation")
	check(not lesson.get_node("%ContinueButton").visible, "no CONTINUE button")
	check(lesson.session.hearts.hearts == 1, "a second heart goes")
	await create_timer(6.5).timeout
	check(not lesson.sheet.visible and lesson._item != first_item, "on to the next question by itself")
	# A right answer: a short word from Racoon, a heart back, and on by itself.
	var second_item: Dictionary = lesson._item
	if lesson._task is StoryPage:
		lesson._task.done.emit()
		await _frames(3)
	lesson._task.answered.emit(str(second_item.answer), 800)
	await _frames()
	check(not lesson.sheet.visible and lesson.session.hearts.hearts == 2, "right: no sheet, one heart back")
	var hearts_row: HBoxContainer = lesson.get_node("%Hearts")
	var regained := hearts_row.get_children().filter(func(c): return c.name.begins_with("RegainedHeart"))
	check(regained.size() == 1 and hearts_row.get_child(1) == regained[0]
			and regained[0].get_child(0) is AnimatedHeart, "the heart that comes back fills in (Regain Heart)")
	await create_timer(1.6).timeout
	check(lesson._item != second_item, "and the next question comes by itself")
	check(gs.model.to_dict() == model_before and gs.store.read_queue().size() == queued_before,
			"nothing is saved while the lesson runs")

	# Wrong tries until the hearts run out -> Racoon's Rescue, answered correctly.
	for i in 8:
		if lesson.session.in_rescue():
			break
		lesson._task.answered.emit("__wrong__", 900)
		await _frames()
		if lesson.sheet.visible:
			lesson._on_continue()
			await _frames()
	check(lesson.session.in_rescue(), "rescue started with no hearts left")
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
	check(gs.model.to_dict() != model_before, "a finished lesson keeps its BKT")

	current_scene.get_node("%ContinueButton").pressed.emit()
	await _frames(5)
	if current_scene.name == "LessonComplete" and current_scene.get_node("%Unlock").visible:
		current_scene.get_node("%GoButton").pressed.emit()   # a Level Up shows the new world first
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

	# D-021: stopping a lesson halfway keeps nothing; it starts over next time.
	var kept: Dictionary = gs.model.to_dict()
	var queue_size: int = gs.store.read_queue().size()
	var xp: int = gs.wallet.xp
	var done_nodes: int = gs.path.world(1).done
	gs.start_lesson(1, 1, false)
	await _frames(5)
	lesson = current_scene
	for i in 3:
		lesson._task.answered.emit(str(lesson._item.answer), 800)
		await _frames()
		lesson._on_continue()
		await _frames(3)
	lesson._on_close()
	await _frames()
	lesson.get_node("%OverlaySecondary").pressed.emit()
	await _frames(5)
	check(current_scene.name == "LearningPath", "STOP goes back to the path")
	check(gs.model.to_dict() == kept and gs.store.read_queue().size() == queue_size,
			"a stopped lesson keeps no BKT and no events")
	check(gs.wallet.xp == xp and gs.path.world(1).done == done_nodes, "and no XP or path progress")

	# D-021: Adventure opens the map; the pre-test waits there until the child taps START.
	gs.reset_progress()
	queue_size = gs.store.read_queue().size()
	gs.open_section("adventure")
	await _frames(6)
	check(current_scene.name == "LearningPath", "Adventure opens the map, not a test")
	var card: Node = current_scene.find_child("PreTestCard", true, false)
	check(card != null, "the Reading Adventure card is on the map")
	card.find_child("Start", true, false).pressed.emit()
	await _frames(5)
	lesson = current_scene
	check(lesson.name == "Lesson" and lesson._testing, "START begins the Reading Adventure")
	check(not lesson.get_node("%Overlay").visible, "no extra card before the first question")
	for i in 3:
		if lesson._task is StoryPage:
			lesson._task.done.emit()
			await _frames(3)
		lesson._task.answered.emit(str(lesson._item.answer), 900)
		await _frames(2)
		lesson._on_continue()
		await _frames(3)
	lesson._on_close()
	await _frames()
	lesson.get_node("%OverlaySecondary").pressed.emit()
	await _frames(5)
	check(current_scene.name == "LearningPath", "STOP in the test goes back to the map")
	var added: Array = gs.store.read_queue().slice(queue_size).map(func(e): return e.type)
	check(gs.needs_pretest() and not added.has("response") and not added.has("assessment"),
			"a stopped test keeps no answers and waits on the map again (%s)" % str(added))

	# Reading Adventure (pre-test): 20 items with no right/wrong, results by skill.
	gs.reset_progress()
	gs.start_assessment("pre")
	await _frames(5)
	lesson = current_scene
	check(not lesson.get_node("%Hearts").visible, "no hearts in the test")
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
		check(not lesson.sheet.visible, "test feedback is a word from Racoon, no sheet")
		lesson._on_continue()
		await _frames(4)
	check(current_scene.name == "LessonComplete", "test complete screen opens")
	check(gs.assessments.has("pre") and gs.assessments.pre.total == 20, "pre-test stored")
	check(gs.model.highest_unlocked == 2, "placed at level 2 after a perfect test")
	var results: Node = current_scene.find_child("Results", true, false)
	check(results != null and results.get_node("Rows").get_child_count() == 5,
			"results show one bar per reading skill (D-021)")
	check(current_scene.find_child("Footer", true, false) != null, "where the path starts is shown")
	check(current_scene.get_node("%ContinueButton").text == "GO HOME", "the button says GO HOME")
	current_scene.get_node("%ContinueButton").pressed.emit()
	await _frames(5)
	check(current_scene.name == "Hub", "the home hub opens after the test (D-015)")

	# Home, with the Play picker folded in (D-022).
	var hub := current_scene
	check(hub.get_node("%LibraryTile") != null and hub.get_node("%PracticeTile") != null
			and hub.get_node("%WatchTile") != null, "Library, Practice and Watch are on Home")
	check(hub._play_title.text == "PLAY" and hub._play.face_color == Palette.YELLOW,
			"PLAY is the yellow Adventure button (no Big Reading Day yet)")
	hub.get_node("%PlayButton").pressed.emit()
	await _frames(5)
	check(current_scene.name == "LearningPath", "PLAY opens the Adventure path")
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
	gs.path.complete_lesson(1, 0)   # a finished lesson: the River cap is earned (D-026)
	current_scene.get_node("%ClosetTab").pressed.emit()
	await _frames(5)
	var shop := current_scene
	check(shop.name == "Shop", "shop opens from the hub's Closet tab")
	var paws_tab: Control = shop.get_node("%Tabs").get_children().filter(func(t): return t.get_meta("slot") == "paws")[0]
	check(paws_tab.tooltip_text == Wardrobe.slot_name("paws", gs.buddy_id()), "the paws tab is named for the buddy")
	shop._show_slot("hat")
	check(gs.wardrobe.owns("cap"), "the Closet gives the River cap a finished lesson earned (D-026)")
	shop._select("salakot")
	await _frames(2)
	check(shop.raccoon.outfit.get("hat") == "salakot", "an item to earn can still be tried on")
	shop._on_action()
	await _frames(2)
	check(not gs.wardrobe.owns("salakot") and gs.wallet.coins == 100, "an item to earn isn't sold")
	shop._select("party_hat")
	await _frames(2)
	check(shop.raccoon.outfit.get("hat") == "party_hat", "trying on shows the hat")
	shop._on_action()
	await _frames(2)
	check(gs.wardrobe.is_worn("party_hat") and gs.wallet.coins == 70, "bought and wearing the party hat")
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
	check(current_scene._play.face_color == current_scene.LOCKED, "PLAY locked in other class hours")
	check(current_scene._tiles.library.modulate.a == 1.0, "Library open in other class hours")
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
	check(current_scene._list.get_child_count() == PracticePool.GAMES.size(), "a card per game")

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
	# Every chip's cards, and the "Nothing here yet" message, fill their grid column.
	# The empty Videos message was once 1 px wide, one letter per line: an
	# autowrapped label in a grid cell asks for no width (NFR-02). Bundled videos
	# are set aside first, so the empty message is always what Videos shows here.
	var wl := current_scene
	var all_media: Array = gs.media.watch
	gs.media.watch = all_media.filter(func(m): return m.kind != "video")
	for chip_name in ["Videos", "Songs", "Stories", "All"]:
		var chip: Button = wl._chips.get_children().filter(func(b): return b.text == chip_name)[0]
		chip.pressed.emit()
		await _frames(5)
		var cells: Array = wl._list.get_children()
		var sep: int = wl._list.get_theme_constant("h_separation")
		var col_w: float = (wl._list.size.x - sep * (wl._list.columns - 1)) / wl._list.columns
		check(not cells.is_empty() and cells.all(func(c): return c.size.x >= col_w - 1.0),
				"Watch & Listen's %s chip: every card and message fills its column" % chip_name)
		if chip_name == "Videos":
			check(cells.size() == 1 and cells[0] is Label and cells[0].size.x >= wl._list.size.x - 1.0
					and cells[0].get_line_count() <= 2, "no videos yet: one readable message across the list")
	gs.media.watch = all_media
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

	# A teacher video keeps its own shape on the stage, with bands on two sides. It
	# was once stretched to the stage, squeezing a 16:9 clip by about 12% on a phone
	# (D-017). tests/fixtures/wide_clip.ogv: 1 s of 320x180 Ogg Theora.
	gs.media.watch.append({"id": "tv-shape01", "kind": "video", "title": "Wide clip", "language": "en",
			"minutes": 1, "file": "res://tests/fixtures/wide_clip.ogv", "teacher": true,
			"check": {"prompt": "Which one is a bee?", "answer": "bee",
					"choices": [{"id": "bee", "label": "bee", "picture": "bee"}, {"id": "cat", "label": "cat", "picture": "cat"}]}})
	gs.open_media = "tv-shape01"
	change_scene_to_file("res://scenes/watch/player.tscn")
	await _frames(8)
	var vp := current_scene
	var shown: Vector2 = vp._video.size
	var stage: Vector2 = vp._stage.size
	check(vp._video.is_playing() and absf(shown.aspect() - 16.0 / 9.0) < 0.02,
			"a teacher video keeps its 16:9 shape (shown %s on a %s stage)" % [shown, stage])
	check(shown.x <= stage.x + 0.5 and shown.y <= stage.y + 0.5 and maxf(shown.x / stage.x, shown.y / stage.y) > 0.9,
			"and fits the stage, filling it one way")
	# Full screen: the corner button opens the video over the whole player, and it
	# plays on (on a phone the screen also turns sideways, which a laptop can't test).
	# Pause works there, Back closes it, and the video ending closes it before the
	# quick check. The video is paused between steps, so the 1 s clip can't end early.
	var fs_btns := vp.find_children("*", "Button", true, false) \
			.filter(func(b): return b.tooltip_text == "Full screen")
	check(fs_btns.size() == 1, "a teacher video has a full-screen button")
	if fs_btns.size() == 1:
		fs_btns[0].pressed.emit()
		await _frames(3)
		var full: Control = vp.get_node_or_null("FullScreen")
		check(full != null and full.get_global_rect().is_equal_approx(vp.get_viewport_rect())
				and vp._video.is_playing() and not vp._video.paused, "full screen covers the screen and the video plays on")
		var fs_pause: Array = full.find_children("*", "Button", true, false) \
				.filter(func(b): return b.tooltip_text == "Pause") if full else []
		var pics: Array = full.find_children("*", "TextureRect", true, false) \
				.filter(func(t): return t.texture == vp._video.get_video_texture()) if full else []
		check(pics.size() == 1 and pics[0].stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				and pics[0].get_global_rect().is_equal_approx(full.get_global_rect()),
				"it shows the video as big as the screen allows, in its own shape")
		check(fs_pause.size() == 1, "full screen has its own Pause")
		if fs_pause.size() == 1:
			fs_pause[0].pressed.emit()
			check(vp._video.paused and fs_pause[0].tooltip_text == "Play", "Pause works in full screen")
		var screen := root.get_node("Screen")
		screen._last_back = -100000
		screen.back()
		await _frames(3)
		check(current_scene == vp and vp.get_node_or_null("FullScreen") == null, "Back closes full screen, still in the player")
		fs_btns[0].pressed.emit()
		await _frames(3)
		full = vp.get_node_or_null("FullScreen")
		var fs_play: Array = full.find_children("*", "Button", true, false) \
				.filter(func(b): return b.tooltip_text == "Play") if full else []
		if fs_play.size() == 1:
			fs_play[0].pressed.emit()
		check(full != null and not vp._video.paused, "full screen opens again, and Play goes on")
		for i in 40:
			if vp.get_node_or_null("FullScreen") == null:
				break
			await create_timer(0.1).timeout
		check(vp.get_node_or_null("FullScreen") == null and vp.find_children("*", "Button", true, false)
				.any(func(b): return b.tooltip_text == "bee"), "the video's end closes full screen for the quick check")
	vp._back()
	await _frames(5)
	gs.media.watch.pop_back()

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
	check(current_scene.name == "Hub"
			and current_scene._goal_stars.all(func(st): return st.self_modulate == Palette.MANGO),
			"all three Today stars light up once the goals are done")

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

	# Choose your buddy (D-033): pick Rina and Bisaya, then Let's go saves them for this student.
	var had_buddy: Dictionary = gs.buddy.duplicate()
	gs.buddy = {"who": "", "lang": "en"}
	change_scene_to_file(gs.BUDDY_SCENE)
	await _frames(5)
	var chooser := current_scene
	check(chooser.name == "ChooseBuddy", "the buddy chooser loads")
	check(chooser._go.disabled, "Let's go waits until a buddy is picked")
	chooser._pick("rina")
	chooser._pick_lang("bis")
	check(not chooser._go.disabled and chooser._go.text == "Dali na!", "Let's go is ready, in Bisaya")
	check(gs.buddy.who == "", "nothing is saved before Let's go")
	chooser._done()
	await _frames(5)
	check(gs.buddy.who == "rina" and gs.buddy.lang == "bis", "Let's go saves Rina and Bisaya")
	check(gs.talk("closet_title") == "Closet ni Rina", "the menus follow the buddy and language")
	change_scene_to_file("res://scenes/shop/shop.tscn")
	await _frames(5)
	var rina_paws: Control = current_scene.get_node("%Tabs").get_children().filter(func(t): return t.get_meta("slot") == "paws")[0]
	check(rina_paws.tooltip_text == "In her paws", "Rina's Closet says what she holds is in her paws")
	change_scene_to_file(gs.HUB_SCENE)   # back where Let's go left it, for the checks below
	await _frames(5)
	check(root.get_node("Speech").buddy == "rina", "Rina's own voice")
	check(not gs.line("rescue_start").contains("{buddy}"), "a buddy line names the buddy")
	check(gs.line("hint_phonics") in gs.lines.hint_phonics, "hints stay in the lesson's language")
	check(gs.talk("path_soon", ["Mango Grove"]).contains("Mango Grove"), "a menu line fills its slot")
	check(gs.talk("no_such_line") == "no_such_line", "an unknown menu line shows its key")
	check(gs.talk_as("choose_hi", "en", "roco") == "Hi! I'm Roco!", "the chooser previews any buddy")
	gs.buddy = {}
	gs.load_profile()
	check(gs.buddy.who == "rina" and gs.buddy.lang == "bis", "the buddy and language come back with the profile")
	gs.set_buddy(str(had_buddy.get("who", "roco")), str(had_buddy.get("lang", "en")))
	check(root.get_node("Speech").buddy == gs.buddy_id(), "the voice follows the buddy back")

	# After a wrong answer the green and orange cards keep their pictures' own colours (D-027):
	# tinting them for the card's new face made black silhouettes.
	var pick: Dictionary = {}
	for it in gs.bank.items:
		if it.task_type == "tap_choice" and it.choices.all(func(c): return c.has("picture")):
			pick = it
			break
	var tap: Node = load("res://scenes/tasks/tap_choice_task.tscn").instantiate()
	root.add_child(tap)
	tap.setup(pick)
	await _frames()
	var wrong_id := ""
	for c in pick.choices:
		if str(c.id) != str(pick.answer):
			wrong_id = str(c.id)
			break
	tap.show_result(wrong_id, str(pick.answer))
	var pictures := tap.find_children("*", "TextureRect", true, false).filter(
			func(t): return t.texture and str(t.texture.resource_path).contains("assets/pictures"))
	check(not pictures.is_empty() and pictures.all(func(t): return t.self_modulate == Color.WHITE),
			"answer pictures keep their colours after a wrong answer (%s)" % pick.get("id", "none"))
	tap.free()
	# Recorded voices only (D-035, D-041): a recorded line plays from its clips; a line with any sentence
	# not recorded in the buddy's voice and language stays silent, and no device voice ever speaks.
	var voice = root.get_node("Speech")
	var had: Dictionary = gs.buddy.duplicate()
	gs.set_buddy("roco", "en")
	check(voice.buddy == "roco" and not voice.recorded("Great job!", "en").is_empty(), "Roco's 'Great job!' is recorded")
	check(voice.recorded("Great job! Zebras eat purple clouds.", "en").is_empty(), "a line with an unrecorded sentence isn't")
	check(voice.recorded("Great job!", "fil").is_empty(), "the clip belongs to its language")
	voice.say("Great job!")
	check(voice.speaking(), "a recorded line plays")
	voice.say("Zebras eat purple clouds.")
	check(not voice.speaking(), "an unrecorded line is silent and stops the line before it")
	check(not voice.say_tracked("Zebras eat purple clouds.", "en"), "an unrecorded read-along paces itself")
	voice.say("Great job!")
	voice.cut()
	check(not voice.speaking(), "cut stops a recorded line at once")
	check(not ProjectSettings.get_setting("audio/general/text_to_speech", false), "the device voice is off")
	gs.set_buddy("rina", "en")
	check(voice.buddy == "rina", "the recorded voice follows the buddy")
	gs.set_buddy(str(had.get("who", "roco")), str(had.get("lang", "en")))

	# A new day's card shows once (D-026): coming back to Home doesn't bring the same card back.
	gs.access.schedule = {}
	gs.new_day_items = [Wardrobe.ITEMS.keys()[0]]
	change_scene_to_file(gs.HUB_SCENE)
	await create_timer(2.2).timeout
	var day_ok := _top_cancel()
	check(day_ok != null, "the new day's card shows")
	if day_ok:
		day_ok.pressed.emit()
	change_scene_to_file(gs.HUB_SCENE)
	await create_timer(2.2).timeout
	check(_top_cancel() == null, "and not again on the next visit to Home")

	# Settings (D-042): the gear opens the card, with the volumes, sign out and (on a laptop) close; Back
	# closes it. Its chips aren't pressed here: they'd save to this laptop's own settings file.
	current_scene.get_node("%SettingsButton").pressed.emit()
	await _frames(3)
	var done := _top_cancel()
	check(done != null and done.text == "Done", "the gear opens Settings")
	var texts: Array = current_scene.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(texts.has("Loud") and texts.has("Off") and texts.has("Sign out") and texts.has("Close game")
			and texts.has("Buddy and language"), "Settings has the volumes, buddy, sign out and close")
	check(texts.has("High") and texts.has("Low") and texts.has("30") and texts.has("60"), "and graphics and frame rate")
	SettingsCard.graphics(self, "low")
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT and not Smooth.enabled,
			"Low graphics draws at the base size, without smoothed edges")
	SettingsCard.graphics(self, "high")
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and Smooth.enabled, "High draws sharp")
	root.get_node("Screen").back()
	await _frames(3)
	check(_top_cancel() == null, "Back closes Settings")

	# Practice games as lesson tasks (D-043): items with a variant play as Rhyme Pop and Word Catch and
	# answer like any card.
	for v in ["rhyme_pop", "word_catch"]:
		var it: Dictionary = gs.bank.items.filter(func(i): return str(i.get("variant", "")) == v)[0]
		var task: Node = load("res://scenes/tasks/%s_task.tscn" % v).instantiate()
		root.add_child(task)
		task.setup(it)
		await _frames()
		check(task._cards.size() == it.choices.size(), "%s shows every answer" % v)
		var got := []
		task.answered.connect(func(a, _ms): got.append(a))
		task._cards[str(it.answer)].pressed.emit()
		check(got == [str(it.answer)], "%s answers with the card tapped" % v)
		task.show_result(str(it.answer), str(it.answer))
		task.free()

	# Drag (the user's play-test, 2026-11-26): a letter let go on or near the gap drops in, and leaves the tray.
	var dl_item: Dictionary = gs.bank.items.filter(func(i): return i.task_type == "drag_letter")[0]
	var dl: Node = load("res://scenes/tasks/drag_letter_task.tscn").instantiate()
	root.add_child(dl)
	dl.setup(dl_item)
	await _frames(3)
	var tile: LetterTile = dl._tiles[str(dl_item.answer)]
	var gap: Rect2 = dl._slot.get_global_rect()
	check(tile._slot_near(gap.get_center()) == dl._slot, "a letter let go on the gap drops in")
	check(tile._slot_near(Vector2(gap.end.x + 40, gap.get_center().y)) == dl._slot, "and one let go just beside it")
	check(tile._slot_near(gap.end + Vector2(300, 300)) == null, "but not one let go far away")
	var got_l := []
	dl.answered.connect(func(a, _ms): got_l.append(a))
	dl._slot.dropped.emit(str(dl_item.answer))
	check(got_l == [str(dl_item.answer)] and tile.modulate.a == 0.0, "the letter dropped answers and leaves the tray")
	dl.free()

	# The word wheel turns like a real one: a fling spins it on, it slows down, clicks onto a letter and
	# answers with the letter at the pointer.
	var sw_item: Dictionary = gs.bank.items.filter(func(i): return i.task_type == "spin_words")[0]
	var sw: Node = load("res://scenes/tasks/spin_words_task.tscn").instantiate()
	root.add_child(sw)
	sw.setup(sw_item)
	await create_timer(1.3).timeout   # the wheel's opening turn
	var wheel: SpinWheel = sw._wheel
	var got_w := []
	sw.answered.connect(func(a, _ms): got_w.append(a))
	var mid := wheel.size / 2
	var ring := wheel._radius() * 0.7
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = mid + Vector2(ring, 0)
	wheel._gui_input(press)
	for k in range(1, 7):
		var move := InputEventMouseMotion.new()
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		move.position = mid + Vector2(cos(k * 0.25), sin(k * 0.25)) * ring
		wheel._gui_input(move)
		await create_timer(0.016).timeout
	var up: InputEventMouseButton = press.duplicate()
	up.pressed = false
	wheel._gui_input(up)
	check(wheel._spin > SpinWheel.FLING, "a fling spins the wheel on (%.1f rad/s)" % wheel._spin)
	await create_timer(5.0).timeout
	check(wheel._spin == 0.0 and got_w.size() == 1, "it slows down, stops on a letter and answers")
	check(got_w.size() == 1 and got_w[0] == str(sw_item.choices[wheel.at_pointer()].id), "with the letter at the pointer")
	sw.free()

	# The developer menu (issue 30, debug builds only; DELETE BEFORE THE FINAL RELEASE with it).
	if DevMenu.allowed():
		DevMenu.toggle(self)
		await _frames()
		var menu: DevMenu = root.get_node_or_null("DevMenu")
		check(menu != null, "the developer menu opens")
		if menu:
			var before := int(gs.wallet.coins)
			menu.add_coins(50)
			check(int(gs.wallet.coins) == before + 50, "the developer menu adds coins")
		DevMenu.toggle(self)
		await _frames()
		check(root.get_node_or_null("DevMenu") == null, "the developer menu closes")

	gs.store.wipe()
	print("ui_smoke: %s" % ("OK" if _failures == 0 else "%d failed" % _failures))
	quit(_failures)
