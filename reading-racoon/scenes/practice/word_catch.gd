extends Control
## Word Catch (D-017): word leaves drift down; Racoon says a word and the child
## catches it. Missed leaves float back up to the top, so nobody loses. Opens
## after Level 1 (wireframe), with words from the child's unlocked worlds.
## Big word cards that fall slowly, a big Hear the word button and round dots
## (D-022).

const ROUNDS := 6
const LEAVES := 4

var _words: Array = []
var _targets: Array = []
var _round := -1
var _first_try := 0
var _missed := false
var _started := 0
var _field: Control
var _dots: HBoxContainer
var _results: Array = []
var _leaves: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if not GameState.guard_free_play():
		return
	_started = Time.get_ticks_msec()
	_rng.randomize()
	var column := Kit.page(self, "grove", 260)
	_dots = Kit.game_header(column, "Word Catch", _back).dots
	var hear := Kit.button("Hear the word", Palette.BLUE, "speaker", 112)
	hear.add_theme_font_size_override("font_size", 34)
	hear.custom_minimum_size.x = 400
	hear.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hear.pressed.connect(_say_round)
	column.add_child(hear)
	_field = Control.new()
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.clip_contents = true
	column.add_child(_field)
	_words = PracticePool.picture_words(GameState.bank, GameState.model.highest_unlocked)
	_targets = PracticePool.pick(_words, ROUNDS, _rng)
	await get_tree().process_frame
	await get_tree().process_frame
	_next()


func _next() -> void:
	_round += 1
	if _round >= _targets.size():
		_finish()
		return
	_missed = false
	Kit.show_rounds(_dots, _targets.size(), _results)
	for l in _leaves:
		l.queue_free()
	_leaves.clear()
	var target: Dictionary = _targets[_round]
	var others := _words.filter(func(w): return w.word != target.word)
	var leaves := [target] + PracticePool.pick(others, LEAVES - 1, _rng)
	leaves.shuffle()
	for i in leaves.size():
		_add_leaf(leaves[i], i, leaves.size(), leaves[i].word == target.word)
	_say_round()


func _say_round() -> void:
	if _round < _targets.size():
		var t: Dictionary = _targets[_round]
		Speech.say("Catch the word: %s!" % t.word, t.get("lang", "en"))


func _add_leaf(w: Dictionary, i: int, n: int, right: bool) -> void:
	var b := ChunkyButton.new()
	b.card_style = true
	b.text = w.word
	b.add_theme_font_override("font", Kit.ANDIKA)
	b.add_theme_font_size_override("font_size", 56)
	b.radius = 24
	b.custom_minimum_size = Vector2(220, 110)
	b.size = b.custom_minimum_size
	b.tooltip_text = w.word
	_field.add_child(b)
	# Room for the widest word, so no leaf drifts off the edge.
	var lane := (_field.size.x - 280.0) / maxf(n - 1, 1)
	b.position.x = lane * i
	var top := -130.0 - i * 110.0
	var t := b.create_tween().set_loops()
	t.tween_property(b, "position:y", _field.size.y + 20.0, 9.0 + i * 1.4).from(top)
	b.pressed.connect(_catch.bind(b, w, right))
	_leaves.append(b)


func _catch(b: ChunkyButton, w: Dictionary, right: bool) -> void:
	if not right:
		_missed = true
		Sfx.play("wrong")
		Speech.say(w.word, w.get("lang", "en"))
		b.disabled = true
		b.modulate.a = 0.4
		return
	if not _missed:
		_first_try += 1
	_results.append("almost" if _missed else "right")
	Kit.show_rounds(_dots, _targets.size(), _results)
	Sfx.play("correct")
	b.card_style = false
	b.face_color = Palette.LEAF
	GameState.learn_words([w], "game")
	for l in _leaves:
		l.disabled = true
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree():
		_next()


func _finish() -> void:
	for l in _leaves:
		l.queue_free()
	_leaves.clear()
	var seconds := (Time.get_ticks_msec() - _started) / 1000.0
	var result := GameState.finish_practice("word_catch", _first_try, _targets.size(), seconds)
	Kit.reward(self, "Great catching!", result, _back)


func _back() -> void:
	Speech.stop()
	get_tree().change_scene_to_file("res://scenes/practice/practice.tscn")
