extends Control
## The learning path (D-007, D-009): one storybook "page" per world, with a
## paper-cut scene of a Butuan place, skill bars, then a winding trail of lesson
## nodes, a treasure chest and a trophy. BKT decides when a world is cleared and
## the next one unlocks (FR-04); this screen only shows it.

@onready var scroll: ScrollContainer = %Scroll
@onready var content: VBoxContainer = %Content

var _guide: Raccoon
var _bubble: SpeechBubble
var _focus_trail: WorldTrail
var _focus_idx := -1


func _ready() -> void:
	if not GameState.guard():   # FR-12: Adventure's hours; otherwise back to the hub
		return
	%Reset.visible = OS.is_debug_build()
	%Reset.pressed.connect(_on_reset)
	%HomeButton.pressed.connect(GameState.go_home)   # D-015: the hub holds the Closet
	GameState.wallet_changed.connect(_update_top_bar)
	_update_top_bar()
	var timer := Timer.new()
	timer.wait_time = 20.0
	timer.autostart = true
	timer.timeout.connect(func():
		if GameState.guard():
			_update_top_bar())
	add_child(timer)
	await _build()
	_scroll_to_focus()
	var chest_waiting := GameState.path.chest_ready(GameState.lesson_world)
	_say(GameState.line("chest" if chest_waiting else "path_hello"), "happy")


func _build() -> void:
	for c in content.get_children():
		c.queue_free()
	_guide = null
	_bubble = null
	_focus_trail = null
	content.add_child(_spacer(28))
	if GameState.post_test_ready():
		content.add_child(_margin(_post_test_card(), 24, 0))
		content.add_child(_spacer(20))
	for level in range(1, SkillCatalog.MAX_LEVEL + 1):
		_add_world(level)
	content.add_child(_spacer(140))
	await get_tree().process_frame
	await get_tree().process_frame


func _add_world(level: int) -> void:
	var info := SkillCatalog.world(level)
	var has_content := level <= GameState.content_max_level()
	var unlocked := GameState.world_unlocked(level)
	var cleared := unlocked and GameState.world_cleared(level)
	var color: Color = info.color if unlocked else Palette.PAPER_DEEP.darkened(0.15)
	content.add_child(_margin(_banner(level, info, has_content, unlocked), 24, 0))
	var trail := WorldTrail.new()
	trail.setup(GameState.path.layout(level, unlocked, cleared), color, info.scene)
	trail.node_pressed.connect(_on_node_pressed.bind(level))
	content.add_child(trail)
	if _guide == null and unlocked:
		var idx := trail.focus_index()
		if idx < 0 and (level == GameState.model.highest_unlocked or level == GameState.content_max_level()):
			idx = trail.nodes.size() - 1
		if idx >= 0:
			_place_guide(trail, idx)


## The raccoon stands beside the node to play, on the side with more room,
## with its speech bubble underneath.
func _place_guide(trail: WorldTrail, idx: int) -> void:
	_focus_trail = trail
	_focus_idx = idx
	_guide = Raccoon.new()
	_guide.custom_minimum_size = Vector2(160, 160)
	_guide.size = Vector2(160, 160)
	_bubble = SpeechBubble.new()
	_bubble.tail = "up"
	trail.add_child(_guide)
	trail.add_child(_bubble)
	var left := trail.row_offset(idx) >= 0.0
	trail.resized.connect(func():
		var c := trail.node_center(idx)
		var x := 20.0 if left else trail.size.x - 180.0
		_guide.position = Vector2(x, c.y - 96)
		_bubble.position = Vector2(clampf(x - 4, 16, trail.size.x - 320), c.y + 76))


## Read positions now, after layout has settled (earlier values can be stale).
func _scroll_to_focus() -> void:
	if _focus_trail:
		var y := _focus_trail.position.y + _focus_trail.node_center(_focus_idx).y
		scroll.scroll_vertical = int(y - scroll.size.y * 0.45)


# --- World banner: a storybook page header ---------------------------------------------

func _banner(level: int, info: Dictionary, has_content: bool, unlocked: bool) -> Control:
	var color: Color = info.color
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _paper_box(Palette.CARD, 30, 8))
	card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)

	var scenery := PaperScenery.new()
	scenery.scene = info.scene
	scenery.fade = 0.0 if unlocked else 0.85
	scenery.custom_minimum_size = Vector2(0, 210)
	v.add_child(scenery)
	var ribbon_bg: Color = color if unlocked else Palette.INK_SOFT
	var ribbon := _pill("LEVEL %d" % level, ribbon_bg, Palette.text_on(ribbon_bg), 22)
	ribbon.position = Vector2(20, 18)
	scenery.add_child(ribbon)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	v.add_child(_margin(body, 26, 20))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(_icon_disc(info.icon, color if unlocked else Palette.INK_SOFT, 64))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(_label(info.name, 40, Palette.INK, true))
	var sub := "Coming soon" if not has_content else (
			"Level %d" % level if unlocked else "Finish Level %d to open" % (level - 1))
	titles.add_child(_label(sub, 24, Palette.INK_SOFT))
	head.add_child(titles)
	if not unlocked:
		head.add_child(Icons.rect("lock", 46, Palette.INK_SOFT))
	body.add_child(head)
	if has_content:
		for sp in GameState.model.skill_progress(level):
			body.add_child(_skill_bar(sp, color, unlocked))
	return card


