extends Control
## The Watch & Listen player. Songs, chants and read-alongs play line by line: the scene and
## pictures on the stage, the words lighting up as Racoon sings them.
## Teacher videos (Ogg Theora, downloaded on Wi-Fi) play in the same frame.
## Then a quick check with two pictures, and nothing else plays by itself.
## Controls are blue: a round Again and a big Pause. A teacher video can also go full screen,
## and a phone turns sideways for it.

## How long full screen's buttons stay after a tap while the video plays.
const FULL_CONTROLS_FOR := 3.0

var _item := {}
var _lines: Array = []
var _lang := "en"
var _i := -1
var _paused := false
var _started := 0
var _stage: PanelContainer
var _scene: PaperScenery
var _pictures: HBoxContainer
var _video: VideoStreamPlayer
var _text: ReadAlong
var _bar: ProgressBar
var _play_btn: ChunkyButton
var _raccoon: Raccoon
var _full: ColorRect            # full screen, while it's open (teacher videos only)
var _full_controls: MarginContainer
var _full_play: ChunkyButton
var _controls_tween: Tween
var _controls_id := 0           # the latest tap; an older tap's timer does nothing
var _orientation_before := -1   # the phone's orientation before full screen turned it


func _ready() -> void:
	if not GameState.guard_free_play():
		return
	_started = Time.get_ticks_msec()
	_item = GameState.media.media(GameState.open_media)
	_lines = GameState.media.lines_of(_item)
	_lang = str(_item.get("language", "en"))
	var column := Kit.page(self)
	Kit.header(column, str(_item.get("title", "Watch")), _back, true)
	# On a laptop the stage stands beside the words card.
	var wide := Kit.landscape()
	var sheet := BoxContainer.new()
	sheet.vertical = not wide
	sheet.add_theme_constant_override("separation", 0)
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(sheet)
	_stage = PanelContainer.new()
	var stage_box := Kit.box(Palette.SKY, 28)
	stage_box.corner_radius_bottom_right = 0
	if wide:
		stage_box.corner_radius_top_right = 0
	else:
		stage_box.corner_radius_bottom_left = 0
	_stage.add_theme_stylebox_override("panel", stage_box)
	_stage.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_stage.custom_minimum_size = Vector2(580, 0) if wide else Vector2(0, 430)
	sheet.add_child(_stage)
	_scene = PaperScenery.new()
	_scene.scene = str(_item.get("scene", "home"))
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_scene)
	_pictures = HBoxContainer.new()
	_pictures.alignment = BoxContainer.ALIGNMENT_CENTER
	_pictures.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pictures.add_theme_constant_override("separation", 12)
	_pictures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_pictures)

	var card := Kit.card(30)
	var card_box: PaperBox = card.get_theme_stylebox("panel").duplicate()
	card_box.corner_radius_top_left = 0
	if wide:
		card_box.corner_radius_bottom_left = 0
	else:
		card_box.corner_radius_top_right = 0
	card.add_theme_stylebox_override("panel", card_box)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_child(card)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 30)
	card.add_child(words)
	_text = ReadAlong.new()
	_text.language = _lang
	_text.font_size = 52
	_text.done.connect(_on_line_done)
	words.add_child(_text)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.add_theme_stylebox_override("background", Kit.box(Palette.PAPER_DEEP, 7))
	_bar.add_theme_stylebox_override("fill", Kit.box(Palette.BLUE, 7))
	words.add_child(_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	_raccoon = Raccoon.new()
	_raccoon.custom_minimum_size = Vector2(130, 130)
	row.add_child(_raccoon)
	var again := ChunkyButton.new()
	again.card_style = true
	again.icon_name = "repeat"
	again.icon_px = 54
	again.icon_tint = Palette.BAY_DEEP
	again.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	again.expand_icon = true
	again.radius = 56
	again.tooltip_text = "Play again from the start"
	again.custom_minimum_size = Vector2(112, 112)
	again.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(_restart)
	row.add_child(again)
	_play_btn = Kit.button("Pause", Palette.BLUE, "pause", 128)
	_play_btn.icon_px = 48
	_play_btn.add_theme_font_size_override("font_size", 38)
	_play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_play_btn.pressed.connect(_toggle)
	row.add_child(_play_btn)

	if _item.get("kind", "") == "video":
		_setup_video()
	else:
		_bar.max_value = maxi(_lines.size(), 1)
		await get_tree().process_frame
		_next_line()


# --- Songs, chants and read-alongs ---------------------------------------------------------

func _next_line() -> void:
	_i += 1
	_bar.value = _i
	if _i >= _lines.size():
		_end()
		return
	var line: Dictionary = _lines[_i]
	if line.has("scene"):
		_scene.scene = str(line.scene)
	for c in _pictures.get_children():
		c.queue_free()
	var pics: Array = line.get("pictures", [])
	for k in pics.size():
		if Icons.exists(pics[k]):
			var p := Kit.picture(pics[k], 140 if pics.size() <= 2 else 96)
			_pictures.add_child(p)
			_bounce(p, k * 0.12)
	_text.set_text(str(line.get("text", "")))
	_raccoon.set_mood("celebrate" if _item.get("kind", "") == "song" else "happy")
	_text.play()


func _bounce(node: Control, delay: float) -> void:
	node.pivot_offset = Vector2(70, 70)
	var t := node.create_tween().set_loops()
	t.tween_interval(delay)
	t.tween_property(node, "scale", Vector2(1.08, 1.08), 0.3).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE)


func _on_line_done() -> void:
	if _paused:
		return
	await get_tree().create_timer(0.5).timeout
	if is_inside_tree() and not _paused and not _text.playing():
		_next_line()


func _toggle() -> void:
	_paused = not _paused
	_play_btn.text = "Play" if _paused else "Pause"
	_play_btn.icon_name = "play" if _paused else "pause"
	if _full_play:
		_full_play.tooltip_text = _play_btn.text
		_full_play.icon_name = _play_btn.icon_name
	if _video:
		_video.paused = _paused
		_show_full_controls()
		return
	if _paused:
		_text.stop()
	elif _i < _lines.size():
		_text.play()


func _restart() -> void:
	_paused = false
	_play_btn.text = "Pause"
	_play_btn.icon_name = "pause"
	if _video:
		_video.stop()
		_video.play()
		return
	_text.stop()
	_i = -1
	_next_line()


# --- Teacher videos ---------------------------------------------------------------------

func _setup_video() -> void:
	_scene.visible = false
	_text.set_text(str(_item.get("title", "")))
	_bar.max_value = 1.0
	var stream := VideoStreamTheora.new()
	stream.file = str(_item.get("file", ""))
	_video = VideoStreamPlayer.new()
	_video.stream = stream
	_video.expand = true
	_video.finished.connect(_end)
	# `expand` alone stretched the clip to fill the stage (a 16:9 clip lost width on a phone).
	# The box keeps the clip's own shape, centred, with sky bands on two sides.
	# Theora knows the frame size from the file's header.
	var box := AspectRatioContainer.new()
	box.stretch_mode = AspectRatioContainer.STRETCH_FIT
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := _video.get_video_texture().get_size() if _video.get_video_texture() else Vector2.ZERO
	box.ratio = frame.aspect() if frame.x > 0.0 and frame.y > 0.0 else 16.0 / 9.0
	box.add_child(_video)
	_stage.add_child(box)
	# Full screen: the button in the stage's corner, or a tap on the picture.
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.gui_input.connect(_on_stage_input)
	var corner := MarginContainer.new()
	corner.size_flags_horizontal = Control.SIZE_SHRINK_END
	corner.size_flags_vertical = Control.SIZE_SHRINK_END
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		corner.add_theme_constant_override("margin_" + side, 14)
	corner.add_child(_round_button("full_screen", "Full screen", 96, _open_full_screen))
	_stage.add_child(corner)
	_video.play()


func _process(_delta: float) -> void:
	if _video and _video.is_playing():
		var length := _video.get_stream_length()
		if length > 0.0:
			_bar.value = _video.stream_position / length


## A round white button with a blue icon, like Again. At least 96 px.
func _round_button(icon: String, tip: String, px: int, on_press: Callable) -> ChunkyButton:
	var b := ChunkyButton.new()
	b.card_style = true
	b.icon_name = icon
	b.icon_px = int(px * 0.48)
	b.icon_tint = Palette.BAY_DEEP
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.radius = roundi(px / 2.0)
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(px, px)
	b.pressed.connect(on_press)
	return b


