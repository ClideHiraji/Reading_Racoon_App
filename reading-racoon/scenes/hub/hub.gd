extends Control
## Home (D-022, replacing the D-015 hub and Play picker): one screen, no second
## menu. Racoon stands on a banig mat over the paper-cut river valley.
## Top: the child (tap to save to school now), Today with its three goal stars,
## and coins. Then three places to go (Library, Practice, Watch & Listen) and the
## big PLAY, which opens the Adventure map, or Big Reading Day when the teacher
## opens the post-test (FR-10). Bottom: Closet, Stickers and Words.
## Only Adventure follows the school schedule, free play has its daily minutes,
## and the hub sleeps at night (FR-12). Yellow means Adventure only (D-022).

const LOCKED := Color("c9c0b2")
## Bottom-anchored layout from the 720x1280 design: tabs, PLAY, the three tiles.
const TABS_H := 112.0
const PLAY_H := 152.0
const TILE_H := 196.0
## On a laptop (D-023) the tiles and PLAY stand in a column this wide on the
## right, and Racoon stands on his mat to the left of it.
const SIDE_W := 640.0

@onready var raccoon: Raccoon = %Raccoon
@onready var bubble: SpeechBubble = %Bubble

var _name: Label
var _initial: Label
var _level_label: Label
var _level_bar: ProgressBar
var _cloud: TextureRect
var _goal_stars: Array[TextureRect] = []
var _coins: Label
var _tiles := {}
var _play: ChunkyButton
var _crest: PanelContainer
var _crest_icon: TextureRect
var _play_title: Label
var _play_sub: Label
var _status: PanelContainer
var _status_icon: TextureRect
var _status_text: Label
var _lift := 0.0   # the phone's home indicator, under the bottom tabs (D-023)


func _ready() -> void:
	if not GameState.guard_hub():   # FR-12: asleep at night
		return
	_build()
	AnimatedStar.warm()   # for Today's goals and the reward card (D-022)
	raccoon.react_to_taps = true   # a tap: giggle, spin, peekaboo, jump, dance... (D-024)
	raccoon.lively = true          # and moves of his own when nobody taps for a while
	bubble.speaker = raccoon       # his bubble walks with him and points at him
	raccoon.tapped.connect(_on_raccoon_tapped)   # only taps he takes (not while he's busy)
	raccoon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND   # D-023
	GameState.wallet_changed.connect(_refresh)
	_refresh()
	var timer := Timer.new()
	timer.wait_time = 20.0
	timer.autostart = true
	timer.timeout.connect(func():
		if GameState.guard_hub():
			_refresh())
	add_child(timer)
	await get_tree().process_frame
	if GameState.notice != "":
		show_notice()
	else:
		_greet()
	# The first visit of a day earns a days sticker (D-017).
	var day := GameState.new_day()
	if day != "" or not GameState.new_day_items.is_empty():
		await get_tree().create_timer(1.6).timeout
		if is_inside_tree():
			Kit.reward(self, GameState.talk("reward_new_day"), {"coins": 0, "stickers": [day] if day != "" else [],
					"items": GameState.new_day_items}, _refresh)


func _greet() -> void:
	var child := GameState.student_name()
	if not AccessPolicy.is_open(GameState.access_decision()):
		_say(GameState.talk("hub_resting"), "encourage")
	elif GameState.post_test_ready():
		_say(GameState.talk("hub_big_day"), "happy")
	elif child != "":
		_say(GameState.talk("hub_hi_name", [child]), "happy")
		raccoon.moment("greet")
	else:
		_say(GameState.talk("hub_hi"), "happy")
		raccoon.moment("greet")


## GameState sent the child here instead of a section; Racoon says why (D-015).
func show_notice() -> void:
	match GameState.notice:
		"adventure_closed":
			var at := GameState.adventure_opens_text()
			_say(GameState.talk("hub_closed_at", [at]) if at != "" else GameState.talk("hub_closed"), "encourage")
		"free_limit":
			_say(GameState.talk("hub_free_done"), "happy")
	GameState.notice = ""
	_refresh()


func _say(text: String, mood: String) -> void:
	raccoon.set_mood(mood)
	raccoon.talk(clampf(text.split(" ", false).size() * 0.3, 0.8, 4.0))
	bubble.say(text)
	Speech.say(text)


func _on_raccoon_tapped() -> void:
	var text := GameState.line("path_hello")
	text = text if text != "" else GameState.talk("read_together")
	bubble.say(text)   # he reacts to the tap himself
	raccoon.talk(1.2)
	Speech.say(text)


# --- Actions ---------------------------------------------------------------------------

