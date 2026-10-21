extends Control
## Home hub (D-015, the approved "Home hub" wireframe): a game lobby in portrait.
## Racoon stands in the middle on a banig mat over the paper-cut river valley.
## Top: the child's name, level, coins and XP, and whether answers are saved to
## school. Left: Shop and Today. Right: "For you" picks. Bottom: Closet, Stickers
## and Word Book, and the big PLAY button that opens the Play picker.
## Only Adventure follows the school schedule; the hub sleeps at night (FR-12).

const WARM_INK := Color("5a3a0a")
const PICKER := "res://scenes/hub/play_picker.tscn"

@onready var raccoon: Raccoon = %Raccoon
@onready var bubble: SpeechBubble = %Bubble


func _ready() -> void:
	if not GameState.guard_hub():   # FR-12: asleep at night
		return
	_style()
	%PlayButton.pressed.connect(_on_play)
	%ShopButton.pressed.connect(GameState.open_section.bind("closet"))
	%TodayButton.pressed.connect(GameState.open_section.bind("today"))
	%ClosetTab.pressed.connect(GameState.open_section.bind("closet"))
	%StickersTab.pressed.connect(GameState.open_section.bind("stickers"))
	%WordsTab.pressed.connect(GameState.open_section.bind("words"))
	%PicksTab.pressed.connect(_toggle_picks)
	raccoon.gui_input.connect(_on_raccoon_input)
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
	if day != "":
		await get_tree().create_timer(1.6).timeout
		if is_inside_tree():
			Kit.reward(self, "Hello, new day!", {"coins": 0, "stickers": [day]}, _refresh)


func _greet() -> void:
	var child := GameState.student_name()
	if not AccessPolicy.is_open(GameState.access_decision()):
		_say("Adventure is resting now. Let's read a story or play!", "encourage")
	elif child != "":
		_say("Hi, %s! Shall we read today?" % child, "happy")
	else:
		_say("Hi! Shall we read today?", "happy")


## GameState sent the child here instead of a section; Racoon says why (D-015).
func show_notice() -> void:
	match GameState.notice:
		"adventure_closed":
			var at := GameState.adventure_opens_text()
			_say("Adventure is resting now%s. Let's read or play!" % (
					", it opens at %s" % at if at != "" else ""), "encourage")
		"free_limit":
			_say("Free play is done for today. Great job! See you tomorrow.", "happy")
	GameState.notice = ""
	_refresh()


func _say(text: String, mood: String) -> void:
	raccoon.set_mood(mood)
	bubble.say(text)
	Speech.say(text)


func _on_play() -> void:
	Speech.stop()
	get_tree().change_scene_to_file(PICKER)


func _on_raccoon_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var text := GameState.line("path_hello")
		_say(text if text != "" else "Let's read together!", "happy")


