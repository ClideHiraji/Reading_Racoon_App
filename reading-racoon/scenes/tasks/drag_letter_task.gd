extends VBoxContainer
## Drag-the-missing-letter task (Phonics). Dragging a tile into the gap answers;
## tapping a tile works too, for small hands that find dragging hard (D-007).
## Letters are paper tiles in Andika, the font made for beginning readers (D-009).

signal answered(answer: String, ms: int)

const ANDIKA := preload("res://assets/fonts/Andika-Bold.ttf")

var _slot: DropSlot
var _tiles := {}
var _started := 0
var _locked := false


func setup(item: Dictionary) -> void:
	_started = Time.get_ticks_msec()
	if item.has("picture"):
		var card := PictureCard.new()
		card.setup(item.picture, "", 160.0, 2.0)
		%Stage.add_child(card)
	for ch in item.pattern:
		if ch == "_":
			_slot = DropSlot.new()
			_slot.dropped.connect(_answer)
			%WordRow.add_child(_slot)
		else:
			%WordRow.add_child(_letter_box(ch))
	for c in item.choices:
		var tile := LetterTile.new()
		tile.letter = str(c.id)
		tile.text = c.get("label", c.id)
		tile.face_color = Palette.BLUE
		tile.lift = 9
		tile.custom_minimum_size = Vector2(130, 140)
		tile.add_theme_font_override("font", ANDIKA)
		tile.add_theme_font_size_override("font_size", 76)
		tile.pressed.connect(_answer.bind(tile.letter))
		%Tiles.add_child(tile)
		_tiles[tile.letter] = tile


func _answer(letter: String) -> void:
	if _locked:
		return
	_locked = true
	_slot.show_letter(letter)
	answered.emit(letter, Time.get_ticks_msec() - _started)


## Second try (D-021): the gap empties and the letter tried fades out.
func try_again(chosen: String) -> void:
	_slot.clear()
	if _tiles.has(chosen):
		var tile: ChunkyButton = _tiles[chosen]
		tile.disabled = true
		create_tween().tween_property(tile, "modulate:a", 0.35, 0.2)
	_started = Time.get_ticks_msec()
	_locked = false


func show_result(chosen: String, answer: String) -> void:
	_slot.show_letter(answer)
	_slot.set_color(Palette.RIGHT)   # always show the right word in green
	for l in _tiles:
		var tile: ChunkyButton = _tiles[l]
		tile.disabled = true
		if l == answer:
			tile.face_color = Palette.RIGHT
		elif l == chosen:
			tile.face_color = Palette.ALMOST
		else:
			tile.modulate.a = 0.4


## A printed letter of the word, on its own paper square.
func _letter_box(ch: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(Palette.SHADOW, 0.16)
	sb.shadow_offset = Vector2(0, 6)
	sb.shadow_size = 1
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(118, 140)
	var l := Label.new()
	l.text = ch
	l.theme_type_variation = &"ReadWord"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p