func _on_play() -> void:
	var open := AccessPolicy.is_open(GameState.access_decision())
	if not open:
		_shake(_play)
		var at := GameState.adventure_opens_text()
		_say(GameState.talk("hub_play_closed_until", [at]) if at != "" else GameState.talk("hub_play_closed"), "thinking")
		return
	Speech.stop()
	if GameState.post_test_ready():
		GameState.start_assessment("post")
	else:
		GameState.open_section("adventure")


func _on_tile(id: String) -> void:
	if not AccessPolicy.is_open(GameState.free_play_decision()):
		_shake(_tiles[id])
		_say(GameState.talk("hub_free_done_short"), "encourage")
		return
	Speech.stop()
	GameState.open_section(id)


## The profile chip opens the buddy and language screen (D-033), which also says whether the stars
## have reached school; the tap saves answers to school now, as before.
func _on_profile() -> void:
	Sync.request_soon()
	Speech.stop()
	get_tree().change_scene_to_file(GameState.BUDDY_SCENE)


func _shake(node: Control) -> void:
	Kit.shake(node)


# --- What the hub shows ----------------------------------------------------------------

func _level() -> int:
	return mini(GameState.model.highest_unlocked, maxi(GameState.content_max_level(), 1))


## The share of the current level's skills learned, for the bar under the name.
func _level_progress(level: int) -> float:
	var skills: Array = GameState.model.skill_progress(level)
	if skills.is_empty():
		return 0.0
	var total := 0.0
	for sp in skills:
		total += float(sp.progress)
	return total / skills.size()


func _refresh() -> void:
	var level := _level()
	var info := SkillCatalog.world(level)
	var child := GameState.student_name()
	_name.text = child if child != "" else "Reader"
	_initial.text = child.left(1).to_upper() if child != "" else "R"
	_level_label.text = str(level)
	_level_bar.value = _level_progress(level)
	_coins.text = str(GameState.wallet.coins)
	# Green cloud: everything is saved to school. Orange: answers still waiting.
	var saved := GameState.store.queue_size() == 0
	_cloud.self_modulate = Palette.LEAF_DEEP if saved else Palette.ORANGE
	var done := clampi(Collection.GOALS.size() - GameState.collection.goals_left(GameState.today()),
			0, _goal_stars.size())
	for i in _goal_stars.size():
		_goal_stars[i].self_modulate = Palette.MANGO if i < done else Palette.PAPER_DEEP.darkened(0.06)

	var d := GameState.access_decision()
	var open := AccessPolicy.is_open(d)
	var big_day := open and GameState.post_test_ready()
	if big_day:
		_style_play(Palette.PLUM_LIGHT, Palette.PLUM_DEEP, "trophy", "BIG READING DAY",
				"Your teacher opened it", 46)
	elif open:
		_style_play(Palette.YELLOW, info.color, info.icon, "PLAY",
				"%s · Level %d" % [info.name, level], 72)
	else:
		var at := GameState.adventure_opens_text()
		_style_play(LOCKED, Palette.INK_SOFT, "lock", "PLAY",
				"Opens %s" % at if at != "" else "Resting", 72)
	var free := GameState.free_play_decision()
	var free_open := AccessPolicy.is_open(free)
	for id in _tiles:
		_tiles[id].modulate.a = 1.0 if free_open else 0.55
	_update_status(open, d, free, level)
	# Late afternoon and evening: a warm dusk over the valley.
	%Dusk.visible = int(GameState.now_dict().hour) >= 17


func _style_play(face: Color, crest: Color, icon: String, title: String, sub: String, title_px: int) -> void:
	_play.face_color = face
	_crest.add_theme_stylebox_override("panel", _disc(crest))
	_crest_icon.texture = Icons.tex(icon)
	_crest_icon.self_modulate = Palette.text_on(crest)
	_play_title.text = title
	_play_title.add_theme_font_size_override("font_size", title_px)
	_play_sub.text = sub


## A small line for grown-ups and children who read: time left or a treasure.
func _update_status(open: bool, d: Dictionary, free: Dictionary, level: int) -> void:
	var s := []
	if open and d.status == "after_school":
		s = ["moon", "Adventure: %d min left today" % d.minutes_left]
	elif open and GameState.path.chest_ready(level):
		s = ["chest", "A treasure chest is waiting!"]
	elif free.status == "free_play":
		s = ["sun", "Free play: %d min left today" % free.minutes_left]
	elif free.status == "free_limit":
		s = ["star", "Free play is done for today!"]
	_status.visible = not s.is_empty()
	if not s.is_empty():
		_status_icon.texture = Icons.tex(s[0])
		_status_text.text = s[1]


# --- Building the screen (D-022 layout) ------------------------------------------------