func _toggle_picks() -> void:
	%Picks.visible = not %Picks.visible
	%PicksTab.text = "‹" if %Picks.visible else "›"
	%PicksTab.tooltip_text = "Hide picks" if %Picks.visible else "Show picks"
	%PicksTab.offset_left = -214.0 if %Picks.visible else -54.0
	%PicksTab.offset_right = %PicksTab.offset_left + 40.0


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
	%Name.text = child if child != "" else "Reader"
	%Initial.text = child.left(1).to_upper() if child != "" else "R"
	%Level.text = str(level)
	%LevelBar.value = _level_progress(level)
	%Coins.text = str(GameState.wallet.coins)
	%Xp.text = str(GameState.wallet.xp)
	# Green cloud: everything is saved to school. Orange: answers still waiting.
	var saved := GameState.store.queue_size() == 0
	%SyncIcon.self_modulate = Palette.LEAF_DEEP if saved else Palette.ORANGE
	%SyncDot.tooltip_text = "Saved to school" if saved else "Waiting for Wi-Fi to save"

	var d := GameState.access_decision()
	var open := AccessPolicy.is_open(d)
	if open:
		%TopIcon.texture = Icons.tex("star")
		%TopText.text = "LEVEL %d" % level
		%SubText.text = info.name
		%Crest.add_theme_stylebox_override("panel", _crest(info.color))
		%CrestIcon.texture = Icons.tex(info.icon)
		%CrestIcon.self_modulate = Palette.text_on(info.color)
	else:
		var at := GameState.adventure_opens_text()
		%TopIcon.texture = Icons.tex("lock")
		%TopText.text = "Opens %s" % at if at != "" else "Resting"
		%SubText.text = "Read, watch, play"
		%Crest.add_theme_stylebox_override("panel", _crest(DiamondTile.LOCKED))
		%CrestIcon.texture = Icons.tex("lock")
		%CrestIcon.self_modulate = Palette.INK
	%TopIcon.self_modulate = WARM_INK
	# Late afternoon and evening: a warm dusk over the valley.
	%Dusk.visible = int(GameState.now_dict().hour) >= 17
	%Dot.visible = GameState.collection.goals_left(GameState.today()) > 0
	var tip := _tip(open, d, level)
	%TipIcon.texture = Icons.tex(tip[0])
	%TipIcon.self_modulate = Palette.MANGO
	%TipText.text = tip[1]
	_build_picks(open)


## [icon, text] for the hint above PLAY.
func _tip(open: bool, d: Dictionary, level: int) -> Array:
	var left := GameState.collection.goals_left(GameState.today())
	var goals := ["star", "%d more goal%s for a sticker!" % [left, "" if left == 1 else "s"]]
	if open:
		if d.status == "after_school":
			return ["moon", "Adventure: %d min left today" % d.minutes_left]
		if GameState.post_test_ready():
			return ["stories", "Your Big Test is ready!"]
		if GameState.path.chest_ready(level):
			return ["chest", "A treasure chest is waiting!"]
		return goals if left > 0 else ["coins", "Finish a lesson to earn coins!"]
	var f := GameState.free_play_decision()
	match f.status:
		"free_play":
			return ["sun", "Free play left today: %d min" % f.minutes_left]
		"free_limit":
			return ["star", "Free play is done for today!"]
	return goals if left > 0 else ["book", "Read a story with Racoon!"]


## "For you": up to three things to do now, like a lobby's friends list.
func _picks(open: bool) -> Array:
	var out := []
	if open and GameState.post_test_ready():
		out.append({"id": "post", "title": "Big Test", "icon": "stories", "color": Palette.PLUM_LIGHT})
	elif open:
		out.append({"id": "adventure", "title": "Next lesson", "icon": SkillCatalog.world(_level()).icon,
				"color": Palette.YELLOW})
	out.append({"id": "library", "title": "Story time", "icon": "book", "color": Palette.ORANGE})
	out.append({"id": "watch", "title": "Sing along", "icon": "speaker", "color": Palette.BLUE})
	out.append({"id": "practice", "title": "Brain game", "icon": "bulb", "color": Palette.LEAF})
	return out.slice(0, 3)


func _build_picks(open: bool) -> void:
	for c in %List.get_children():
		if c != %Header:
			c.queue_free()
	for p in _picks(open):
		%List.add_child(_pick(p))


