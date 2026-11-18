extends SceneTree
## Scratch test: a tour of the game that times every frame (vsync off, so a frame's time is its real
## cost). Each screen is opened the way the game opens it; its moments are played. Twice: the first
## pass is the child's first visit (loading, shaders, textures); the second is a warm revisit.
##   Godot --path <copy> --resolution 576x1024 -s res://perf_tour.gd -- <out.json>
## (copy this file into a scratch copy of the game first; see tools/perf/README.md)

var phase := "boot"
var frames: Array = []          # [pass, phase, wall ms, process ms, render cpu ms, gpu ms]
var pass_n := 1
var running := true
var vp: RID
var gs: Node


func _initialize() -> void:
	_run.call_deferred()


func _logger() -> void:
	var last := Time.get_ticks_usec()
	while running:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append([pass_n, phase, (now - last) / 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
			RenderingServer.viewport_get_measured_render_time_gpu(vp)])
		last = now


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _go(label: String, path: String, settle := 2.5) -> void:
	phase = label + " · open"
	change_scene_to_file(path)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	phase = label
	await _wait(settle)


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	AudioServer.set_bus_mute(0, true)
	gs = root.get_node("GameState")
	root.get_node("Speech")._voices = {}        # no read-aloud through the speakers
	_logger()
	for p in 2:
		pass_n = p + 1
		_reset()
		await _tour()
	running = false
	await process_frame
	var out: String = OS.get_cmdline_user_args()[0]
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(frames))
	f.close()
	print("frames ", frames.size(), " saved ", out)
	quit()


func _reset() -> void:
	gs.reset_progress()
	gs.device = {"token": "", "student_name": "Ana", "student_id": 0}
	gs.assessments = {"pre": {"total": 20}}
	gs.wallet = {"xp": 140, "coins": 120}
	gs.model.highest_unlocked = 3
	gs.access.schedule = AccessPolicy.DEFAULTS.duplicate()
	gs._debug_now = {"year": 2026, "month": 10, "day": 19, "weekday": 1, "hour": 7, "minute": 45, "second": 0}
	gs.usage = {"date": gs.today(), "minutes": 0.0, "free_minutes": 0.0}
	gs.learn_words(PracticePool.picture_words(gs.bank, 3).slice(0, 9), "lesson")


func _tour() -> void:
	await _go("start screen", "res://scenes/main.tscn")
	if pass_n == 1:
		phase = "start screen (screens loading in the background)"
		var pl = gs.get("preloader")
		var t0 := Time.get_ticks_msec()
		while pl != null and pl.is_processing() and Time.get_ticks_msec() - t0 < 15000:
			await process_frame
		print("background loading: %d screens in %.1f s" % [pl.loaded_count() if pl else 0, (Time.get_ticks_msec() - t0) / 1000.0])
	await _go("home", "res://scenes/hub/hub.tscn", 3.0)
	await _go("learning path", "res://scenes/path/learning_path.tscn")
	# a lesson: hello and reading along, a wrong try (hint), a second wrong (answer and why), right answers
	gs.lesson_mode = "lesson"
	gs.lesson_world = 1
	gs.lesson_node = 0
	gs.lesson_seed = 5
	await _go("lesson", "res://scenes/lesson/lesson.tscn", 3.0)
	var lesson := current_scene
	var item: Dictionary = lesson._item
	var wrong := "__wrong__"
	for c in item.get("choices", []):
		if str(c.id) != str(item.answer):
			wrong = str(c.id)
	phase = "lesson · wrong try (hint)"
	lesson._task.answered.emit(wrong, 900)
	await _wait(2.5)
	phase = "lesson · second wrong (answer)"
	lesson._task.answered.emit(wrong, 900)
	await _wait(4.0)
	for k in 6:
		if current_scene != lesson or lesson._task == null or not lesson._task.has_signal("answered"):
			break
		phase = "lesson · right answer"
		lesson._task.answered.emit(str(lesson._item.get("answer", "")), 900)
		await _wait(2.6)
	phase = "lesson · finish"
	if current_scene == lesson:
		lesson._finish()
	await process_frame
	await process_frame
	phase = "lesson complete"
	await _wait(4.0)
	await _go("closet", "res://scenes/shop/shop.tscn")
	phase = "closet · scarves tab"
	current_scene._show_slot("neck")
	await _wait(1.2)
	phase = "closet · try on"
	current_scene.raccoon.outfit = {"neck": "scarf_coral", "paws": "open_book"}
	await _wait(1.2)
	gs._debug_now = {"year": 2026, "month": 10, "day": 20, "weekday": 2, "hour": 18, "minute": 0, "second": 0}
	await _go("practice", "res://scenes/practice/practice.tscn")
	gs.practice_game = "memory_match"
	await _go("memory match", "res://scenes/practice/memory_match.tscn")
	await _go("rhyme pop", "res://scenes/practice/rhyme_pop.tscn", 3.0)
	await _go("word catch", "res://scenes/practice/word_catch.tscn", 3.0)
	gs.practice_game = "syllable_train"
	await _go("syllable train", "res://scenes/practice/practice_round.tscn")
	await _go("library", "res://scenes/library/library.tscn")
	gs.open_book = "bangka-ni-lolo"
	await _go("reader", "res://scenes/library/reader.tscn", 3.0)
	await _go("watch", "res://scenes/watch/watch.tscn")
	gs.open_media = "abc-chant"
	await _go("player", "res://scenes/watch/player.tscn", 3.0)
	await _go("stickers", "res://scenes/collection/stickers.tscn")
	await _go("words", "res://scenes/collection/words.tscn")
	await _go("today", "res://scenes/collection/today.tscn")
	gs._debug_now = {"year": 2026, "month": 10, "day": 19, "weekday": 1, "hour": 22, "minute": 0, "second": 0}
	await _go("lock screen", "res://scenes/lock/lock_screen.tscn")
