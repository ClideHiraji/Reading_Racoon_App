extends BoxContainer
## Tap-one-card task: rhyme, picture-word match, letter sounds, syllable claps.
## A tap answers right away (no Check button). 2-4 big paper cards with
## tinted SVG pictures and Andika letters.

signal answered(answer: String, ms: int)

const ROW_W := 640.0
const ROW_PX := 36

var _cards := {}
var _started := 0
var _locked := false


func setup(item: Dictionary) -> void:
	_started = Time.get_ticks_msec()
	var word: String = item.get("sentence", item.get("word", ""))
	if item.has("picture") or word != "":
		var card := PictureCard.new()
		card.setup(item.get("picture", ""), word, 150.0 if word.contains(" ") else 170.0)
		%Stage.add_child(card)
	else:
		%Stage.hide()
	var choices: Array = item.choices
	var grid: GridContainer = %Choices
	var has_pictures := choices.any(func(c): return c.has("picture"))
	var wide := choices.size() <= 2 or choices.size() == 4
	var card_w := 310.0 if wide else 210.0
	# Long answers (story questions, polite phrases) stack as full-width cards, and so do
	# picture words too wide for their card ("a paper star").
	var long := choices.any(func(c): return str(c.get("label", "")).length() > 12 \
			or (not has_pictures and str(c.get("label", "")).length() > 7) \
			or (has_pictures and _text_w(str(c.get("label", "")), 46) > card_w - 24.0))
	grid.columns = 1 if long else (2 if choices.size() == 4 else choices.size())
	for c in choices:
		var card := ChunkyButton.new()
		card.card_style = true
		card.lift = 8
		card.radius = 28
		card.custom_minimum_size = Vector2(card_w, 250 if has_pictures else 180)
		if long:
			var base := 110.0 if not has_pictures else 130.0
			if Kit.landscape():   # cards stay at least 96 px tall
				base = 96.0 if not has_pictures else 110.0
			card.custom_minimum_size = Vector2(ROW_W, _row_height(c, base))
		card.pressed.connect(_on_card.bind(str(c.id)))
		card.add_child(_row_content(c) if long else _card_content(c, has_pictures))
		grid.add_child(card)
		_cards[str(c.id)] = card
	# On a laptop the picture stands beside the choices.
	if Kit.landscape() and %Stage.visible:
		vertical = false
		add_theme_constant_override("separation", 48)
		%Choices.size_flags_vertical = Control.SIZE_SHRINK_CENTER   # level with the picture, not its top


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
		var px := (130.0 if not c.has("label") else 116.0) / (1.0 if count == 1 else 1.7)
		for i in count:
			var icon := Icons.picture_rect(c.picture, px)
			icon.name = "Icon%d" % i
			row.add_child(icon)
		box.add_child(row)
	if c.has("label"):
		var l := Label.new()
		l.name = "Word"
		l.text = c.label
		l.theme_type_variation = &"ReadLabel" if has_pictures else &"ReadWord"
		if not has_pictures and str(c.label).length() > 3:
			l.add_theme_font_size_override("font_size", 60 if str(c.label).length() <= 6 else 44)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	return box


## How wide `text` is in the reading font at `px`.
static func _text_w(text: String, px: int) -> float:
	return ThemeDB.get_project_theme().get_font(&"font", &"ReadLabel").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


## A row card tall enough for its words on as many lines as they need at the row's
## narrowest (a three-line story answer used to overflow a one-line card).
static func _row_height(c: Dictionary, base: float) -> float:
	var font := ThemeDB.get_project_theme().get_font(&"font", &"ReadLabel")
	var width := ROW_W - 46.0 - (90.0 if c.has("picture") else 0.0)   # the row's margins and picture
	var h := font.get_multiline_string_size(str(c.get("label", c.id)), HORIZONTAL_ALIGNMENT_LEFT,
			width, ROW_PX).y
	return maxf(base, h + 30.0)


## A full-width answer row: optional small picture, then the words (Andika).
func _row_content(c: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 26
	row.offset_right = -20
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 18)
	if c.has("picture"):
		var icon := Icons.picture_rect(c.picture, 72)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	var l := Label.new()
	l.name = "Word"
	l.text = c.get("label", c.id)
	l.theme_type_variation = &"ReadLabel"
	l.add_theme_font_size_override("font_size", ROW_PX)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	return row


func _on_card(id: String) -> void:
	if _locked:
		return
	_locked = true
	answered.emit(id, Time.get_ticks_msec() - _started)


## Second try: the wrong card fades, gets an orange "almost" edge and can't be tapped again.
func try_again(chosen: String) -> void:
	if _cards.has(chosen):
		var card: ChunkyButton = _cards[chosen]
		card.disabled = true
		var sb: PaperBox = card.get_theme_stylebox("disabled").duplicate()
		sb.border_color = Palette.ALMOST
		sb.set_border_width_all(5)
		card.add_theme_stylebox_override("disabled", sb)
		create_tween().tween_property(card, "modulate:a", 0.5, 0.2)
	_started = Time.get_ticks_msec()
	_locked = false


## Colors the tapped card and always shows the right one in green.
func show_result(chosen: String, answer: String) -> void:
	for id in _cards:
		var card: ChunkyButton = _cards[id]
		card.disabled = true
		if id == answer or id == chosen:
			card.card_style = false
			card.face_color = Palette.RIGHT if id == answer else Palette.ALMOST
			_ink(card, Palette.text_on(card.face_color))
		else:
			card.modulate.a = 0.45
	if _cards.has(answer):
		var c: Control = _cards[answer]
		c.pivot_offset = c.size / 2
		var t := create_tween()
		t.tween_property(c, "scale", Vector2(1.08, 1.08), 0.1)
		t.tween_property(c, "scale", Vector2.ONE, 0.15)


## Recolours the card's icon and words so they read on its new colour. A full-colour
## picture stays untinted; tinting it made a black shape.
func _ink(node: Node, col: Color) -> void:
	for child in node.get_children():
		if child is TextureRect and child.self_modulate != Color.WHITE:
			child.self_modulate = col
		elif child is Label:
			child.add_theme_color_override("font_color", col)
		_ink(child, col)