func _pick(p: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var b := ChunkyButton.new()
	b.face_color = p.color
	b.icon_name = p.icon
	b.icon_px = 50
	b.lift = 5
	b.radius = 18
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.custom_minimum_size = Vector2(136, 92)
	b.tooltip_text = p.title
	b.pressed.connect(_open_pick.bind(p.id))
	v.add_child(b)
	var l := Label.new()
	l.text = p.title
	l.theme_type_variation = &"TitleLabel"
	l.add_theme_font_size_override("font_size", 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v


func _open_pick(id: String) -> void:
	Speech.stop()
	if id == "post":
		GameState.start_assessment("post")
	else:
		GameState.open_section(id)


# --- Styles (paper-cut, D-009) ------------------------------------------------------------

func _style() -> void:
	var glass := Color(Palette.CARD, 0.94)
	%Profile.add_theme_stylebox_override("panel", _box(glass, 50, 5, Vector4(8, 8, 26, 8)))
	%Disc.add_theme_stylebox_override("panel", _box(Palette.BLUE, 42, 0))
	%Initial.add_theme_color_override("font_color", Palette.text_on(Palette.BLUE))
	var badge := _box(Palette.MANGO, 20, 0)
	badge.set_border_width_all(3)
	badge.border_color = Palette.CARD
	%Badge.add_theme_stylebox_override("panel", badge)
	%LevelBar.add_theme_stylebox_override("background", _box(Palette.PAPER_DEEP, 7, 0))
	%LevelBar.add_theme_stylebox_override("fill", _box(Palette.ORANGE, 7, 0))
	for pill in [%CoinsPill, %XpPill]:
		pill.add_theme_stylebox_override("panel", _box(glass, 30, 4, Vector4(14, 8, 18, 8)))
	%SyncDot.add_theme_stylebox_override("panel", _box(glass, 30, 4))
	%CoinsIcon.texture = Icons.tex("coins")
	%CoinsIcon.self_modulate = Palette.MANGO_DEEP
	%XpIcon.texture = Icons.tex("bolt")
	%XpIcon.self_modulate = Palette.MANGO
	%SyncIcon.texture = Icons.tex("cloud")
	for l in [%ShopLabel, %TodayLabel]:
		l.add_theme_stylebox_override("normal", _box(Palette.CARD, 16, 3, Vector4(14, 2, 14, 4)))
	var dot := _box(Palette.CORAL_DEEP, 15, 0)
	dot.set_border_width_all(4)
	dot.border_color = Palette.CARD
	%Dot.add_theme_stylebox_override("panel", dot)
	%Picks.add_theme_stylebox_override("panel", _box(glass, 28, 6, Vector4(14, 14, 14, 16)))
	var tab := _box(glass, 0, 4)
	tab.corner_radius_top_left = 20
	tab.corner_radius_bottom_left = 20
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		%PicksTab.add_theme_stylebox_override(s, tab)
	%PicksTab.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	%Tip.add_theme_stylebox_override("panel", _box(Color(Palette.INK, 0.92), 20, 0, Vector4(20, 12, 20, 12)))
	var bar := _box(Palette.CARD, 0, 0, Vector4(10, 8, 10, 6))
	bar.corner_radius_top_left = 34
	bar.corner_radius_top_right = 34
	bar.shadow_color = Color(Palette.SHADOW, 0.25)
	bar.shadow_offset = Vector2(0, -6)
	bar.shadow_size = 1
	%BottomBar.add_theme_stylebox_override("panel", bar)
	_tab(%ClosetTab, "hat", Palette.BAY_DEEP)
	_tab(%StickersTab, "star", Palette.MANGO_DEEP)
	_tab(%WordsTab, "pencil", Palette.CORAL_DEEP)


func _tab(b: Button, icon: String, tint: Color) -> void:
	b.icon = Icons.tex(icon)
	b.add_theme_constant_override("icon_max_width", 50)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		b.add_theme_color_override(c, Palette.INK)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color",
			"icon_hover_pressed_color"]:
		b.add_theme_color_override(c, tint)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _crest(col: Color) -> StyleBoxFlat:
	var sb := _box(col, 60, 6)
	sb.set_border_width_all(6)
	sb.border_color = Palette.CARD
	return sb


## A rounded paper box; `pad` = left, top, right, bottom content margins.
func _box(col: Color, r: int, lift: int, pad := Vector4.ZERO) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(r)
	sb.anti_aliasing = true
	if lift > 0:
		sb.shadow_color = Color(Palette.SHADOW, 0.2)
		sb.shadow_offset = Vector2(0, lift)
		sb.shadow_size = 1
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb
