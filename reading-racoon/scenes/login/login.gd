extends Control
## Sign in once with the student's login code from the teacher (FR-01, D-010).
## A big on-screen keypad holds only the letters and numbers a code can have
## (no 0/O/1/I/L to mix up), so there's no phone keyboard and no settings to fill
## in: the server address is built into the app. After this the app opens
## straight to play, offline too, and saving to the server is automatic.

const ANDIKA := preload("res://assets/fonts/Andika-Bold.ttf")

var _code := ""
var _boxes: Array[Label] = []
var _key_px := 100.0


func _ready() -> void:
	_fit_shape()
	for i in LoginCode.LENGTH:
		if i == 4:
			var dash := Label.new()
			dash.text = "-"
			dash.add_theme_font_override("font", ANDIKA)
			dash.add_theme_font_size_override("font_size", 52)
			dash.add_theme_color_override("font_color", Palette.INK_SOFT)
			%CodeRow.add_child(dash)
		%CodeRow.add_child(_box())
	for ch in LoginCode.ALPHABET:
		%Keys.add_child(_key(ch))
	var del := ChunkyButton.new()
	del.card_style = true
	del.lift = 6
	del.custom_minimum_size = Vector2(_key_px, _key_px)
	del.tooltip_text = "Delete"
	var icon := BackspaceIcon.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_bottom = -6
	del.add_child(icon)
	del.pressed.connect(_delete)
	%Keys.add_child(del)
	%GoButton.pressed.connect(_submit)
	%SkipButton.visible = OS.is_debug_build()
	%SkipButton.pressed.connect(_skip)
	_refresh()
	%Raccoon.set_mood("happy")
	var hello := "Hi! Type the code on your card."
	if GameState.student_name() != "":
		hello = "Welcome back, reader! Type your code again."   # no name: the line is recorded
	%Bubble.say(hello)
	Speech.say(hello, "en")


func _box() -> Control:
	var p := PanelContainer.new()
	var sb := PaperBox.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(Palette.SHADOW, 0.16)
	sb.shadow_offset = Vector2(0, 5)
	sb.shadow_size = 1
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(72, 96)
	var l := Label.new()
	l.add_theme_font_override("font", ANDIKA)
	l.add_theme_font_size_override("font_size", 50)
	l.add_theme_color_override("font_color", Palette.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	_boxes.append(l)
	return p


func _key(ch: String) -> ChunkyButton:
	var b := ChunkyButton.new()
	b.text = ch
	b.card_style = true
	b.lift = 6
	b.radius = 20
	b.custom_minimum_size = Vector2(_key_px, _key_px)   # 100 px keys, 90 on a laptop (D-022, D-023)
	b.add_theme_font_override("font", ANDIKA)
	b.add_theme_font_size_override("font_size", 48)
	b.pressed.connect(_type.bind(ch))
	return b


## Laptops (D-023): Racoon, his bubble and LET'S GO in a column on the left,
## the code and eight columns of keys on the right, so it all fits the shorter
## screen. Both shapes keep clear of a notch.
func _fit_shape() -> void:
	var margin: MarginContainer = $Margin
	if Kit.landscape():
		var col: VBoxContainer = $Margin/VBox
		var top: Control = $Margin/VBox/Top
		var spacer: Control = $Margin/VBox/Spacer
		var body := HBoxContainer.new()
		body.add_theme_constant_override("separation", 32)
		margin.add_child(body)
		var side := VBoxContainer.new()
		side.custom_minimum_size = Vector2(360, 0)
		side.alignment = BoxContainer.ALIGNMENT_END
		side.add_theme_constant_override("separation", 24)
		body.add_child(side)
		col.reparent(body, false)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var bubble: SpeechBubble = %Bubble
		bubble.tail = "down"
		bubble.tail_x = 140.0
		bubble.reparent(side, false)
		%Raccoon.custom_minimum_size = Vector2(200, 200)
		%Raccoon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		%Raccoon.reparent(side, false)
		%GoButton.reparent(side, false)
		%SkipButton.reparent(side, false)
		# Its long debug-only line wraps: on one line it widened the column past the screen's edges.
		%SkipButton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		top.queue_free()
		spacer.queue_free()
		%Keys.columns = 8
		_key_px = 90.0
		for edge in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + edge, 40)
		margin.add_theme_constant_override("margin_top", 24)
		margin.add_theme_constant_override("margin_bottom", 20)
	Kit.fit_safe(margin)


## On a laptop the child can type the code on the keyboard too: letters and
## numbers, Backspace, and Enter for LET'S GO (D-023).
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_BACKSPACE:
		_delete()
	elif key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if not %GoButton.disabled:   # not twice while it is checking
			_submit()
	else:
		var ch := char(key.unicode).to_upper() if key.unicode > 0 else ""
		if ch == "" or not LoginCode.ALPHABET.contains(ch):
			return
		_type(ch)
	get_viewport().set_input_as_handled()


func _type(ch: String) -> void:
	if _code.length() < LoginCode.LENGTH:
		_code += ch
		%Error.text = ""
		_refresh()


func _delete() -> void:
	_code = _code.substr(0, maxi(_code.length() - 1, 0))
	%Error.text = ""
	_refresh()


func _refresh() -> void:
	for i in _boxes.size():
		_boxes[i].text = _code[i] if i < _code.length() else ""
		var box: PanelContainer = _boxes[i].get_parent()
		var sb: PaperBox = box.get_theme_stylebox("panel")
		sb.border_color = Palette.ORANGE
		sb.set_border_width_all(4 if i == _code.length() else 0)
	%GoButton.disabled = _code.length() != LoginCode.LENGTH
	%GoButton.modulate.a = 1.0 if not %GoButton.disabled else 0.5


func _submit() -> void:
	if _code.length() != LoginCode.LENGTH:
		return
	%GoButton.disabled = true
	%GoButton.text = "CHECKING..."
	%Raccoon.set_mood("thinking")
	var err: String = await Sync.login(_code)
	%GoButton.text = "LET'S GO!"
	if err == "":
		%Raccoon.set_mood("celebrate")
		%Bubble.say("Hi, reader!")
		Speech.say("Hi, reader!", "en")
		await get_tree().create_timer(1.0).timeout
		_continue()
		return
	%Error.text = err
	%Raccoon.set_mood("encourage")
	Speech.say(err, "en")
	_refresh()


## After signing in: the home hub (the pre-test waits on the Adventure map, D-021).
func _continue() -> void:
	if not GameState.guard_hub():
		return
	# a new student picks a buddy and a language first (D-033)
	get_tree().change_scene_to_file(GameState.HUB_SCENE if GameState.buddy_chosen() else GameState.BUDDY_SCENE)


## Debug builds only: play without a server (classroom demos, tests).
func _skip() -> void:
	_continue()