## "Big Reading Day": the post-test, shown once the teacher opens it (FR-10).
func _post_test_card() -> Control:
	var card := PanelContainer.new()
	var sb := _paper_box(Palette.PLUM_LIGHT, 28, 8)
	sb.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(_icon_disc("stories", Palette.CARD, 64))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(_label("Big Reading Day!", 38, Palette.INK, true))
	titles.add_child(_label("Show your teacher how much you've grown.", 24, Palette.INK))
	head.add_child(titles)
	v.add_child(head)
	var go := ChunkyButton.new()
	go.text = "START"
	go.face_color = Palette.ORANGE
	go.custom_minimum_size = Vector2(0, 96)
	go.pressed.connect(func(): GameState.start_assessment("post"))
	v.add_child(go)
	return card


func _skill_bar(sp: Dictionary, color: Color, unlocked: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(Icons.rect(SkillCatalog.ICONS[sp.skill], 38, color if unlocked else Palette.INK_SOFT))
	var skill_name := _label(SkillCatalog.NAMES[sp.skill], 28, Palette.INK)
	skill_name.custom_minimum_size = Vector2(118, 0)
	row.add_child(skill_name)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = sp.progress if unlocked else 0.0
	bar.custom_minimum_size = Vector2(0, 22)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _flat(Palette.PAPER_DEEP, 11))
	bar.add_theme_stylebox_override("fill", _flat(Palette.MANGO if sp.mastered else color, 11))
	row.add_child(bar)
	if sp.mastered:
		row.add_child(Icons.rect("crown", 38, Palette.MANGO_DEEP))
	elif sp.review:
		row.add_child(Icons.rect("repeat", 34, Palette.BAY))
	return row


# --- Taps --------------------------------------------------------------------------------

func _on_node_pressed(n: Dictionary, node: PathNode, level: int) -> void:
	var world_name: String = SkillCatalog.world(level).name
	if level > GameState.content_max_level():
		_say("%s is coming soon!" % world_name, "thinking")
		return
	match n.kind:
		"lesson":
			if n.state == "locked":
				_say("Finish the lessons above first!", "thinking")
				_shake(node)
				return
			Speech.stop()
			GameState.start_lesson(level, n.node, n.state in ["bonus", "bonus_done"])
		"chest":
			match n.state:
				"ready":
					var coins := GameState.open_chest(level)
					Sfx.play("coin")
					var at := scroll.scroll_vertical
					await _build()
					scroll.scroll_vertical = at
					_say("Treasure! You found %d coins!" % coins, "celebrate")
				"open":
					_say("You already opened this chest!", "happy")
				_:
					_say("Play two lessons to open the chest!", "thinking")
					_shake(node)
		"trophy":
			if n.state == "won":
				Sfx.play("fanfare")
				_say("You cleared %s!" % world_name, "celebrate")
			else:
				_say("Learn every skill here to win the trophy!", "encourage")


func _say(text: String, mood: String) -> void:
	if _guide:
		_guide.set_mood(mood)
	if _bubble:
		_bubble.say(text)


func _shake(node: Control) -> void:
	var x := node.position.x
	var t := create_tween()
	for d in [12.0, -12.0, 8.0, 0.0]:
		t.tween_property(node, "position:x", x + d, 0.05)


func _update_top_bar() -> void:
	var top := mini(GameState.model.highest_unlocked, maxi(GameState.content_max_level(), 1))
	var info := SkillCatalog.world(top)
	%WorldIcon.texture = Icons.tex(info.icon)
	%WorldDisc.add_theme_stylebox_override("panel", _flat(info.color, 30))
	%WorldName.text = info.name
	%WorldLevel.text = "LEVEL %d" % top
	var d := GameState.access_decision()
	if d.status == "after_school":
		# After-school play has a daily cap with a visible countdown (FR-12).
		%WorldLevel.text += "  ·  %d MIN LEFT" % d.minutes_left
	%Coins.text = str(GameState.wallet.coins)
	%Xp.text = str(GameState.wallet.xp)


func _on_reset() -> void:
	GameState.reset_progress()
	_update_top_bar()
	await _build()
	scroll.scroll_vertical = 0
	_say("Fresh start!", "happy")


# --- Small builders ----------------------------------------------------------------------

func _paper_box(col: Color, r: int, lift: int) -> StyleBoxFlat:
	var sb := _flat(col, r)
	sb.shadow_color = Color(Palette.SHADOW, 0.2)
	sb.shadow_offset = Vector2(0, lift)
	sb.shadow_size = 1
	return sb


func _flat(col: Color, r: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(r)
	sb.anti_aliasing = true
	return sb


func _pill(text: String, bg: Color, fg: Color, fs: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _paper_box(bg, 16, 4)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var l := _label(text, fs, fg, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	return p


func _icon_disc(icon: String, color: Color, px: float) -> Control:
	var p := PanelContainer.new()
	var sb := _paper_box(color, int(px / 2), 4)
	sb.set_content_margin_all(px * 0.18)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(Icons.rect(icon, px * 0.64, Palette.text_on(color)))
	return p


func _label(text: String, fs: int, col: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.theme_type_variation = &"TitleLabel"
		l.add_theme_font_size_override("font_size", fs)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _margin(child: Control, h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", h)
	m.add_theme_constant_override("margin_right", h)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)
	m.add_child(child)
	return m


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