func _build() -> void:
	var wide := Kit.landscape()
	var safe := Kit.insets()
	_lift = safe.bottom
	# Top bar: the child, Today, coins.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = (40.0 if wide else 16.0) + safe.left
	top.offset_right = -(40.0 if wide else 16.0) - safe.right
	top.offset_top = 18 + safe.top
	top.offset_bottom = 114 + safe.top
	add_child(top)
	top.add_child(_profile())
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)
	top.add_child(_today())
	var pill := Kit.coin_pill(self)
	_coins = pill.get_meta("label")
	top.add_child(pill)

	# The three places to go.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_bottom(row, TABS_H + 28 + PLAY_H + 32 + TILE_H, TILE_H)
	for id in ["library", "practice", "watch"]:
		var s := HubSections.get_info(id)
		var t := _tile(s.name.replace(" & Listen", ""), s.icon, s.color)
		t.name = id.capitalize() + "Tile"
		t.unique_name_in_owner = true
		t.pressed.connect(_on_tile.bind(id))
		row.add_child(t)
		_tiles[id] = t

	# Free-play minutes, a waiting chest...
	_status = PanelContainer.new()
	_status.add_theme_stylebox_override("panel", Kit.box(Color(Palette.CARD, 0.95), 24, 4,
			Vector4(16, 8, 20, 8)))
	_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status.offset_top = -(TABS_H + 28 + PLAY_H + 32 + TILE_H + 70) - _lift
	_status.offset_bottom = _status.offset_top + 56
	if wide:   # centered over the column
		_status.anchor_left = 1.0
		_status.anchor_right = 1.0
		_status.offset_left = -(40 + SIDE_W / 2)
		_status.offset_right = _status.offset_left
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 10)
	_status.add_child(sh)
	_status_icon = Icons.rect("sun", 32, Palette.MANGO_DEEP)
	sh.add_child(_status_icon)
	_status_text = Kit.label("", 24, Palette.INK, true)
	_status_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	sh.add_child(_status_text)
	add_child(_status)

	# PLAY.
	_play = _play_button()
	_bottom(_play, TABS_H + 28 + PLAY_H, PLAY_H)

	# My things.
	var bar := PanelContainer.new()
	var sb := Kit.box(Palette.CARD, 0, 0, Vector4(16, 4, 16, 8 + _lift))
	sb.corner_radius_top_left = 28
	sb.corner_radius_top_right = 28
	sb.shadow_color = Color(Palette.SHADOW, 0.25)
	sb.shadow_offset = Vector2(0, -6)
	sb.shadow_size = 1
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -TABS_H - _lift
	add_child(bar)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	bar.add_child(tabs)
	for t in [["ClosetTab", "Closet", "hat", Palette.BAY_DEEP, "closet"],
			["StickersTab", "Stickers", "sticker", Palette.MANGO_DEEP, "stickers"],
			["WordsTab", "Words", "wordbook", Palette.CORAL_DEEP, "words"]]:
		var b := _tab(t[1], t[2], t[3])
		b.name = t[0]
		b.unique_name_in_owner = true
		b.pressed.connect(GameState.open_section.bind(t[4]))
		tabs.add_child(b)
	# %Names work only for nodes this scene owns.
	for n in find_children("*", "", true, false):
		if n.unique_name_in_owner:
			n.owner = self
	if wide:
		_place_racoon()


## Laptop (D-023): Racoon on his mat in the middle of the left side, his bubble
## above him growing upward, clear of the top bar.
func _place_racoon() -> void:
	var cx := 40.0 + (1280.0 - 80.0 - SIDE_W - 24.0) / 2.0
	var feet := TABS_H + _lift + 44.0
	_pin(raccoon, cx - 150, cx + 150, -(feet + 300), -feet)
	_pin($Mat, cx - 160, cx + 160, -(feet + 32), -(feet - 32))
	_pin(bubble, 40, 1280.0 - 80.0 - SIDE_W, -(feet + 410), -(feet + 320))
	bubble.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bubble.tail_x = cx - 60


## Anchors `node` to the bottom-left corner at these offsets.
func _pin(node: Control, left: float, right: float, top: float, bottom: float) -> void:
	node.anchor_left = 0.0
	node.anchor_right = 0.0
	node.anchor_top = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = left
	node.offset_right = right
	node.offset_top = top
	node.offset_bottom = bottom


## Puts `node` in a full-width band whose top is `from_bottom` px above the
## bottom edge, `h` px tall, with 24 px side margins; on a laptop, in the
## column on the right (D-023).
func _bottom(node: Control, from_bottom: float, h: float) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	node.offset_left = 24
	node.offset_right = -24
	if Kit.landscape():
		node.anchor_left = 1.0
		node.offset_left = -(40 + SIDE_W)
		node.offset_right = -40
	node.offset_top = -from_bottom - _lift
	node.offset_bottom = -from_bottom - _lift + h
	add_child(node)


