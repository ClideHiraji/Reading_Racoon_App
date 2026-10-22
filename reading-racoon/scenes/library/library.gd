extends Control
## The Library (D-017, wireframe "Library"): picture books in English, Filipino
## and Bisaya, easiest first. Only books bundled with the app or picked by the
## teacher (no open internet, RA 10173); teacher-picked books say so on the cover.
## Each language has one color, shown as a dot on its chip and a soft tag on the
## cover; green is kept for right answers (D-022).

const LANG_COLORS := {"en": Palette.BAY_DEEP, "fil": Palette.ORANGE, "bis": Palette.TEAL}

var _lang := ""
var _column: VBoxContainer
var _chips: Control
var _grid: GridContainer


func _ready() -> void:
	if not GameState.guard_free_play():
		return
	_column = Kit.page(self)
	Kit.header(_column, "Library", GameState.go_home)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(_grid)
	_build()
	_column.add_child(scroll)
	Speech.say("Pick a book!")


func _build() -> void:
	if _chips:
		_chips.queue_free()
	var options := [["", "All", "book"]]
	for l in MediaLibrary.LANGUAGES:
		options.append([l, MediaLibrary.LANGUAGES[l], "dot", LANG_COLORS.get(l, Palette.BAY_DEEP)])
	_chips = Kit.chips(options, _lang, _pick_lang)
	_column.add_child(_chips)
	_column.move_child(_chips, 1)
	for c in _grid.get_children():
		c.queue_free()
	for b in GameState.media.books_in(_lang):
		_grid.add_child(_cover(b))


func _pick_lang(lang: String) -> void:
	_lang = lang
	_build()


## A book cover: its setting drawn in paper on top, then the title and a soft
## language tag (D-022).
func _cover(b: Dictionary) -> Control:
	var lang := Collection.lang_of(str(b.language))
	var btn := ChunkyButton.new()
	btn.card_style = true
	btn.custom_minimum_size = Vector2(320, 330)
	btn.radius = 28
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.tooltip_text = b.title
	btn.pressed.connect(_open.bind(b.id))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 10)
	btn.add_child(v)
	var art := PanelContainer.new()
	var art_box := Kit.box(Palette.SKY, 28)
	art_box.corner_radius_bottom_left = 0
	art_box.corner_radius_bottom_right = 0
	art.add_theme_stylebox_override("panel", art_box)
	art.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	art.custom_minimum_size = Vector2(0, 200)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pages: Array = b.get("pages", [])
	var photo: Texture2D = MediaLibrary.page_texture(pages[0]) if not pages.is_empty() else null
	if photo:
		# A teacher book's first page picture is its cover (D-020).
		var r := TextureRect.new()
		r.texture = photo
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(r)
		art.add_child(Kit.photo_edge(28, 0))
	else:
		var scene := PaperScenery.new()
		scene.scene = str(b.get("cover", "river"))
		scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(scene)
	v.add_child(art)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 8)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(text)
	v.add_child(pad)
	var t := Kit.label(b.title, 28, Palette.INK, true)
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.resized.connect(Kit.balance.bind(t))
	text.add_child(t)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tags.add_child(_tag(MediaLibrary.LANGUAGES.get(lang, "English"), LANG_COLORS.get(lang, Palette.BLUE)))
	if b.get("teacher", false):
		tags.add_child(_tag("Teacher", Palette.YELLOW))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tags.add_child(spacer)
	if GameState.collection.is_finished(b.id):
		tags.add_child(Icons.rect("check", 34, Palette.readable(Palette.LEAF)))
	text.add_child(tags)
	return btn


func _tag(text: String, color: Color) -> Label:
	var l := Kit.label(text, 22, Palette.readable(color.darkened(0.25), Palette.pale(color, 0.8)), true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_stylebox_override("normal", Kit.box(Palette.pale(color, 0.8), 12, 0, Vector4(14, 4, 14, 6)))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _open(id: String) -> void:
	if not GameState.guard_free_play():
		return
	Speech.stop()
	GameState.open_book = id
	get_tree().change_scene_to_file("res://scenes/library/reader.tscn")
