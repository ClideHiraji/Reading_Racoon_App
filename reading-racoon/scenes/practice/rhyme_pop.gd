extends Control
## Rhyme Pop (D-017): balloons float up; pop the one that rhymes with the word
## on the card. A wrong balloon just wobbles and says its word, no penalty.
## Rounds come from Adventure's rhyme items in the child's unlocked worlds.
## The word card holds its own round speaker; dots show the rounds (D-022).

const ROUNDS := 4
const COLORS := [Palette.BLUE, Palette.ORANGE, Palette.YELLOW, Palette.LEAF]

var _rounds: Array = []
var _round := -1
var _first_try := 0
var _missed := false
var _started := 0
var _sky: Control
var _target: HBoxContainer
var _dots: HBoxContainer
var _results: Array = []
var _balloons: Array = []


func _ready() -> void:
	if not GameState.guard_free_play():
		return
	_started = Time.get_ticks_msec()
	var column := Kit.page(self, "river", 300)
	_dots = Kit.game_header(column, "Rhyme Pop", _back).dots
	var card := Kit.card(14)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size.x = 500
	column.add_child(card)
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 18)
	card.add_child(card_row)
	_target = HBoxContainer.new()
	_target.add_theme_constant_override("separation", 18)
	_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_row.add_child(_target)
	var hear := ChunkyButton.new()
	hear.face_color = Palette.BLUE
	hear.icon_name = "speaker"
	hear.icon_px = 50
	hear.expand_icon = true
	hear.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hear.radius = 48
	hear.lift = 5
	hear.tooltip_text = "Hear it again"
	hear.custom_minimum_size = Vector2(96, 96)
	hear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hear.pressed.connect(_say_round)
	card_row.add_child(hear)
	_sky = Control.new()
	_sky.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sky.clip_contents = true
	column.add_child(_sky)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_rounds = PracticePool.pick(PracticePool.rhymes(GameState.bank, GameState.model.highest_unlocked),
			ROUNDS, rng)
	# Wait for the layout so the balloons know how big the sky is.
	await get_tree().process_frame
	await get_tree().process_frame
	_next()


func _next() -> void:
	_round += 1
	if _round >= _rounds.size():
		_finish()
		return
	_missed = false
	Kit.show_rounds(_dots, _rounds.size(), _results)
	var r: Dictionary = _rounds[_round]
	for c in _target.get_children():
		c.queue_free()
	_target.add_child(Kit.picture(r.picture, 130, 12))   # card corner 26 - padding 14
	var w := Kit.word_label(r.word, 72)
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_target.add_child(w)
	for b in _balloons:
		b.queue_free()
	_balloons.clear()
	var options: Array = [r.rhyme] + r.others
	options.shuffle()
	for i in options.size():
		_add_balloon(options[i], i, options.size(), options[i] == r.rhyme)
	_say_round()


func _say_round() -> void:
	var r: Dictionary = _rounds[_round] if _round < _rounds.size() else {}
	if not r.is_empty():
		Speech.say("Pop the balloon that rhymes with %s!" % r.word)


func _add_balloon(o: Dictionary, i: int, n: int, right: bool) -> void:
	var b := Balloon.new()
	b.word = o.word
	b.picture = o.picture if Icons.exists(o.picture) else ""
	b.color = COLORS[i % COLORS.size()]
	b.tooltip_text = o.word
	_sky.add_child(b)
	var lane := (_sky.size.x - 170.0) / maxf(n - 1, 1)
	var x := lane * i
	var bottom := _sky.size.y
	b.position = Vector2(x, bottom + 40 + i * 70)
	var t := b.create_tween().set_loops()
	t.tween_property(b, "position:y", -260.0, 7.0 + i * 0.8).from(bottom + 20)
	b.pressed.connect(_tap.bind(b, o, right))
	_balloons.append(b)


func _tap(b: Balloon, o: Dictionary, right: bool) -> void:
	if not right:
		_missed = true
		Sfx.play("wrong")
		Speech.say(o.word)
		Kit.shake(b, 14.0)
		return
	if not _missed:
		_first_try += 1
	_results.append("almost" if _missed else "right")
	Kit.show_rounds(_dots, _rounds.size(), _results)
	Sfx.play("pop")
	var r: Dictionary = _rounds[_round]
	Speech.say("%s and %s. They rhyme!" % [r.word, o.word])
	GameState.learn_words([{"word": o.word, "picture": o.picture, "lang": "en"}], "game")
	for other in _balloons:
		if other != b:
			other.disabled = true
	b.pivot_offset = b.size / 2
	var t := create_tween().set_parallel()
	t.tween_property(b, "scale", Vector2(1.5, 1.5), 0.18)
	t.tween_property(b, "modulate:a", 0.0, 0.18)
	await get_tree().create_timer(1.6).timeout
	if is_inside_tree():
		_next()


func _finish() -> void:
	for b in _balloons:
		b.queue_free()
	_balloons.clear()
	var seconds := (Time.get_ticks_msec() - _started) / 1000.0
	var result := GameState.finish_practice("rhyme_pop", _first_try, _rounds.size(), seconds)
	Kit.reward(self, "Pop, pop, hooray!", result, _back)


func _back() -> void:
	Speech.stop()
	get_tree().change_scene_to_file("res://scenes/practice/practice.tscn")
