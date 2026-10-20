extends Control
## Grown-ups screen for teachers and parents, behind a simple gate (a times-table
## question children this age don't know yet). Connect the device to the school
## server (FR-01, temporary login code until open issue 9), see and force the sync
## (FR-11), open the post-test (FR-10), and check the play-time schedule (FR-12).

var _answer := 0
var _server: LineEdit
var _code: LineEdit
var _connect_status: Label
var _sync_label: Label


func _ready() -> void:
	%BackButton.pressed.connect(_back)
	_show_gate()


func _clear() -> void:
	for c in %Content.get_children():
		c.queue_free()


# --- Gate ------------------------------------------------------------------------------

func _show_gate() -> void:
	_clear()
	var a := randi_range(4, 9)
	var b := randi_range(3, 9)
	_answer = a * b
	%Content.add_child(_title("For grown-ups"))
	%Content.add_child(_text("Please answer to continue:"))
	var q := _title("%d  ×  %d  =  ?" % [a, b])
	q.add_theme_font_size_override("font_size", 64)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%Content.add_child(q)
	var options := [_answer, _answer + randi_range(1, 4), maxi(1, _answer - randi_range(2, 6))]
	options.shuffle()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	for o in options:
		var b2 := ChunkyButton.new()
		b2.text = str(o)
		b2.card_style = true
		b2.custom_minimum_size = Vector2(170, 120)
		b2.add_theme_font_size_override("font_size", 46)
		b2.pressed.connect(_on_gate.bind(int(o)))
		row.add_child(b2)
	%Content.add_child(row)


func _on_gate(n: int) -> void:
	if n == _answer:
		_show_settings()
	else:
		_back()


# --- Settings ----------------------------------------------------------------------------

func _show_settings() -> void:
	_clear()
	%Content.add_child(_title("Grown-ups"))

	var connect := _card("School server", "stories")
	_server = _line_edit(str(GameState.settings.get("server_url", "")), "https://server-address")
	connect.add_child(_text("Server address"))
	connect.add_child(_server)
	_code = _line_edit("", "Student login code, e.g. K7PM-3QXA")
	connect.add_child(_text("Student login code (from the teacher)"))
	connect.add_child(_code)
	_connect_status = _text("")
	connect.add_child(_connect_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.add_child(_button("CONNECT", Palette.TEAL, _on_connect))
	buttons.add_child(_button("DISCONNECT", Palette.INK_SOFT, _on_disconnect))
	connect.add_child(buttons)

	var sync := _card("Saving to the server", "repeat")
	_sync_label = _text("")
	sync.add_child(_sync_label)
	sync.add_child(_button("SYNC NOW", Palette.LEAF, func(): Sync.sync_now()))
	Sync.status_changed.connect(func(_t): _refresh())

	var tests := _card("Reading Adventure", "star")
	var pre: Dictionary = GameState.assessments.get("pre", {})
	var post: Dictionary = GameState.assessments.get("post", {})
	tests.add_child(_text("Pre-test: %s" % ("done on %s" % pre.date if not pre.is_empty() else "not yet")))
	tests.add_child(_text("Post-test: %s" % ("done on %s" % post.date if not post.is_empty() else "not yet")))
	var toggle := CheckButton.new()
	toggle.text = "Open Big Reading Day (post-test)"
	toggle.add_theme_font_size_override("font_size", 28)
	toggle.add_theme_color_override("font_color", Palette.INK)
	toggle.button_pressed = bool(GameState.settings.get("post_test_open", false))
	toggle.toggled.connect(func(on):
		GameState.settings.post_test_open = on
		GameState.save_profile())
	tests.add_child(toggle)
	tests.add_child(_text("The teacher's server setting overrides this when the device syncs.", true))

	var time := _card("Play time", "night")
	var sched: Dictionary = GameState.access.schedule
	if sched.is_empty():
		time.add_child(_text("No schedule from the school yet, so the game is always open."))
	else:
		var s := AccessPolicy.DEFAULTS.duplicate()
		s.merge(sched, true)
		time.add_child(_text("Reading time %s-%s, after school %s-%s, %d min a day." % [s.class_start,
				s.class_end, s.after_school_start, s.after_school_end, s.daily_minutes]))
	time.add_child(_text("Played today: %d min. Now: %s" % [int(GameState.minutes_used_today()),
			GameState.access_decision().status]))
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(_sync_label):
		return
	var waiting := GameState.store.queue_size()
	var who: String = GameState.device.get("student_name", "")
	_connect_status.text = ("Connected as %s" % who) if Sync.connected() else "Not connected"
	_sync_label.text = "%d answers waiting to upload. %s" % [waiting, Sync.last_status]


func _on_connect() -> void:
	GameState.settings.server_url = _server.text.strip_edges()
	GameState.save_profile()
	_connect_status.text = "Connecting..."
	var err: String = await Sync.login(_code.text)
	_connect_status.text = err if err != "" else "Connected!"
	_refresh()


func _on_disconnect() -> void:
	Sync.logout()
	_refresh()


func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --- Builders ----------------------------------------------------------------------------

func _card(title: String, icon: String) -> VBoxContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(24)
	sb.set_content_margin_all(22)
	sb.shadow_color = Color(Palette.SHADOW, 0.18)
	sb.shadow_offset = Vector2(0, 6)
	sb.shadow_size = 1
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(Icons.rect(icon, 40, Palette.TEAL))
	var t := _title(title)
	t.add_theme_font_size_override("font_size", 32)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # a wrapping label in a row must expand
	head.add_child(t)
	v.add_child(head)
	%Content.add_child(card)
	return v


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"TitleLabel"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _text(text: String, muted: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24 if muted else 27)
	l.add_theme_color_override("font_color", Palette.INK_SOFT if muted else Palette.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _line_edit(value: String, hint: String) -> LineEdit:
	var e := LineEdit.new()
	e.text = value
	e.placeholder_text = hint
	e.custom_minimum_size = Vector2(0, 76)
	e.add_theme_font_size_override("font_size", 28)
	e.add_theme_color_override("font_color", Palette.INK)
	e.add_theme_color_override("font_placeholder_color", Color(Palette.INK_SOFT, 0.6))
	for state in ["normal", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Palette.PAPER
		sb.set_corner_radius_all(16)
		sb.set_border_width_all(3 if state == "focus" else 2)
		sb.border_color = Palette.TEAL if state == "focus" else Palette.PAPER_DEEP
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		e.add_theme_stylebox_override(state, sb)
	return e


func _button(text: String, color: Color, action: Callable) -> ChunkyButton:
	var b := ChunkyButton.new()
	b.text = text
	b.face_color = color
	b.custom_minimum_size = Vector2(0, 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(action)
	return b
