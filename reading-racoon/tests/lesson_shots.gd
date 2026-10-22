extends SceneTree
## Screenshots of the D-021 screens for visual review (needs a window, not headless):
## pre/post-test results by skill, the second try with Racoon's hint, SKIP at one
## heart, the stop dialog and the lesson-complete stamps.
##   "C:\Program Files\Godot\Godot.exe" --path reading-racoon --resolution 720x1280
##       -s res://tests/lesson_shots.gd -- --profile=shots --fresh --out=C:/some/folder

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


## Plays a whole test: right answers for the skills in `strong`, and the first
## `partly` answers right for the others.
func _play_test(gs: Node, kind: String, strong: Array, partly: int) -> void:
	gs.lesson_mode = kind
	var s: AssessmentSession = gs.new_session()
	var seen := {}
	while true:
		var it := s.next_item()
		if it.is_empty():
			break
		seen[it.sub_skill] = seen.get(it.sub_skill, 0) + 1
		var right: bool = strong.has(it.sub_skill) or seen[it.sub_skill] <= partly
		if s.submit(it.answer if right else "__wrong__", 900).next == "done":
			break
	gs.finish_lesson(s)


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset_progress()
	gs.device = {"token": "", "student_name": "Ana", "student_id": 0}

	change_scene_to_file("res://scenes/path/learning_path.tscn")
	await _shot("t0_map_pretest_card")
	_play_test(gs, "pre", [SkillCatalog.PA, SkillCatalog.VOCAB], 1)
	change_scene_to_file("res://scenes/lesson/lesson_complete.tscn")
	await _shot("t1_pretest_results")
	_play_test(gs, "post", [SkillCatalog.PA, SkillCatalog.PHONICS, SkillCatalog.VOCAB], 2)
	change_scene_to_file("res://scenes/lesson/lesson_complete.tscn")
	await _shot("t2_posttest_results")

	gs.lesson_mode = "lesson"
	gs.lesson_world = 1
	gs.lesson_node = 0
	gs.lesson_seed = 5
	change_scene_to_file("res://scenes/lesson/lesson.tscn")
	await _frames(8)
	var lesson := current_scene
	var wrong := "__wrong__"
	for c in lesson._item.get("choices", []):
		if str(c.id) != str(lesson._item.answer):
			wrong = str(c.id)
			break
	lesson._task.answered.emit(wrong, 900)
	await _shot("t3_hint_first_wrong")
	lesson._task.answered.emit("__wrong__", 900)
	await _shot("t4_answer_and_why")
	lesson._on_continue()
	await _frames(4)
	lesson._task.answered.emit(str(lesson._item.answer), 800)
	await _frames(12)
	await _shot("t5_right_no_popup")
	lesson._on_continue()
	await _frames(4)
	lesson._on_close()
	await _shot("t6_stop_dialog")
	lesson.get_node("%OverlayPrimary").pressed.emit()
	for i in 30:
		if current_scene != lesson:
			break
		if lesson.session.tries == 0 and i % 3 == 0 and not lesson.session.in_rescue():
			lesson._task.answered.emit("__wrong__", 900)
			await _frames(3)
		if not lesson.sheet.visible:
			lesson._task.answered.emit(str(lesson._item.answer), 800)
			await _frames(3)
		lesson._on_continue()
		await _frames(5)
	await _shot("t7_lesson_complete")
	quit()