func _profile() -> ChunkyButton:
	var b := ChunkyButton.new()
	b.name = "Profile"
	b.unique_name_in_owner = true
	b.card_style = true
	b.lift = 5
	b.radius = 48
	b.tap_sound = false
	b.tooltip_text = "My buddy"
	b.custom_minimum_size = Vector2(292, 96)
	b.pressed.connect(_on_profile)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -16
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var avatar := Control.new()
	avatar.custom_minimum_size = Vector2(80, 80)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(avatar)
	var disc := PanelContainer.new()
	disc.add_theme_stylebox_override("panel", _disc(Palette.BLUE))
	disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_child(disc)
	_initial = Kit.label("R", 40, Palette.text_on(Palette.BLUE), true)
	_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disc.add_child(_initial)
	var badge := PanelContainer.new()
	var bb := _disc(Palette.MANGO)
	bb.set_border_width_all(3)
	bb.border_color = Palette.CARD
	badge.add_theme_stylebox_override("panel", bb)
	badge.custom_minimum_size = Vector2(38, 38)
	badge.position = Vector2(50, 48)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_child(badge)
	_level_label = Kit.label("1", 20, Palette.INK, true)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(_level_label)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 8)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(names)
	_name = Kit.label("Reader", 34, Palette.INK, true)
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(_name)
	_level_bar = ProgressBar.new()
	_level_bar.show_percentage = false
	_level_bar.max_value = 1.0
	_level_bar.custom_minimum_size = Vector2(0, 14)
	_level_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_bar.add_theme_stylebox_override("background", Kit.box(Palette.PAPER_DEEP, 7))
	_level_bar.add_theme_stylebox_override("fill", Kit.box(Palette.LEAF, 7))
	names.add_child(_level_bar)
	_cloud = Icons.rect("cloud", 30, Palette.LEAF_DEEP)
	_cloud.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_cloud)
	return b


func _today() -> ChunkyButton:
	var b := ChunkyButton.new()
	b.name = "TodayButton"
	b.unique_name_in_owner = true
	b.card_style = true
	b.lift = 5
	b.radius = 48
	b.tooltip_text = "Today"
	b.custom_minimum_size = Vector2(196, 96)
	b.pressed.connect(GameState.open_section.bind("today"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var sun := PanelContainer.new()
	sun.add_theme_stylebox_override("panel", _disc(Palette.ORANGE))
	sun.custom_minimum_size = Vector2(76, 76)
	sun.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sun)
	var icon := Icons.rect("sun", 50, Palette.INK)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sun.add_child(icon)
	for i in Collection.GOALS.size():
		var s := Icons.rect("star", 32, Palette.PAPER_DEEP)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(s)
		_goal_stars.append(s)
	return b


func _tile(title: String, icon: String, color: Color) -> ChunkyButton:
	var b := ChunkyButton.new()
	b.text = title
	b.face_color = color
	b.full_color = true   # the Home tiles show their pictures in full colour (D-027)
	b.stitched = true     # and are sewn round like felt patches (D-028)
	b.tilt = {"book": -2.0, "bulb": 1.5, "speaker": -1.5}.get(icon, 0.0)
	b.icon_name = icon
	b.icon_px = 84
	b.lift = 8
	b.radius = 28
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, TILE_H)
	b.add_theme_font_size_override("font_size", 30)
	b.tooltip_text = title
	return b


func _play_button() -> ChunkyButton:
	var b := ChunkyButton.new()
	b.name = "PlayButton"
	b.unique_name_in_owner = true
	b.face_color = Palette.YELLOW
	b.lift = 10
	b.radius = 28
	b.tooltip_text = "Play"
	b.pressed.connect(_on_play)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 28
	h.offset_right = -28
	h.offset_bottom = -10
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	_crest = PanelContainer.new()
	_crest.custom_minimum_size = Vector2(108, 108)
	_crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_crest)
	_crest_icon = Icons.rect("waves", 64, Palette.CARD)
	_crest_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_crest_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_crest.add_child(_crest_icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -6)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(words)
	_play_title = Kit.label("PLAY", 72, Palette.INK, true)
	_play_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.add_child(_play_title)
	_play_sub = Kit.label("", 26, Palette.INK, true)
	_play_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	_play_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(_play_sub)
	var arrow := Icons.rect("play", 60, Palette.INK)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(arrow)
	return b


## A bottom tab: its icon right next to its name, both centered.
func _tab(title: String, icon: String, tint: Color) -> Button:
	var b := Button.new()
	b.flat = true
	b.tooltip_text = title
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 96)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(c)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(h)
	h.add_child(Icons.picture_rect(icon, 56, tint))   # in full paper colour (D-027)
	var l := Kit.label(title, 26, Palette.INK, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return b


func _disc(col: Color) -> PaperBox:
	return Kit.box(col, 60)
