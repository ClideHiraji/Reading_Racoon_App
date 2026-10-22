extends Control
## The story reader (D-017, wireframe "Story reader"): one page at a time with
## the setting drawn in paper and its pictures. "Read to me" reads the page aloud
## and lights each word (FR-20); tap any word to hear it again. After the last
## page: two easy questions, the book's credit, a sticker and the words.
## Big words, page dots, round Back/Next arrows and a big blue Read to me (D-022).

var _book := {}
var _lang := "en"
var _page := 0
var _reading := false
var _started := 0
var _right := 0
var _column: VBoxContainer
var _dots: HBoxContainer
var _art: PanelContainer
var _scene: PaperScenery
var _photo: TextureRect
var _photo_edge: Panel
var _pictures: HBoxContainer
var _text: ReadAlong
var _body: VBoxContainer
var _controls: HBoxContainer
var _read_btn: ChunkyButton
var _prev: ChunkyButton
var _next_btn: ChunkyButton


func _ready() -> void:
	if not GameState.guard_free_play():
		return
	_started = Time.get_ticks_msec()
	_book = GameState.media.book(GameState.open_book)
	_lang = str(_book.get("language", "en"))
	_column = Kit.page(self)
	Kit.header(_column, str(_book.get("title", "Book")), _back, true)
	var card := Kit.card(0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_column.add_child(card)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	card.add_child(_body)
	_art = PanelContainer.new()
	_art.add_theme_stylebox_override("panel", Kit.box(Palette.SKY, 0))
	_art.custom_minimum_size = Vector2(0, 420)
	_body.add_child(_art)
	_scene = PaperScenery.new()
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_scene)
	# A teacher book's own page picture, once downloaded (D-020).
	_photo = TextureRect.new()
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_photo)
	_photo_edge = Kit.photo_edge(26, 0)   # the card's corner
	_art.add_child(_photo_edge)
	_pictures = HBoxContainer.new()
	_pictures.alignment = BoxContainer.ALIGNMENT_CENTER
	_pictures.size_flags_vertical = Control.SIZE_SHRINK_END
	_pictures.add_theme_constant_override("separation", 14)
	_pictures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_pictures)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 24)
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(m)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 30)
	m.add_child(words)
	_text = ReadAlong.new()
	_text.language = _lang
	_text.font_size = 54
	_text.done.connect(_on_page_read)
	words.add_child(_text)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 12)
	words.add_child(_dots)

	_controls = HBoxContainer.new()
	_controls.add_theme_constant_override("separation", 20)
	_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_child(_controls)
	_prev = _arrow("arrow_left", Palette.PAPER_DEEP, "Back a page")
	_prev.pressed.connect(_turn.bind(-1))
	_controls.add_child(_prev)
	_read_btn = Kit.button("Read to me", Palette.BLUE, "speaker", 128)
	_read_btn.icon_px = 56
	_read_btn.add_theme_font_size_override("font_size", 36)
	_read_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_read_btn.pressed.connect(_toggle_read)
	_controls.add_child(_read_btn)
	_next_btn = _arrow("arrow_right", Palette.ORANGE, "Next page")
	_next_btn.pressed.connect(_turn.bind(1))
	_controls.add_child(_next_btn)

	_reading = Speech.available(_lang)
	_show_page()


func _arrow(icon: String, color: Color, tip: String) -> ChunkyButton:
	var b := ChunkyButton.new()
	b.face_color = color
	b.icon_name = icon
	b.icon_px = 52
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.radius = 56
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(112, 112)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


func _pages() -> Array:
	return _book.get("pages", [])


