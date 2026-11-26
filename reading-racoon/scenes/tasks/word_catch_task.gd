extends BoxContainer
## Word Catch as a lesson task (D-043): the answers are word cards that drift down like leaves, the look
## of Practice's Word Catch, so the child knows that game when they meet it there. Racoon says the word
## (the prompt) and the child catches its card. The cards settle and wait, so speed never decides the
## answer; a tap answers, even mid-fall (D-007). Content: a tap_choice item with "variant": "word_catch".

signal answered(answer: String, ms: int)

const CARD := Vector2(240, 120)
const FIELD := Vector2(640, 420)
## Where the cards come to rest in the field, for 2, 3 or 4 answers (none overlap).
const SPOTS := {
	2: [Vector2(40, 90), Vector2(360, 210)],
	3: [Vector2(0, 40), Vector2(380, 110), Vector2(190, 270)],
	4: [Vector2(0, 20), Vector2(380, 70), Vector2(40, 240), Vector2(400, 290)],
}

var _cards := {}                  # answer id -> card (the lesson points at the right one)
var _started := 0
var _locked := false


func setup(item: Dictionary) -> void:
	_started = Time.get_ticks_msec()
	vertical = true
	alignment = BoxContainer.ALIGNMENT_CENTER
	var field := Control.new()
	field.custom_minimum_size = FIELD
	field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(field)
	var choices: Array = item.choices
	var spots: Array = SPOTS[clampi(choices.size(), 2, 4)]
	for i in choices.size():
		var c: Dictionary = choices[i]
		var b := ChunkyButton.new()
		b.card_style = true
		b.text = str(c.get("label", c.id))
		b.add_theme_font_override("font", Kit.ANDIKA)
		b.add_theme_font_size_override("font_size", 56)
		b.radius = 24
		b.custom_minimum_size = CARD
		b.size = CARD
		b.pivot_offset = CARD / 2
		b.tooltip_text = b.text
		field.add_child(b)
		var rest: Vector2 = spots[i % spots.size()]
		b.position = Vector2(rest.x, -CARD.y - 60.0 - i * 90.0)
		b.rotation = deg_to_rad(-8.0 if i % 2 == 0 else 8.0)
		# Down like a leaf, then a slow sway where it landed.
		var fall := b.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		fall.tween_property(b, "position:y", rest.y, 1.3 + i * 0.3)
		fall.tween_property(b, "rotation", 0.0, 1.3 + i * 0.3)
		fall.chain().tween_callback(_sway.bind(b, i))
		b.pressed.connect(_on_catch.bind(str(c.id)))
		_cards[str(c.id)] = b


func _sway(b: Control, i: int) -> void:
	var t := b.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	t.tween_property(b, "rotation", deg_to_rad(2.0), 1.4 + i * 0.2)
	t.tween_property(b, "rotation", deg_to_rad(-2.0), 1.4 + i * 0.2)


func _on_catch(id: String) -> void:
	if _locked:
		return
	_locked = true
	answered.emit(id, Time.get_ticks_msec() - _started)


## Second try (D-021): the card tried fades and can't be caught again.
func try_again(chosen: String) -> void:
	if _cards.has(chosen):
		var b: ChunkyButton = _cards[chosen]
		b.disabled = true
		create_tween().tween_property(b, "modulate:a", 0.4, 0.2)
	_started = Time.get_ticks_msec()
	_locked = false


## Colors the caught card and always shows the right one in green (as the tap cards do).
func show_result(chosen: String, answer: String) -> void:
	for id in _cards:
		var b: ChunkyButton = _cards[id]
		b.disabled = true
		if id == answer or id == chosen:
			b.card_style = false
			b.face_color = Palette.RIGHT if id == answer else Palette.ALMOST
		else:
			b.modulate.a = 0.45
