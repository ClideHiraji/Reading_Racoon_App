extends VBoxContainer
## Put-it-in-order task: build a word from syllable tiles (Phonological Awareness,
## Phonics), build a sentence from word tiles (Fluency: left-to-right reading,
## RL1BPK-I-3), or put story events in order (Literal Comprehension, RL1CAT-I-2b).
## Tap a tile to place it in the next empty slot; tap a placed tile to take it
## back. The answer is the tile keys joined with "|", sent once every slot is full.

signal answered(answer: String, ms: int)

const ANDIKA := preload("res://assets/fonts/Andika-Bold.ttf")

var _item := {}
var _variant := "sentence"         # syllables | sentence | sequence
var _slots: Array[Control] = []
var _placed: Array = []            # tile key per slot, "" when empty
var _tiles := {}                   # key -> ChunkyButton
var _started := 0
var _locked := false


func setup(item: Dictionary) -> void:
	_item = item
	_variant = item.get("variant", "sentence")
	_started = Time.get_ticks_msec()
	if item.has("picture"):
		var card := PictureCard.new()
		card.setup(item.picture, "", 150.0, -2.0)
		%Stage.add_child(card)
	else:
		%Stage.hide()
	var tiles: Array = item.tiles.duplicate()
	var keys := tiles.map(func(t): return QuestionBank.tile_key(t))
	_placed.resize(tiles.size())
	_placed.fill("")
	var slot_box := _box()
	%SlotsHolder.add_child(slot_box)
	for i in tiles.size():
		var slot := _slot(i)
		slot_box.add_child(slot)
		_slots.append(slot)
	# Shuffle the tiles, but never show them already in the right order.
	var order := range(tiles.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(item.id)
	for attempt in 6:
		_shuffle(order, rng)
		if order != range(tiles.size()):
			break
	var tile_box := _box()
	%TilesHolder.add_child(tile_box)
	for i in order:
		var t = tiles[i]
		var key: String = keys[i]
		var b := _tile_button(t)
		b.pressed.connect(_on_tile.bind(key))
		tile_box.add_child(b)
		_tiles[key] = b


func _box() -> Container:
	if _variant == "sequence":
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		return v
	var f := HFlowContainer.new()
	f.alignment = FlowContainer.ALIGNMENT_CENTER
	f.add_theme_constant_override("h_separation", 12)
	f.add_theme_constant_override("v_separation", 14)
	return f


func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _tile_text(t) -> String:
	return str(t.text) if t is Dictionary else str(t)


func _tile_button(t) -> ChunkyButton:
	var b := ChunkyButton.new()
	b.face_color = Palette.BLUE if _variant != "sequence" else Palette.CARD
	b.card_style = _variant == "sequence"
	b.lift = 8
	b.text = _tile_text(t)
	b.add_theme_font_override("font", ANDIKA)
	match _variant:
		"syllables":
			b.add_theme_font_size_override("font_size", 64)
			b.custom_minimum_size = Vector2(150, 120)
		"sentence":
			b.add_theme_font_size_override("font_size", 44)
			b.custom_minimum_size = Vector2(110, 96)
		_:
			b.add_theme_font_size_override("font_size", 32)
			b.custom_minimum_size = Vector2(620, 96)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if t is Dictionary and t.has("picture"):
				b.icon = Icons.tex(t.picture)
				b.icon_px = 56
				b.icon_tint = Icons.picture_color(t.picture)
	return b


## An empty slot: a dashed paper outline, numbered for story events.
func _slot(i: int) -> Control:
	var s := DropSlot.new()
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	s.gui_input.connect(_on_slot_input.bind(i))
	match _variant:
		"syllables":
			s.custom_minimum_size = Vector2(150, 120)
		"sentence":
			s.custom_minimum_size = Vector2(110, 96)
		_:
			s.custom_minimum_size = Vector2(620, 96)
	s.set_hint(str(i + 1) if _variant == "sequence" else "")
	return s


func _on_tile(key: String) -> void:
	if _locked:
		return
	var i := _placed.find("")
	if i < 0:
		return
	_placed[i] = key
	_tiles[key].visible = false
	_slots[i].show_tile(_tiles[key].text, _variant)
	if _placed.find("") < 0:
		_locked = true
		await get_tree().create_timer(0.35).timeout
		answered.emit("|".join(_placed), Time.get_ticks_msec() - _started)


func _on_slot_input(event: InputEvent, i: int) -> void:
	if _locked or _placed[i] == "":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tiles[_placed[i]].visible = true
		_placed[i] = ""
		_slots[i].clear()


## Second try (D-021): every tile goes back so the child can build it again.
func try_again(_chosen: String) -> void:
	for i in _slots.size():
		_placed[i] = ""
		_slots[i].clear()
	for b in _tiles.values():
		b.visible = true
	_started = Time.get_ticks_msec()
	_locked = false


## Shows the right order in the slots: green where the child was right,
## mango where the tile was out of place.
func show_result(chosen: String, answer: String) -> void:
	var right := answer.split("|")
	var mine := chosen.split("|")
	var texts := {}
	for t in _item.tiles:
		texts[QuestionBank.tile_key(t)] = _tile_text(t)
	for i in _slots.size():
		_slots[i].show_tile(texts.get(right[i], right[i]), _variant)
		_slots[i].set_color(Palette.RIGHT if i < mine.size() and mine[i] == right[i] else Palette.ALMOST)
	for b in _tiles.values():
		b.visible = false


## Human-readable answer for the feedback sheet.
func answer_text(answer: String) -> String:
	var texts := {}
	for t in _item.tiles:
		texts[QuestionBank.tile_key(t)] = _tile_text(t)
	var parts := Array(answer.split("|")).map(func(k): return texts.get(k, k))
	match _variant:
		"syllables":
			return "-".join(parts)
		"sequence":
			return "  ".join(range(parts.size()).map(func(i): return "%d. %s" % [i + 1, parts[i]]))
	return " ".join(parts)
