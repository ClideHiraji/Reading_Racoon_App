extends Control
## Watch & Listen (D-017, wireframe "Watch & Listen"): songs and chants to sing
## with Racoon, read-alongs of Library books, and videos the teacher picked.
## No ads and no open internet (RA 10173): videos play only once downloaded.
## Each kind has its own icon and color on the chips and rows; yellow stays with
## Adventure (D-022).

const KIND_ICONS := {"song": "speaker", "read_along": "book", "video": "play"}
const KIND_COLORS := {"song": Palette.BLUE, "read_along": Palette.ORANGE, "video": Palette.TEAL}
## Short chip names, so the four chips fit on one row.
const KIND_CHIPS := {"song": "Songs", "read_along": "Stories", "video": "Videos"}

var _kind := ""
var _column: VBoxContainer
var _chips: Control
var _list: VBoxContainer


func _ready() -> void:
	if not GameState.guard_free_play():
		return
	_column = Kit.page(self)
	Kit.header(_column, "Watch & Listen", GameState.go_home)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 16)
	scroll.add_child(_list)
	_build()
	_column.add_child(scroll)
	var note := Kit.label("Only songs and videos your teacher picked. No ads.", 22, Palette.INK_SOFT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(note)
	Speech.say("Let's sing and listen!")


func _build() -> void:
	if _chips:
		_chips.queue_free()
	var options := [["", "All"]]
	for k in MediaLibrary.KINDS:
		var tint: Color = KIND_COLORS.get(k, Palette.BLUE)
		options.append([k, KIND_CHIPS.get(k, MediaLibrary.KINDS[k]), KIND_ICONS.get(k, "speaker"),
				Palette.INK if k == _kind else Palette.readable(tint.darkened(0.2))])
	_chips = Kit.chips(options, _kind, _pick_kind)
	_column.add_child(_chips)
	_column.move_child(_chips, 1)
	for c in _list.get_children():
		c.queue_free()
	var items := GameState.media.watch_in(_kind)
	if items.is_empty():
		var empty := Kit.label("Nothing here yet. Your teacher can add videos.", 28, Palette.INK_SOFT)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(empty)
	for m in items:
		_list.add_child(_row(m))


func _pick_kind(kind: String) -> void:
	_kind = kind
	_build()


func _row(m: Dictionary) -> Control:
	var can_play := MediaLibrary.video_ready(m)
	var color: Color = KIND_COLORS.get(m.kind, Palette.BLUE)
	var b := ChunkyButton.new()
	b.card_style = true
	b.custom_minimum_size = Vector2(0, 150)
	b.radius = 28
	b.tooltip_text = m.title
	b.pressed.connect(_open.bind(m, can_play))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -18
	row.offset_top = 12
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 18)
	b.add_child(row)
	var thumb := PanelContainer.new()
	thumb.add_theme_stylebox_override("panel", Kit.box(Palette.SKY, 18))
	thumb.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	thumb.custom_minimum_size = Vector2(176, 0)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scene := PaperScenery.new()
	scene.scene = str(m.get("scene", "home"))
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.add_child(scene)
	var play := Kit.disc(KIND_ICONS.get(m.kind, "speaker"), color, 72)
	thumb.add_child(play)
	row.add_child(thumb)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.label(m.title, 30, Palette.INK, true))
	var lang: String = MediaLibrary.LANGUAGES.get(Collection.lang_of(str(m.get("language", "en"))), "English")
	var info := "%d min  ·  %s" % [int(m.get("minutes", 2)), lang]
	if not can_play:
		info = "Downloads next time there's Wi-Fi"
	elif m.get("teacher", false):
		info += "  ·  from your teacher"
	v.add_theme_constant_override("separation", 8)
	v.add_child(Kit.label(info, 22, Palette.INK_SOFT))
	row.add_child(v)
	if GameState.collection.is_finished(m.id):
		row.add_child(Icons.rect("check", 36, Palette.readable(Palette.LEAF)))
	if not can_play:
		b.modulate.a = 0.6
	return b


func _open(m: Dictionary, can_play: bool) -> void:
	if not can_play:
		Speech.say("This one comes next time there's Wi-Fi.")
		return
	if not GameState.guard_free_play():
		return
	Speech.stop()
	GameState.open_media = m.id
	get_tree().change_scene_to_file("res://scenes/watch/player.tscn")
