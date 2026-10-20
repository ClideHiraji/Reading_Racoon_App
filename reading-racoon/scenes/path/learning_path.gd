extends Control
## The learning path (D-007): each map level is a colored world with 5 lesson
## nodes, a treasure chest and a trophy. BKT decides when a world is cleared and
## the next one unlocks (FR-04); this screen only shows it.

const SWING := 150.0
const LOCKED_COLOR := Color("c9c0b0")

@onready var scroll: ScrollContainer = %Scroll
@onready var content: VBoxContainer = %Content

var _guide: Raccoon
var _bubble: SpeechBubble
var _focus_row: Control


func _ready() -> void:
	%Reset.visible = OS.is_debug_build()
	%Reset.pressed.connect(_on_reset)
	GameState.wallet_changed.connect(_update_top_bar)
	_update_top_bar()
	await _build()
	if _focus_row:
		scroll.scroll_vertical = int(_focus_row.position.y - 420)
	var chest_waiting := GameState.path.chest_ready(GameState.lesson_world)
	_say(GameState.line("chest" if chest_waiting else "path_hello"), "happy")


func _build() -> void:
	for c in content.get_children():
		c.queue_free()
	_focus_row = null
	_guide = null
	content.add_child(_spacer(20))
	for level in range(1, SkillCatalog.MAX_LEVEL + 1):
		_add_world(level)
	content.add_child(_spacer(160))
	await get_tree().process_frame
	await get_tree().process_frame


func _add_world(level: int) -> void:
	var info := SkillCatalog.world(level)
	var has_content := level <= GameState.content_max_level()
	var unlocked := GameState.world_unlocked(level)
	var cleared := unlocked and GameState.world_cleared(level)
	content.add_child(_banner(level, info, has_content, unlocked))
	var layout := GameState.path.layout(level, unlocked, cleared)
	for i in layout.size():
		var n: Dictionary = layout[i]
		var row := Control.new()
		row.custom_minimum_size = Vector2(0, 200)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(row)
		var node := PathNode.new()
		node.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(node)
		node.setup(n.kind, n.state, info.color if unlocked else LOCKED_COLOR)
		var offset := sin(i * 0.95 + 0.6) * SWING
		row.resized.connect(func(): node.position = Vector2(row.size.x / 2 + offset - 100, 0))
		node.pressed.connect(_on_node_pressed.bind(level, n, node))
		if _guide == null and n.state in ["current", "practice", "ready"]:
			_place_guide(row, offset)
	if _guide == null and unlocked and (level == GameState.model.highest_unlocked \
			or level == GameState.content_max_level()):
		_place_guide(content.get_child(content.get_child_count() - 1), 0.0)


## The raccoon stands beside the node to play, on the side with more room.
func _place_guide(row: Control, offset: float) -> void:
	_focus_row = row
	_guide = Raccoon.new()
	_guide.custom_minimum_size = Vector2(150, 150)
	_guide.size = Vector2(150, 150)
	_bubble = SpeechBubble.new()
	row.add_child(_guide)
	row.add_child(_bubble)
	var left_side := offset >= 0.0
	row.resized.connect(func():
		var x := 24.0 if left_side else row.size.x - 174.0
		_guide.position = Vector2(x, 30)
		_bubble.position = Vector2(clampf(x, 16, row.size.x - 316), 190))


func _banner(level: int, info: Dictionary, has_content: bool, unlocked: bool) -> Control:
	var wrap := MarginContainer.new()
	for side in ["left", "right"]:
		wrap.add_theme_constant_override("margin_" + side, 24)
	wrap.add_theme_constant_override("margin_top", 28)
	wrap.add_theme_constant_override("margin_bottom", 8)
	var panel := PanelContainer.new()
	var color: Color = info.color if unlocked else LOCKED_COLOR
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = color.darkened(0.22)
	sb.border_width_bottom = 8
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	wrap.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var small := _white_label("LEVEL %d" % level, 24)
	small.modulate.a = 0.85
	v.add_child(small)
	v.add_child(_white_label("%s  %s" % [info.icon, info.name], 44))
	if not has_content:
		v.add_child(_white_label("Coming soon!", 28))
		return wrap
	if not unlocked:
		v.add_child(_white_label("🔒 Finish Level %d to open" % (level - 1), 28))
	var rings := HBoxContainer.new()
	rings.add_theme_constant_override("separation", 4)
	for sp in GameState.model.skill_progress(level):
		var ring := SkillRing.new()
		ring.setup(SkillCatalog.ICONS[sp.skill], SkillCatalog.NAMES[sp.skill],
				sp.progress if unlocked else 0.0, sp.mastered, sp.review)
		rings.add_child(ring)
	v.add_child(rings)
	return wrap


func _on_node_pressed(level: int, n: Dictionary, node: PathNode) -> void:
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
					await _rebuild_keep_scroll()
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


func _rebuild_keep_scroll() -> void:
	var at := scroll.scroll_vertical
	await _build()
	scroll.scroll_vertical = at


func _update_top_bar() -> void:
	var top := mini(GameState.model.highest_unlocked, maxi(GameState.content_max_level(), 1))
	var info := SkillCatalog.world(top)
	%World.text = "%s Level %d" % [info.icon, top]
	%Coins.text = "💰 %d" % GameState.wallet.coins
	%Xp.text = "⚡ %d" % GameState.wallet.xp


func _on_reset() -> void:
	GameState.reset_progress()
	_update_top_bar()
	await _build()
	scroll.scroll_vertical = 0
	_say("Fresh start!", "happy")


func _white_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
