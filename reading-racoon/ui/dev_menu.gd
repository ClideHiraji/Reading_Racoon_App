class_name DevMenu
extends CanvasLayer
## Developer menu (issue 30): jump to any screen, add coins, unlock worlds, fill the collections,
## move the clock and show the frame rate, to explore the game quickly.
##
## Debug builds only (the editor and debug exports): a release export never shows it.
## Open or close it with F12, or tap the top-right corner of the screen 5 times quickly.
##
## DELETE BEFORE THE FINAL RELEASE (issue 30 in docs/knowledge/10-open-issues.md): this file, its
## two lines in scripts/autoload/screen.gd, and its check at the end of tests/ui_smoke.gd.

const ENABLED := true      # the master switch: false hides it in debug builds too
const TAPS := 5
const TAP_WINDOW_MS := 2500
const CORNER := 96.0       # the top-right corner's size, in canvas px
## Monday at 7:45, inside the default reading time, and Tuesday evening, after it (as hub_shots.gd).
const MORNING := {"year": 2026, "month": 10, "day": 19, "weekday": 1, "hour": 7, "minute": 45, "second": 0}
const EVENING := {"year": 2026, "month": 10, "day": 20, "weekday": 2, "hour": 18, "minute": 0, "second": 0}

static var _taps: Array[int] = []

var _col: VBoxContainer
var _info: Label


static func allowed() -> bool:
	return ENABLED and OS.is_debug_build()


## Screen's input hook: F12, or five quick taps in the top-right corner, opens or closes the menu.
## It only looks at the input; the screen underneath still gets it.
static func handle_input(event: InputEvent, tree: SceneTree) -> void:
	if not allowed():
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F12:
		toggle(tree)
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var size := tree.root.get_visible_rect().size
	if mb.position.x < size.x - CORNER or mb.position.y > CORNER:
		return
	var now := Time.get_ticks_msec()
	var recent: Array[int] = []
	for t in _taps:
		if now - t < TAP_WINDOW_MS:
			recent.append(t)
	recent.append(now)
	_taps = recent
	if _taps.size() >= TAPS:
		_taps.clear()
		toggle(tree)


