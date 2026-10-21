extends Control
## The Sticker Album (D-017, wireframe "Sticker Album"): a page per kind of
## sticker, the empty spots waiting with a "?", and how to earn them. Stickers
## are a personal collection: no leaderboards, and none is ever taken away (D-007).

var _group := "adventure"
var _column: VBoxContainer
var _chips: Control
var _page: VBoxContainer


func _ready() -> void:
	if not GameState.guard_hub():
		return
	_column = Kit.page(self)
	var head := Kit.header(_column, "Sticker Album", GameState.go_home)
	var total := Kit.label("%d / %d" % [GameState.collection.count(), Collection.STICKERS.size()], 28,
			Palette.INK, true)
	total.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.row.add_child(total)
	head.row.move_child(total, 2)
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
	if _chips:
		_chips.queue_free()
	var options := []
	for g in Collection.GROUPS:
		options.append([g, Collection.GROUPS[g].name])
	_chips = Kit.chips(options, _group, _pick)
	_column.add_child(_chips)
	_column.move_child(_chips, 1)
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
	var got := Kit.label("%d / %d" % [GameState.collection.count(_group), Collection.in_group(_group).size()],
			28, Palette.INK_SOFT, true)
	got.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	got.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_child(got)
	v.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
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


func _pick(group: String) -> void:
	_group = group
	_build()


func _slot(id: String) -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(140, 0)
	v.add_theme_constant_override("separation", 6)
	if GameState.collection.has_sticker(id):
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(130, 130)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.tooltip_text = Collection.sticker(id).name
		var s := Kit.sticker(id, 120)
		s.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		b.add_child(s)
		b.pressed.connect(_say.bind(id, b))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b)
		var n := Kit.label(Collection.sticker(id).name, 20, Palette.INK, true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
	else:
		var empty := PanelContainer.new()
		var sb := Kit.box(Palette.CARD, 60)
		sb.set_border_width_all(4)
		sb.border_color = Palette.PAPER_DEEP
		empty.add_theme_stylebox_override("panel", sb)
		empty.custom_minimum_size = Vector2(120, 120)
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
	b.pivot_offset = b.size / 2
	var t := create_tween()
	t.tween_property(b, "scale", Vector2(1.12, 1.12), 0.1)
	t.tween_property(b, "scale", Vector2.ONE, 0.15)
