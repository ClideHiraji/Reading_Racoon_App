extends Control
## Practice games (D-017, wireframe "Practice games"): play to sharpen your mind,
## no hearts and no tests. A game opens once its skill shows up on the child's
## path; locked cards say what opens them. Two columns of picture cards, open
## games first, each with a soft skill tag (D-022).

const SKILL_COLORS := {"Sounds": Palette.TEAL, "Letters": Palette.BAY_DEEP, "Words": Palette.NIPA,
		"Stories": Palette.CORAL_DEEP}
const LOCKED := Color("efe9d2")

var _list: GridContainer


func _ready() -> void:
	if not GameState.guard_free_play():
		return
	var column := Kit.page(self)
	Kit.header(column, "Practice", GameState.go_home)
	var talk := HBoxContainer.new()
	talk.add_theme_constant_override("separation", 12)
	column.add_child(talk)
	var raccoon := Raccoon.new()
	raccoon.custom_minimum_size = Vector2(100, 100) if Kit.landscape() else Vector2(130, 130)
	talk.add_child(raccoon)
	var bubble := SpeechBubble.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	talk.add_child(bubble)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = GridContainer.new()
	_list.columns = 3 if Kit.landscape() else 2   # all six games on one laptop screen (D-023)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("h_separation", 18)
	_list.add_theme_constant_override("v_separation", 18)
	scroll.add_child(_list)
	column.add_child(scroll)
	var level := GameState.model.highest_unlocked
	var games: Array = PracticePool.GAMES.duplicate()
	# Whether each game is open, worked out once: each check searches the question bank, and the
	# sort asked it twice per comparison (~50 ms each time Practice opened; NFR-01).
	var open := {}
	for g in games:
		open[g.id] = PracticePool.unlocked(g.id, GameState.bank, level)
	games.sort_custom(func(a, b): return open[a.id] and not open[b.id])
	for g in games:
		_list.add_child(_card(g, open[g.id]))
	bubble.say(GameState.talk("practice_hello_bubble"))
	Speech.say(GameState.talk("practice_hello"))


func _card(g: Dictionary, open: bool) -> Control:
	var color: Color = SKILL_COLORS.get(g.skill, Palette.BLUE)
	var b := ChunkyButton.new()
	b.card_style = true
	b.radius = 28
	var wide := Kit.landscape()
	b.custom_minimum_size = Vector2(0, 210 if wide else 286)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = g.name
	b.pressed.connect(_open.bind(g, open))
	if open:
		b.stitched = true   # an open game's card is sewn round, like a felt patch (D-028)
	if not open:
		# A locked card lies flat on the page (D-022).
		b.card_style = false
		b.face_color = LOCKED
		b.lift = 0
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.add_theme_constant_override("separation", 12)
	b.add_child(v)
	var disc := PanelContainer.new()
	disc.add_theme_stylebox_override("panel", Kit.box(Palette.pale(color, 0.8) if open else LOCKED.darkened(0.06), 70))
	disc.custom_minimum_size = Vector2(108, 108) if wide else Vector2(140, 140)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_px := 72 if wide else 92
	var icon := Icons.picture_rect(g.icon, icon_px, color.darkened(0.1)) if open \
			else Icons.rect("lock", icon_px, Color("b5a88c"))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.add_child(icon)
	v.add_child(disc)
	var name_label := Kit.label(g.name, 32, Palette.INK if open else Color("6b5a49"), true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_label)
	var level := GameState.model.highest_unlocked
	var tag_text: String = g.skill if open else PracticePool.lock_text(g.id, GameState.bank, level)
	var tag_color: Color = color if open else Color("b5a88c")
	var tag := Kit.label(tag_text, 22, Palette.readable(tag_color.darkened(0.25), Palette.pale(tag_color, 0.8)), true)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_stylebox_override("normal", Kit.box(Palette.pale(tag_color, 0.8), 12, 0, Vector4(14, 4, 14, 6)))
	v.add_child(tag)
	return b


func _open(g: Dictionary, open: bool) -> void:
	if not open:
		Speech.say(GameState.talk("practice_locked", [g.name]))
		return
	if not GameState.guard_free_play():
		return
	Speech.stop()
	GameState.practice_game = g.id
	GameState.practice_words = []
	get_tree().change_scene_to_file(g.scene)