static func toggle(tree: SceneTree) -> void:
	var open := tree.root.get_node_or_null("DevMenu")
	if open:
		open.queue_free()
	else:
		var menu := DevMenu.new()
		menu.name = "DevMenu"
		tree.root.add_child(menu)


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var view := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := Kit.card(22)
	card.custom_minimum_size = Vector2(minf(view.x - 40.0, 680.0), 0)
	center.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(view.y - 120.0, 1060.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	_col = VBoxContainer.new()
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_theme_constant_override("separation", 12)
	scroll.add_child(_col)
	_build()


func close() -> void:
	queue_free()


func _gs() -> Node:
	return get_node_or_null("/root/GameState")


func _build() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var title := Kit.label("Developer menu", 34, Palette.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("Close", close, Palette.PAPER_DEEP))
	_col.add_child(head)
	var note := Kit.label("Debug builds only: F12, or 5 quick taps in the top-right corner. "
			+ "Delete before the final release (issue 30).", 20, Palette.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(note)
	_info = Kit.label("", 22, Palette.INK)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(_info)
	_refresh_info()

	var go := [["Home", _go.bind("res://scenes/hub/hub.tscn")],
			["Lesson", _lesson], ["Pre-test", _assessment.bind("pre")]]
	for id in HubSections.ALL:
		var info: Dictionary = HubSections.ALL[id]
		if str(info.get("scene", "")) != "":
			go.append([str(info.name), _go.bind(info.scene)])
	go.append(["Login", _go.bind("res://scenes/login/login.tscn")])
	go.append(["Lock screen", _go.bind("res://scenes/lock/lock_screen.tscn")])
	_section("Go to", go)
	_section("Coins", [["+50", add_coins.bind(50)], ["+500", add_coins.bind(500)], ["None", _set_coins.bind(0)]])
	_section("Progress", [["Unlock all worlds", _changed.bind(_unlock_worlds)],
			["Finish this world", _changed.bind(_finish_world)],
			["Skip the pre-test", _changed.bind(_skip_pretest)],
			["Open the post-test", _changed.bind(_open_posttest)],
			["Reset all progress", _changed.bind(_reset)]])
	_section("Collections", [["All stickers", _changed.bind(_all_stickers)],
			["All Closet items", _changed.bind(_all_items)],
			["Today's goals done", _changed.bind(_all_goals)]])
	_section("Clock", [["Mon 7:45 AM", _changed.bind(_clock.bind(MORNING))],
			["Tue 6 PM", _changed.bind(_clock.bind(EVENING))],
			["Real time", _changed.bind(_clock.bind({}))]])
	_section("Show", [["Frame rate", _toggle_fps], ["A reward card", _reward]])


func _section(title: String, buttons: Array) -> void:
	_col.add_child(Kit.label(title, 26, Palette.INK, true))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	for b: Array in buttons:
		flow.add_child(_button(str(b[0]), b[1]))
	_col.add_child(flow)


func _button(text: String, action: Callable, face: Color = Palette.YELLOW) -> ChunkyButton:
	var b := ChunkyButton.new()
	b.text = text
	b.face_color = face
	b.custom_minimum_size = Vector2(0, 72)
	b.pad = 16
	b.radius = 18
	b.lift = 4
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	return b


func _refresh_info() -> void:
	var gs := _gs()
	if gs == null:
		_info.text = "No GameState."
		return
	var clock: String = "real time" if gs._debug_now.is_empty() else "%s %02d:%02d" % [gs.today(),
			int(gs._debug_now.hour), int(gs._debug_now.minute)]
	var who: String = gs.student_name() if gs.student_name() != "" else "No profile"
	_info.text = "%s · world %d unlocked · %d coins · %d stickers · clock: %s" % [who,
			gs.model.highest_unlocked, int(gs.wallet.coins), gs.collection.count(), clock]


# --- actions --------------------------------------------------------------------------------

func _go(scene: String) -> void:
	close()
	get_tree().change_scene_to_file(scene)


func _lesson() -> void:
	var gs := _gs()
	var level: int = gs.model.highest_unlocked
	gs.lesson_mode = "lesson"
	gs.lesson_world = level
	gs.lesson_node = mini(int(gs.path.world(level).done), PathProgress.LESSONS_PER_WORLD - 1)
	gs.lesson_as_bonus = false
	_go("res://scenes/lesson/lesson.tscn")


func _assessment(kind: String) -> void:
	var gs := _gs()
	gs.lesson_mode = kind
	gs.lesson_world = 1
	_go("res://scenes/lesson/lesson.tscn")


func add_coins(n: int) -> void:
	_set_coins(int(_gs().wallet.coins) + n)


func _set_coins(n: int) -> void:
	var gs := _gs()
	gs.wallet.coins = maxi(0, n)
	gs.wallet_changed.emit()
	gs.save_profile()
	_refresh_info()


## Runs a change to the saved game, saves it and reloads the screen so it shows the change.
func _changed(change: Callable) -> void:
	change.call()
	var gs := _gs()
	gs._decision_age = 99.0   # the access rules look again now, not in a few seconds
	gs.save_profile()
	gs.outfit_changed.emit()
	close()
	get_tree().reload_current_scene()


func _unlock_worlds() -> void:
	var gs := _gs()
	gs.model.highest_unlocked = mini(SkillCatalog.MAX_LEVEL, int(gs.content_max_level()))


func _finish_world() -> void:
	var gs := _gs()
	for n in PathProgress.LESSONS_PER_WORLD:
		gs.path.complete_lesson(gs.model.highest_unlocked, n)


func _skip_pretest() -> void:
	var gs := _gs()
	if not gs.assessments.has("pre"):
		gs.assessments["pre"] = {"date": gs.today(), "correct": 0, "total": 0, "scores": {}, "placed_level": 1}


func _open_posttest() -> void:
	_gs().settings["post_test_open"] = true


func _reset() -> void:
	_gs().reset_progress()


func _all_stickers() -> void:
	var gs := _gs()
	for id in Collection.STICKERS:
		if not gs.collection.has_sticker(id):
			gs.collection.stickers[id] = gs.today()


func _all_items() -> void:
	var gs := _gs()
	for id in Wardrobe.ITEMS:
		if not gs.wardrobe.owns(id):
			gs.wardrobe.owned.append(id)


func _all_goals() -> void:
	var gs := _gs()
	for g: Dictionary in Collection.GOALS:
		gs.collection.complete_goal(str(g.id), gs.today())


func _clock(at: Dictionary) -> void:
	_gs()._debug_now = at.duplicate()


func _toggle_fps() -> void:
	var root := get_tree().root
	var fps := root.get_node_or_null("DevFps")
	if fps:
		fps.queue_free()
		return
	var hud := CanvasLayer.new()
	hud.name = "DevFps"
	hud.layer = 121
	var l := Label.new()
	l.position = Vector2(12, 8)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Palette.INK)
	l.add_theme_color_override("font_outline_color", Palette.CARD)
	l.add_theme_constant_override("outline_size", 6)
	hud.add_child(l)
	root.add_child(hud)
	var t := Timer.new()
	t.wait_time = 0.5
	t.autostart = true
	t.timeout.connect(func() -> void:
		l.text = "%d fps · %.1f ms" % [Engine.get_frames_per_second(),
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	hud.add_child(t)


func _reward() -> void:
	var scene := get_tree().current_scene as Control
	close()
	if scene:
		Kit.reward(scene, "A test reward", {"coins": 10}, func() -> void: pass)
