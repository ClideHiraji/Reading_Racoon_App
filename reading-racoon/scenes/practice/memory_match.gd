extends Control
## Memory Match (D-017, wireframe "Practice game: Memory Match"): find the word
## that goes with each picture. Every card says its word when it flips. No timer
## and no losing; matched words go to My Word Book. From My Word Book it plays
## with the child's own words (GameState.practice_words). One dot per pair in
## the header (D-022).

const PAIRS := 6
const BACK_COLOR := Palette.BLUE

var _cards: Array = []      # {holder, button, face, pair, kind, open, done}
var _open: Array = []
var _matched := 0
var _pairs := 0
var _busy := false
var _started := 0
var _dots: HBoxContainer
var _bubble: SpeechBubble
var _raccoon: Raccoon
var _from_words := false


func _ready() -> void:
	if not GameState.guard_free_play():
		return
	_started = Time.get_ticks_msec()
	_from_words = not GameState.practice_words.is_empty()
	var column := Kit.page(self)
	_dots = Kit.game_header(column, "Memory Match", _back).dots

	var talk := HBoxContainer.new()
	talk.add_theme_constant_override("separation", 12)
	_raccoon = Raccoon.new()
	_raccoon.custom_minimum_size = Vector2(130, 130)
	talk.add_child(_raccoon)
	_bubble = SpeechBubble.new()
	_bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	talk.add_child(_bubble)
	column.add_child(talk)

	var words := GameState.practice_words if _from_words \
			else PracticePool.picture_words(GameState.bank, GameState.model.highest_unlocked)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chosen := PracticePool.pick(words, PAIRS, rng)
	_pairs = chosen.size()
	var deck := []
	for i in chosen.size():
		deck.append({"pair": i, "kind": "picture", "word": chosen[i]})
		deck.append({"pair": i, "kind": "word", "word": chosen[i]})
	deck.shuffle()
	var grid := GridContainer.new()
	grid.columns = 3 if deck.size() > 8 else 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	for d in deck:
		grid.add_child(_card(d))
	_update_count()
	await get_tree().process_frame
	_say("Find the word that goes with each picture!", "happy")


func _card(d: Dictionary) -> Control:
	# A plain holder in the grid, so flipping (scale) isn't reset by the container.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(196, 196)
	var b := ChunkyButton.new()
	b.face_color = BACK_COLOR
	b.icon_name = "raccoon"
	b.icon_px = 80
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.radius = 24
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(b)
	var face := VBoxContainer.new()
	face.alignment = BoxContainer.ALIGNMENT_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.visible = false
	if d.kind == "picture":
		var pic := Kit.picture(d.word.picture, 140)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		face.add_child(pic)
	else:
		face.add_child(Kit.word_label(d.word.word, 50))
	b.add_child(face)
	var c := {"holder": holder, "button": b, "face": face, "pair": d.pair, "word": d.word,
			"open": false, "done": false}
	b.pressed.connect(_tap.bind(c))
	_cards.append(c)
	return holder


func _tap(c: Dictionary) -> void:
	if _busy or c.open or c.done:
		return
	_flip(c, true)
	Speech.say(c.word.word, c.word.get("lang", "en"))
	_open.append(c)
	if _open.size() < 2:
		return
	var a: Dictionary = _open[0]
	var b: Dictionary = _open[1]
	_open.clear()
	if a.pair == b.pair:
		for x in [a, b]:
			x.done = true
			x.button.face_color = Palette.pale(Palette.LEAF, 0.45)
		_matched += 1
		Sfx.play("correct")
		_update_count()
		GameState.learn_words([a.word], "game")
		if _matched == _pairs:
			_finish()
		else:
			_say("A match! %s!" % a.word.word.capitalize(), "happy")
		return
	_busy = true
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	_flip(a, false)
	_flip(b, false)
	_busy = false


func _flip(c: Dictionary, up: bool) -> void:
	c.open = up
	var b: ChunkyButton = c.button
	b.pivot_offset = b.size / 2
	var t := create_tween()
	t.tween_property(b, "scale:x", 0.0, 0.08)
	t.tween_callback(func():
		c.face.visible = up
		b.card_style = up
		b.icon_name = "" if up else "raccoon")
	t.tween_property(b, "scale:x", 1.0, 0.08)


func _update_count() -> void:
	var found := []
	found.resize(_matched)
	found.fill("right")
	Kit.show_rounds(_dots, _pairs, found)


func _say(text: String, mood: String) -> void:
	_raccoon.set_mood(mood)
	_bubble.say(text)


func _finish() -> void:
	_say("You matched them all!", "celebrate")
	var seconds := (Time.get_ticks_msec() - _started) / 1000.0
	var result := GameState.finish_practice("memory_match", _pairs, _pairs, seconds)
	await get_tree().create_timer(0.8).timeout
	if is_inside_tree():
		Kit.reward(self, "You matched them all!", result, _back)


func _back() -> void:
	Speech.stop()
	var to := "res://scenes/collection/words.tscn" if _from_words else "res://scenes/practice/practice.tscn"
	GameState.practice_words = []
	get_tree().change_scene_to_file(to)
