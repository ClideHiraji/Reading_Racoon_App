extends VBoxContainer
## Tap-one-card task: rhyme, picture-word match, letter sounds, syllable claps.
## Answers on tap, no "Check" step (D-007). 2-4 big paper cards (NFR-02) with
## tinted SVG pictures and Andika letters (D-009).

signal answered(answer: String, ms: int)

var _cards := {}
var _started := 0
var _locked := false


func setup(item: Dictionary) -> void:
	_started = Time.get_ticks_msec()
	if item.has("picture") or item.has("word"):
		var card := PictureCard.new()
		card.setup(item.get("picture", ""), item.get("word", ""), 170.0)
		%Stage.add_child(card)
	else:
		%Stage.hide()
	var choices: Array = item.choices
	var grid: GridContainer = %Choices
	grid.columns = 2 if choices.size() == 4 else choices.size()
	var wide := choices.size() <= 2 or choices.size() == 4
	var has_pictures := choices.any(func(c): return c.has("picture"))
	for c in choices:
		var card := ChunkyButton.new()
		card.card_style = true
		card.lift = 8
		card.custom_minimum_size = Vector2(300 if wide else 200, 220 if has_pictures else 170)
		card.pressed.connect(_on_card.bind(str(c.id)))
		card.add_child(_card_content(c, has_pictures))
		grid.add_child(card)
		_cards[str(c.id)] = card


func _card_content(c: Dictionary, has_pictures: bool) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 4)
	if c.has("picture"):
		var count := int(c.get("repeat", 1))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", -6)
		var px := (110.0 if not c.has("label") else 96.0) / (1.0 if count == 1 else 1.7)
		for i in count:
			var icon := Icons.rect(c.picture, px, Icons.picture_color(c.picture))
			icon.name = "Icon%d" % i
			row.add_child(icon)
		box.add_child(row)
	if c.has("label"):
		var l := Label.new()
		l.name = "Word"
		l.text = c.label
		l.theme_type_variation = &"ReadLabel" if has_pictures else &"ReadWord"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	return box


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
		if id == answer or id == chosen:
			card.card_style = false
			card.face_color = Palette.RIGHT if id == answer else Palette.ALMOST
			_whiten(card)
		else:
			card.modulate.a = 0.45
	if _cards.has(answer):
		var c: Control = _cards[answer]
		c.pivot_offset = c.size / 2
		var t := create_tween()
		t.tween_property(c, "scale", Vector2(1.08, 1.08), 0.1)
		t.tween_property(c, "scale", Vector2.ONE, 0.15)


func _whiten(node: Node) -> void:
	for child in node.get_children():
		if child is TextureRect:
			child.self_modulate = Color.WHITE
		elif child is Label:
			child.add_theme_color_override("font_color", Color.WHITE)
		_whiten(child)