func _show_page() -> void:
	var pages := _pages()
	if pages.is_empty():
		return
	var p: Dictionary = pages[_page]
	for c in _dots.get_children():
		c.queue_free()
	for i in pages.size():
		_dots.add_child(Icons.rect("dot", 22, Palette.ORANGE if i == _page else Palette.PAPER_DEEP.darkened(0.06)))
	_scene.scene = str(p.get("scene", _book.get("cover", "river")))
	var photo := MediaLibrary.page_texture(p)
	_photo.texture = photo
	_photo.visible = photo != null
	_photo_edge.visible = photo != null
	_scene.visible = photo == null
	for c in _pictures.get_children():
		c.queue_free()
	if photo == null:
		for pic in p.get("pictures", []):
			if Icons.exists(pic):
				_pictures.add_child(Kit.picture(pic, 120))
	var text := str(p.get("text", ""))
	_text.font_size = 54 if text.split(" ", false).size() <= 12 else 40
	_text.set_text(text)
	_prev.disabled = _page == 0
	_prev.modulate.a = 0.4 if _page == 0 else 1.0
	var last := _page == pages.size() - 1
	_next_btn.icon_name = "check" if last else "arrow_right"
	_next_btn.tooltip_text = "The End" if last else "Next page"
	_update_read_button()
	if _reading:
		_text.play.call_deferred()


func _turn(step: int) -> void:
	_text.stop()
	var pages := _pages()
	if _page + step >= pages.size():
		_questions()
		return
	_page = clampi(_page + step, 0, pages.size() - 1)
	Sfx.play("tap")
	_show_page()


func _toggle_read() -> void:
	_reading = not _reading
	if _reading:
		_text.play()
	else:
		_text.stop()
	_update_read_button()


func _update_read_button() -> void:
	_read_btn.text = "Stop" if _reading else "Read to me"


## "Read to me" turns the page by itself after a short pause.
func _on_page_read() -> void:
	if not _reading:
		return
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree() and _reading and not _text.playing():
		if _page < _pages().size() - 1:
			_turn(1)
		else:
			_reading = false
			_update_read_button()


# --- After the last page: two easy questions, the credit, the reward ------------------------

func _questions() -> void:
	_reading = false
	_controls.visible = false
	for c in _body.get_children():
		c.queue_free()
	var qs: Array = _book.get("questions", [])
	_ask(qs, 0)


func _ask(qs: Array, i: int) -> void:
	for c in _body.get_children():
		c.queue_free()
	if i >= qs.size():
		_done(qs.size())
		return
	var q: Dictionary = qs[i]
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 28)
	_body.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	m.add_child(v)
	var prompt := Kit.label(str(q.prompt), 36, Palette.INK, true)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(prompt)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	v.add_child(row)
	var buttons := {}
	for c in q.choices:
		var b := ChunkyButton.new()
		b.card_style = true
		b.custom_minimum_size = Vector2(260, 280)
		b.tooltip_text = str(c.get("label", c.id))
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if c.has("picture") and Icons.exists(c.picture):
			var pic := Kit.picture(c.picture, 150)
			pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(pic)
		var l := Kit.word_label(str(c.get("label", c.id)), 34)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
		b.add_child(col)
		row.add_child(b)
		buttons[str(c.id)] = b
	for id in buttons:
		buttons[id].pressed.connect(_answer.bind(qs, i, id, buttons))
	Speech.say(str(q.prompt), _lang)


func _answer(qs: Array, i: int, id: String, buttons: Dictionary) -> void:
	var right := str(qs[i].answer)
	for b in buttons.values():
		b.disabled = true
	buttons[right].card_style = false
	buttons[right].face_color = Palette.RIGHT
	if id == right:
		_right += 1
		Sfx.play("correct")
	else:
		buttons[id].card_style = false
		buttons[id].face_color = Palette.ALMOST
		Sfx.play("wrong")
	await get_tree().create_timer(1.4).timeout
	if is_inside_tree():
		_ask(qs, i + 1)


func _done(total: int) -> void:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 28)
	_body.add_child(m)
	var credit := Kit.label(str(_book.get("credit", "")), 24, Palette.INK_SOFT)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add_child(credit)
	var seconds := (Time.get_ticks_msec() - _started) / 1000.0
	var result := GameState.finish_book(str(_book.get("id", "")), _right, total, seconds)
	Kit.reward(self, "You read a whole book!", result, _back)


func _back() -> void:
	if is_instance_valid(_text):
		_text.stop()
	Speech.stop()
	get_tree().change_scene_to_file("res://scenes/library/library.tscn")
