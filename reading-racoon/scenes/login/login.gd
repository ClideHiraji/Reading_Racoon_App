extends Control
## Sign in once with the student's login code from the teacher (FR-01, D-010).
## A big on-screen keypad holds only the letters and numbers a code can have
## (no 0/O/1/I/L to mix up), so there's no phone keyboard and no settings to fill
## in: the server address is built into the app. After this the app opens
## straight to play, offline too, and saving to the server is automatic.

const ANDIKA := preload("res://assets/fonts/Andika-Bold.ttf")

var _code := ""
var _boxes: Array[Label] = []


func _ready() -> void:
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
	del.custom_minimum_size = Vector2(82, 82)
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
		hello = "Welcome back, %s! Type your code again." % GameState.student_name()
	%Bubble.say(hello)
	Speech.say(hello)


func _box() -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(Palette.SHADOW, 0.16)
	sb.shadow_offset = Vector2(0, 5)
	sb.shadow_size = 1
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(68, 88)
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
	b.radius = 16
	b.custom_minimum_size = Vector2(82, 82)
	b.add_theme_font_override("font", ANDIKA)
	b.add_theme_font_size_override("font_size", 42)
	b.pressed.connect(_type.bind(ch))
	return b


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
		var sb: StyleBoxFlat = box.get_theme_stylebox("panel")
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
		%Bubble.say("Hi, %s!" % GameState.student_name())
		Speech.say("Hi, %s!" % GameState.student_name())
		await get_tree().create_timer(1.0).timeout
		_continue()
		return
	%Error.text = err
	%Raccoon.set_mood("encourage")
	Speech.say(err)
	_refresh()


## After signing in: the Reading Adventure the first time, then the home hub.
func _continue() -> void:
	if not GameState.guard_hub():
		return
	if GameState.needs_pretest():
		GameState.start_assessment("pre")
	else:
		get_tree().change_scene_to_file(GameState.HUB_SCENE)


## Debug builds only: play without a server (classroom demos, tests).
func _skip() -> void:
	_continue()
