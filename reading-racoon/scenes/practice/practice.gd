extends Control
## Practice games (D-017, wireframe "Practice games"): play to sharpen your mind,
## no hearts and no tests. A game opens once its skill shows up on the child's
## path; locked cards say what opens them.

const SKILL_COLORS := {"Sounds": Palette.BLUE, "Letters": Palette.ORANGE, "Words": Palette.YELLOW,
		"Stories": Palette.LEAF}

var _skill := ""
var _column: VBoxContainer
var _chips: Control
var _list: VBoxContainer


func _ready() -> void:
	if not GameState.guard_free_play():
		return
	_column = Kit.page(self)
	Kit.header(_column, "Practice", GameState.go_home)
	_column.add_child(Kit.label("Play to sharpen your mind. No hearts, no tests, just fun.", 26,
			Palette.INK_SOFT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 16)
	scroll.add_child(_list)
	_build()
	_column.add_child(scroll)
	Speech.say("Pick a game!")


func _build() -> void:
	if _chips:
		_chips.queue_free()
	var options := [["", "All"]]
	for s in PracticePool.SKILLS:
		options.append([s, s])
	_chips = Kit.chips(options, _skill, _pick_skill)
	_column.add_child(_chips)
	_column.move_child(_chips, 2)
	for c in _list.get_children():
		c.queue_free()
	for g in PracticePool.GAMES:
		if _skill == "" or g.skill == _skill:
			_list.add_child(_card(g))


func _pick_skill(skill: String) -> void:
	_skill = skill
	_build()


func _card(g: Dictionary) -> Control:
	var level := GameState.model.highest_unlocked
	var open := PracticePool.unlocked(g.id, GameState.bank, level)
	var color: Color = SKILL_COLORS.get(g.skill, Palette.BLUE)
	var b := ChunkyButton.new()
	b.card_style = true
	b.custom_minimum_size = Vector2(0, 150)
	b.tooltip_text = g.name
	b.pressed.connect(_open.bind(g, open))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	row.add_theme_constant_override("separation", 20)
	b.add_child(row)
	row.add_child(Kit.disc(g.icon if open else "lock", color if open else DiamondTile.LOCKED, 104))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.label(g.name, 32, Palette.INK, true))
	v.add_child(Kit.label(g.line if open else PracticePool.lock_text(g.id, GameState.bank, level), 24,
			Palette.INK_SOFT))
	row.add_child(v)
	var tag := Kit.label(g.skill.to_upper(), 20, Palette.readable(Palette.deep(color)), true)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)
	if not open:
		b.modulate.a = 0.75
	return b


func _open(g: Dictionary, open: bool) -> void:
	if not open:
		Speech.say("Keep playing Adventure to open %s!" % g.name)
		return
	if not GameState.guard_free_play():
		return
	Speech.stop()
	GameState.practice_game = g.id
	GameState.practice_words = []
	get_tree().change_scene_to_file(g.scene)
