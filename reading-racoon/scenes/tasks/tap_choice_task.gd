extends VBoxContainer
## Tap-one-card task: rhyme, picture-word match, letter sounds, syllable claps.
## Answers on tap, no separate "Check" step (D-007). 2-4 big cards (NFR-02).

signal answered(answer: String, ms: int)

const GREEN := Color("6bbf59")
const SOFT_ORANGE := Color("ffa94d")

var _cards := {}
var _started := 0
var _locked := false


func setup(item: Dictionary) -> void:
	_started = Time.get_ticks_msec()
	%Picture.text = item.get("picture", "")
	%Picture.visible = item.has("picture")
	%Word.text = item.get("word", "")
	%Word.visible = item.has("word")
	var choices: Array = item.choices
	var grid: GridContainer = %Choices
	grid.columns = 2 if choices.size() == 4 else choices.size()
	var wide := choices.size() <= 2 or choices.size() == 4
	var has_pictures := choices.any(func(c): return c.has("picture"))
	for c in choices:
		var card := ChunkyButton.new()
		card.card_style = true
		card.custom_minimum_size = Vector2(300 if wide else 200, 210 if has_pictures else 170)
		card.pressed.connect(_on_card.bind(str(c.id)))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_bottom = -10
		if c.has("picture"):
			box.add_child(_label(c.picture, 64 if c.picture.length() <= 2 else 40, ""))
		if c.has("label"):
			box.add_child(_label(c.label, 0, "ReadLabel" if has_pictures else "ReadWord"))
		card.add_child(box)
		grid.add_child(card)
		_cards[str(c.id)] = card


func _on_card(id: String) -> void:
	if _locked:
		return
	_locked = true
	answered.emit(id, Time.get_ticks_msec() - _started)


## Colors the tapped card and always shows the right one in green.
func show_result(chosen: String, answer: String) -> void:
	for id in _cards:
		var card: ChunkyButton = _cards[id]
		card.disabled = true
		if id == answer:
			card.card_style = false
			card.face_color = GREEN
		elif id == chosen:
			card.card_style = false
			card.face_color = SOFT_ORANGE
		else:
			card.modulate.a = 0.5
	if _cards.has(answer):
		var c: Control = _cards[answer]
		c.pivot_offset = c.size / 2
		var t := create_tween()
		t.tween_property(c, "scale", Vector2(1.08, 1.08), 0.1)
		t.tween_property(c, "scale", Vector2.ONE, 0.15)


func _label(text: String, font_size: int, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if variation != "":
		l.theme_type_variation = variation
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	return l
