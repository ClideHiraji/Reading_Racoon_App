extends Control
## The Watch & Listen player (D-017, wireframe "Video player"). Songs, chants and
## read-alongs play line by line: the scene and pictures on the stage, the words
## lighting up as Racoon sings them. Teacher videos (Ogg Theora, downloaded on
## Wi-Fi) play in the same frame. Then a quick check with two pictures, and no
## autoplay of anything else. The stage sits on the words card, and the controls
## are listening blue: a round Again and a big Pause (D-022).

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


func _ready() -> void:
	if not GameState.guard_free_play():
		return
	_started = Time.get_ticks_msec()
	_item = GameState.media.media(GameState.open_media)
	_lines = GameState.media.lines_of(_item)
	_lang = str(_item.get("language", "en"))
	var column := Kit.page(self)
	Kit.header(column, str(_item.get("title", "Watch")), _back, true)
	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", 0)
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(sheet)
	_stage = PanelContainer.new()
	var stage_box := Kit.box(Palette.SKY, 28)
	stage_box.corner_radius_bottom_left = 0
	stage_box.corner_radius_bottom_right = 0
	_stage.add_theme_stylebox_override("panel", stage_box)
	_stage.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_stage.custom_minimum_size = Vector2(0, 430)
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
	var card_box: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	card_box.corner_radius_top_left = 0
	card_box.corner_radius_top_right = 0
	card.add_theme_stylebox_override("panel", card_box)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	if _video:
		_video.paused = _paused
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
	_stage.add_child(_video)
	_video.play()


func _process(_delta: float) -> void:
	if _video and _video.is_playing():
		var length := _video.get_stream_length()
		if length > 0.0:
			_bar.value = _video.stream_position / length


# --- The end: a quick check, then the reward --------------------------------------------

func _end() -> void:
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
	Kit.reward(self, "What a show!", result, _back)


func _back() -> void:
	_paused = true
	if is_instance_valid(_text):
		_text.stop()
	Speech.stop()
	get_tree().change_scene_to_file("res://scenes/watch/watch.tscn")