static func _is_tap(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	return mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT


func _on_stage_input(event: InputEvent) -> void:
	if _is_tap(event):
		_open_full_screen()


# --- Full screen (teacher videos) --------------------------------------------------------

## The same video over the whole player, in its own shape on dark ink, so playback never stops
## or restarts. A phone turns sideways for it. A tap shows a big Pause and the close button;
## while the video plays they fade after a while.
func _open_full_screen() -> void:
	if _full or not _video:
		return
	_full = ColorRect.new()
	_full.name = "FullScreen"
	_full.color = Palette.INK
	_full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full.gui_input.connect(_on_full_input)
	add_child(_full)
	var pic := TextureRect.new()
	pic.texture = _video.get_video_texture()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full.add_child(pic)
	_full_controls = MarginContainer.new()
	_full_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full.add_child(_full_controls)
	var close := _round_button("full_screen_exit", "Small screen", 112, _close_full_screen)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_full_controls.add_child(close)
	_full_play = _round_button("play" if _paused else "pause", "Play" if _paused else "Pause", 160, _toggle)
	_full_play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_full_play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_full_controls.add_child(_full_play)
	# The notch moves to a side when the phone turns, so the margins follow the size.
	_full.resized.connect(_fit_full_controls)
	_fit_full_controls()
	_turn(true)
	_show_full_controls()


func _fit_full_controls() -> void:
	var safe := Kit.insets()
	for side: String in ["left", "top", "right", "bottom"]:
		_full_controls.add_theme_constant_override("margin_" + side, int(24 + safe[side]))


func _on_full_input(event: InputEvent) -> void:
	if _is_tap(event):
		_show_full_controls()


## Shows full screen's buttons. While the video plays they fade after
## FULL_CONTROLS_FOR seconds; while it's paused they stay.
func _show_full_controls() -> void:
	if not _full:
		return
	_controls_id += 1
	var id := _controls_id
	if _controls_tween:
		_controls_tween.kill()
	_full_controls.visible = true
	_full_controls.modulate.a = 1.0
	if _paused:
		return
	await get_tree().create_timer(FULL_CONTROLS_FOR).timeout
	if _full and id == _controls_id and not _paused:
		_controls_tween = _full_controls.create_tween()
		_controls_tween.tween_property(_full_controls, "modulate:a", 0.0, 0.3)
		_controls_tween.tween_callback(_full_controls.hide)


func _close_full_screen() -> void:
	if not _full:
		return
	_controls_id += 1
	remove_child(_full)
	_full.queue_free()
	_full = null
	_full_controls = null
	_full_play = null
	_controls_tween = null
	_turn(false)


## A phone turns sideways for full screen, then back to how it was (the game is
## portrait). Laptops and the editor don't turn: their window is already the screen.
func _turn(sideways: bool) -> void:
	if not OS.has_feature("mobile"):
		return
	if sideways and _orientation_before < 0:
		_orientation_before = DisplayServer.screen_get_orientation()
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	elif not sideways and _orientation_before >= 0:
		DisplayServer.screen_set_orientation(_orientation_before as DisplayServer.ScreenOrientation)
		_orientation_before = -1


func _exit_tree() -> void:
	_turn(false)   # leaving the player never leaves a phone sideways


## Android Back (Screen.back): full screen closes first; otherwise it's the ✕.
func go_back() -> void:
	if _full:
		_close_full_screen()
	else:
		_back()


# --- The end: a quick check, then the reward --------------------------------------------

func _end() -> void:
	_close_full_screen()
	_raccoon.set_mood("celebrate")
	var check: Dictionary = _item.get("check", {})
	if check.is_empty():
		_reward(true)
		return
	var v := Kit.overlay(self)
	var prompt := Kit.label(str(check.prompt), 34, Palette.INK, true)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(prompt)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	var buttons := {}
	for c in check.choices:
		var b := ChunkyButton.new()
		b.card_style = true
		b.custom_minimum_size = Vector2(220, 240)
		b.tooltip_text = str(c.get("label", c.id))
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if c.has("picture") and Icons.exists(c.picture):
			var pic := Kit.picture(c.picture, 130)
			pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(pic)
		col.add_child(Kit.word_label(str(c.get("label", c.id)), 30))
		b.add_child(col)
		row.add_child(b)
		buttons[str(c.id)] = b
	for id in buttons:
		buttons[id].pressed.connect(_check.bind(id, str(check.answer), buttons, v))
	Speech.new_question()
	Speech.say(str(check.prompt), _lang)


func _check(id: String, right: String, buttons: Dictionary, v: Control) -> void:
	for b in buttons.values():
		b.disabled = true
	buttons[right].card_style = false
	buttons[right].face_color = Palette.RIGHT
	if id != right:
		buttons[id].card_style = false
		buttons[id].face_color = Palette.ALMOST
	Sfx.play("correct" if id == right else "wrong")
	await get_tree().create_timer(1.4).timeout
	if is_inside_tree():
		v.get_meta("overlay").queue_free()
		_reward(id == right)


func _reward(check_right: bool) -> void:
	var seconds := (Time.get_ticks_msec() - _started) / 1000.0
	var result := GameState.finish_media(str(_item.get("id", "")), check_right, seconds)
	Kit.reward(self, GameState.talk("reward_show"), result, _back)


func _back() -> void:
	_paused = true
	if is_instance_valid(_text):
		_text.stop()
	Speech.stop()
	get_tree().change_scene_to_file("res://scenes/watch/watch.tscn")
