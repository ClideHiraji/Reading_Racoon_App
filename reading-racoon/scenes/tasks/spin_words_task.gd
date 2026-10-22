extends VBoxContainer
## "Spin the Words" (Phonics, word families): a picture, a paper wheel of first
## sounds and a fixed word ending. Tapping a sound turns it to the pointer and
## builds the word, which answers (no Check step, D-007).

signal answered(answer: String, ms: int)

const ANDIKA := preload("res://assets/fonts/Andika-Bold.ttf")

var _item := {}
var _wheel: SpinWheel
var _onset: Label
var _started := 0
var _locked := false


func setup(item: Dictionary) -> void:
	_item = item
	_started = Time.get_ticks_msec()
	if item.has("picture"):
		var card := PictureCard.new()
		card.setup(item.picture, "", 150.0, 2.5)
		%Stage.add_child(card)
	_wheel = SpinWheel.new()
	_wheel.picked.connect(_on_picked)
	var row: HBoxContainer = %Row
	row.add_child(_wheel)
	row.add_child(_pointer())
	var word := HBoxContainer.new()
	word.add_theme_constant_override("separation", 6)
	_onset = _word_piece("?", Color(Palette.MANGO_DEEP, 0.45))
	word.add_child(_onset.get_parent())
	word.add_child(_word_piece(str(item.rime), Palette.INK).get_parent())
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(word)
	_wheel.setup(item.choices.map(func(c): return c.get("label", c.id)))


func _pointer() -> Control:
	var p := Control.new()
	p.custom_minimum_size = Vector2(36, 60)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.draw.connect(func():
		p.draw_colored_polygon(PackedVector2Array([Vector2(0, 30), Vector2(34, 6), Vector2(34, 54)]),
				Palette.INK))
	return p


func _word_piece(text: String, color: Color) -> Label:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(Palette.SHADOW, 0.16)
	sb.shadow_offset = Vector2(0, 6)
	sb.shadow_size = 1
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	card.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", ANDIKA)
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", color)
	card.add_child(l)
	return l


func _on_picked(i: int) -> void:
	if _locked:
		return
	_locked = true
	_wheel.locked = true
	_wheel.turn_to(i)
	var c: Dictionary = _item.choices[i]
	_onset.text = c.get("label", c.id)
	_onset.add_theme_color_override("font_color", Palette.INK)
	await get_tree().create_timer(0.55).timeout
	answered.emit(str(c.id), Time.get_ticks_msec() - _started)


## Second try (D-021): the sound tried is greyed out and the wheel turns again.
func try_again(chosen: String) -> void:
	for i in _item.choices.size():
		if str(_item.choices[i].id) == chosen:
			_wheel.grey_out(i)
	_onset.text = "?"
	_onset.add_theme_color_override("font_color", Color(Palette.MANGO_DEEP, 0.45))
	_started = Time.get_ticks_msec()
	_locked = false
	_wheel.locked = false


func show_result(chosen: String, answer: String) -> void:
	var right := answer
	for c in _item.choices:
		if str(c.id) == answer:
			right = c.get("label", c.id)
	_onset.text = right
	var ok := chosen == answer
	_onset.add_theme_color_override("font_color", Palette.readable(Palette.deep(Palette.RIGHT)))
	var card: PanelContainer = _onset.get_parent()
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	sb.bg_color = Palette.pale(Palette.RIGHT if ok else Palette.ALMOST, 0.7)
	card.add_theme_stylebox_override("panel", sb)


func answer_text(answer: String) -> String:
	for c in _item.choices:
		if str(c.id) == answer:
			return "%s%s" % [c.get("label", c.id), _item.rime]
	return answer
