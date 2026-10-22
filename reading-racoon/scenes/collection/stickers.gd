extends Control
## The Sticker Album (D-017, wireframe "Sticker Album"): a page per kind of
## sticker, the empty spots waiting with a "?", and how to earn them. Stickers
## are a personal collection: no leaderboards, and none is ever taken away (D-007).
## A row of picture tabs (Racoon says each name) and big round stickers (D-022).

const GROUP_ICONS := {"adventure": "waves", "books": "book", "games": "bulb", "watch": "speaker",
		"days": "sun", "goals": "star"}

var _group := "adventure"
var _column: VBoxContainer
var _tabs: GridContainer
var _page: VBoxContainer


func _ready() -> void:
	if not GameState.guard_hub():
		return
	_column = Kit.page(self)
	Kit.header(_column, "Stickers", GameState.go_home)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 16)
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build()
	_column.add_child(_page)
	var note := Kit.label("Stickers are yours to keep. No ranking, no losing.", 22, Palette.INK_SOFT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(note)
	Speech.say("Your sticker album!")


func _build() -> void:
	if _tabs:
		_tabs.queue_free()
	_tabs = GridContainer.new()
	_tabs.columns = Collection.GROUPS.size()
	_tabs.add_theme_constant_override("h_separation", 12)
	for g in Collection.GROUPS:
		_tabs.add_child(_tab(g))
	_column.add_child(_tabs)
	_column.move_child(_tabs, 1)
	for c in _page.get_children():
		c.queue_free()
	var info: Dictionary = Collection.GROUPS[_group]
	var card := Kit.card(24)
	_page.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	card.add_child(v)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 12)
	var group_title := Kit.label(info.name, 36, Palette.INK, true)
	group_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.add_child(group_title)
	var got := Kit.label("%d of %d" % [GameState.collection.count(_group), Collection.in_group(_group).size()],
			28, Palette.INK_SOFT, true)
	got.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	got.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_child(got)
	v.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 18)
	v.add_child(grid)
	for id in Collection.in_group(_group):
		grid.add_child(_slot(id))
	var how := HBoxContainer.new()
	how.add_theme_constant_override("separation", 12)
	how.add_child(Kit.disc("sparkles", info.color, 56))
	var how_text := Kit.label("How to get one: %s." % info.how.to_lower(), 26, Palette.INK)
	how_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	how.add_child(how_text)
	v.add_child(how)


## A picture tab for a sticker group; the open one is blue.
func _tab(g: String) -> ChunkyButton:
	var info: Dictionary = Collection.GROUPS[g]
	var on := g == _group
	var b := ChunkyButton.new()
	b.card_style = not on
	b.face_color = Palette.BLUE
	b.icon_name = GROUP_ICONS.get(g, "star")
	b.icon_px = 54
	b.icon_tint = Palette.INK if on else Palette.readable(Color(info.color).darkened(0.2))
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.radius = 24
	b.lift = 5
	b.tooltip_text = info.name
	b.custom_minimum_size = Vector2(0, 100)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(_pick.bind(g))
	return b


func _pick(group: String) -> void:
	_group = group
	Speech.say(Collection.GROUPS[group].name)
	_build()


func _slot(id: String) -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(138, 0)
	v.add_theme_constant_override("separation", 6)
	if GameState.collection.has_sticker(id):
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(132, 132)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.tooltip_text = Collection.sticker(id).name
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(Kit.sticker(id, 124))
		b.add_child(center)
		b.pressed.connect(_say.bind(id, b))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b)
		var n := Kit.label(Collection.sticker(id).name, 22, Palette.INK, true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
	else:
		var empty := PanelContainer.new()
		var sb := Kit.box(Palette.CARD, 62)
		sb.set_border_width_all(4)
		sb.border_color = Palette.PAPER_DEEP
		empty.add_theme_stylebox_override("panel", sb)
		empty.custom_minimum_size = Vector2(124, 124)
		empty.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var q := Kit.label("?", 48, Palette.PAPER_DEEP.darkened(0.25), true)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_child(q)
		v.add_child(empty)
	return v


func _say(id: String, b: Control) -> void:
	Speech.say(Collection.sticker(id).name)
	Sfx.play("pop")
	Kit.pop(b)
