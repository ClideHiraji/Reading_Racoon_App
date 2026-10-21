extends SceneTree
## Screenshots of Practice, the Library, Watch & Listen and the collections
## (D-017), for visual review (needs a window, not headless):
##   "C:\Program Files\Godot\Godot.exe" --path reading-racoon --resolution 720x1280
##       -s res://tests/section_shots.gd -- --profile=shots --fresh --out=C:/some/folder

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


func _open(path: String) -> void:
	change_scene_to_file(path)
	await _frames(8)


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset_progress()
	gs.device = {"token": "", "student_name": "Ana", "student_id": 0}
	gs.assessments = {"pre": {"total": 20}}
	gs.wallet = {"xp": 140, "coins": 120}
	gs.model.highest_unlocked = 3
	for g in ["adventure", "adventure", "adventure", "books", "games", "days", "watch"]:
		gs.collection.earn(g, gs.today())
	gs.learn_words(PracticePool.picture_words(gs.bank, 3).slice(0, 9), "lesson")
	gs.collection.complete_goal("story", gs.today())
	gs.collection.mark_day(gs.today())

	await _open("res://scenes/practice/practice.tscn")
	await _shot("p1_practice")
	gs.practice_game = "memory_match"
	await _open("res://scenes/practice/memory_match.tscn")
	var mm := current_scene
	var pair: Array = mm._cards.filter(func(c): return c.pair == 0)
	mm._tap(pair[0])
	mm._tap(pair[1])
	mm._tap(mm._cards.filter(func(c): return c.pair == 1)[0])
	await _shot("p2_memory_match")
	await _open("res://scenes/practice/rhyme_pop.tscn")
	await _frames(90)
	await _shot("p3_rhyme_pop")
	await _open("res://scenes/practice/word_catch.tscn")
	await _frames(80)
	await _shot("p4_word_catch")
	gs.practice_game = "syllable_train"
	await _open("res://scenes/practice/practice_round.tscn")
	await _shot("p5_syllable_train")

	await _open("res://scenes/library/library.tscn")
	await _shot("l1_library")
	gs.open_book = "bangka-ni-lolo"
	await _open("res://scenes/library/reader.tscn")
	current_scene._reading = false
	current_scene._text.stop()
	current_scene._text._light(1)
	await _shot("l2_reader")
	current_scene._questions()
	await _shot("l3_questions")

	await _open("res://scenes/watch/watch.tscn")
	await _shot("w1_watch")
	gs.open_media = "abc-chant"
	await _open("res://scenes/watch/player.tscn")
	await _frames(30)
	await _shot("w2_player")
	var result := {"coins": 13, "stickers": ["speaker", "star"], "goals_done": true}
	Kit.reward(current_scene, "What a show!", result, func(): pass)
	await _shot("w3_reward")

	await _open("res://scenes/collection/stickers.tscn")
	await _shot("c1_stickers")
	await _open("res://scenes/collection/words.tscn")
	await _shot("c2_words")
	await _open("res://scenes/collection/today.tscn")
	await _shot("c3_today")
	quit()
