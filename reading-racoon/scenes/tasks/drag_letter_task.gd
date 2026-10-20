extends VBoxContainer
## Drag-the-missing-letter task (Phonics). Dragging a tile into the gap answers;
## tapping a tile works too, for small hands that find dragging hard (D-007).

signal answered(answer: String, ms: int)

const GREEN := Color("6bbf59")
const SOFT_ORANGE := Color("ffa94d")
const TILE_BLUE := Color("3fa7d6")

var _slot: DropSlot
var _tiles := {}
var _started := 0
var _locked := false


func setup(item: Dictionary) -> void:
	_started = Time.get_ticks_msec()
	%Picture.text = item.get("picture", "")
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
		tile.face_color = TILE_BLUE
		tile.custom_minimum_size = Vector2(130, 140)
		tile.add_theme_font_override("font", preload("res://assets/fonts/Andika-Bold.ttf"))
		tile.add_theme_font_size_override("font_size", 72)
		tile.pressed.connect(_answer.bind(tile.letter))
		%Tiles.add_child(tile)
		_tiles[tile.letter] = tile


func _answer(letter: String) -> void:
	if _locked:
		return
	_locked = true
	_slot.show_letter(letter)
	answered.emit(letter, Time.get_ticks_msec() - _started)


func show_result(chosen: String, answer: String) -> void:
	_slot.show_letter(answer)
	_slot.set_color(GREEN)   # always show the right word in green
	for l in _tiles:
		var tile: ChunkyButton = _tiles[l]
		tile.disabled = true
		if l == answer:
			tile.face_color = GREEN
		elif l == chosen:
			tile.face_color = SOFT_ORANGE
		else:
			tile.modulate.a = 0.4


func _letter_box(ch: String) -> Control:
	var l := Label.new()
	l.text = ch
	l.theme_type_variation = &"ReadWord"
	l.custom_minimum_size = Vector2(110, 140)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
