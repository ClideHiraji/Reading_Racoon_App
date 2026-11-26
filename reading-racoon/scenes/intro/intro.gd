class_name Intro
extends CanvasLayer
## The opening (D-037): instead of Godot's logo, the game opens on a sheet of paper where a sunburst
## turns, Racoon pops up and waves, and "Reading Racoon" drops in letter by letter over a crayon
## squiggle. Then the sheet lifts away like a page, hand-cut bottom edge and all (D-028), and shows
## the start screen that was ready underneath. About 3.3 s; a tap or key skips straight to the lift.
## Once per launch: the start screen adds it the first time it opens (scenes/main.gd).
## Text is large and nothing needs reading (NFR-02); the start screen speaks after it, not over it.

signal finished

const BURST_AT := 0.10
const RACOON_AT := 0.20
const LETTERS_AT := 0.80
const LETTER_STEP := 0.05
const LETTER_TIME := 0.32
const LIFT_AT := 2.75
const LIFT_TIME := 0.55
const SKIP_AFTER := 0.35   # a tap this early is the child's launch tap, not a skip
const EDGE := 26.0         # how far the hand-cut edge and its shadow hang below the sheet

## Played already in this run of the game (it opens once per launch).
static var played := false

var _sheet := Control.new()
var _paper := ColorRect.new()
var _raccoon := Raccoon.new()
var _burst := Sunburst.new()
var _letters: Array[Label] = []
var _underline := _Underline.new()
var _tween: Tween
var _started_ms := 0
var _lifting := false


## Whether the opening plays: once per launch, and not when a test or debug run asks it not to
## (--no-intro, or a --profile / --scene / --shot run).
static func should_play(args: Dictionary) -> bool:
	for k in ["no-intro", "profile", "scene", "shot"]:
		if args.has(k):
			return false
	return not played


func _ready() -> void:
	played = true
	layer = 50
	_started_ms = Time.get_ticks_msec()
	_build()
	await get_tree().process_frame   # sizes are known after the first layout
	_prepare()
	_play()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # the start screen waits underneath
	root.gui_input.connect(_on_input)
	add_child(root)
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_sheet)
	var edge := _Edge.new()   # first, so the paper covers its top
	edge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	edge.offset_top = -4
	edge.offset_bottom = EDGE
	_sheet.add_child(edge)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://ui/paper.gdshader")
	mat.set_shader_parameter("vignette", 0.0)   # an even sheet, so its cut edge shows no seam
	_paper.material = mat
	_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.clip_contents = true   # the burst's rays stop at the paper, not on the start screen
	_sheet.add_child(_paper)
	_set_paper(_boot_color())   # the same cream as the boot screen: no flash

	var land := Kit.landscape()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	var px := 250.0 if land else 340.0
	var stage := Control.new()   # the burst spills past Racoon; the stage only holds his place
	stage.custom_minimum_size = Vector2(px, px)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stage)
	var burst_px := px * 2.2
	_burst.size = Vector2(burst_px, burst_px)
	_burst.position = Vector2(px - burst_px, px - burst_px) / 2.0
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_burst)
	_raccoon.size = Vector2(px, px)
	_raccoon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_raccoon)   # his puppet is built in his _ready, so the mood comes after
	_raccoon.set_mood("happy")

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12 if land else 28)
	col.add_child(gap)
	# The start screen's own title: "Reading" in ink, "Racoon" in the river's orange.
	col.add_child(_word("Reading", 80 if land else 92, Palette.INK))
	col.add_child(_word("Racoon", 92 if land else 108, Color(0.741, 0.384, 0.071)))
	_underline.custom_minimum_size = Vector2(0, 18)
	_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_underline)


## A word as a row of letters, each in a holder so a container can't reset its tween.
func _word(text: String, fs: int, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in text:
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(holder)
		var l := Label.new()
		l.text = ch
		l.theme_type_variation = &"TitleLabel"
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", color)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(l)
		_letters.append(l)
	return row


## Starting poses, once the layout has given everything its size.
func _prepare() -> void:
	for l in _letters:
		var holder := l.get_parent() as Control
		holder.custom_minimum_size = l.get_minimum_size()
		l.pivot_offset = l.get_minimum_size() / 2.0
		l.position = Vector2(0, -70)
		l.scale = Vector2(0.4, 0.4)
		l.modulate.a = 0.0
	var w := 0.0   # the squiggle runs under "Racoon", its last six letters
	for l in _letters.slice(_letters.size() - 6):
		w += l.get_minimum_size().x
	_underline.width = w
	_raccoon.pivot_offset = _raccoon.size * Vector2(0.5, 0.85)   # he springs up from his feet
	_raccoon.scale = Vector2(0.15, 0.15)
	_raccoon.modulate.a = 0.0
	_burst.pivot_offset = _burst.size / 2.0
	_burst.scale = Vector2(0.4, 0.4)
	_burst.modulate.a = 0.0


func _play() -> void:
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_paper, _boot_color(), Palette.CREAM, 0.5)
	_tween.tween_property(_burst, "modulate:a", 1.0, 0.5).set_delay(BURST_AT)
	_tween.tween_property(_burst, "scale", Vector2.ONE, 0.6).set_delay(BURST_AT) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_raccoon, "modulate:a", 1.0, 0.18).set_delay(RACOON_AT)
	_tween.tween_property(_raccoon, "scale", Vector2.ONE, 0.55).set_delay(RACOON_AT) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_pop).set_delay(RACOON_AT + 0.25)
	_tween.tween_callback(_raccoon.moment.bind("greet")).set_delay(RACOON_AT + 0.55)
	var t := LETTERS_AT
	for i in _letters.size():
		var l := _letters[i]
		if i == 7:   # a breath between "Reading" and "Racoon"
			t += 0.1
		_tween.tween_property(l, "modulate:a", 1.0, LETTER_TIME * 0.5).set_delay(t)
		_tween.tween_property(l, "position:y", 0.0, LETTER_TIME).set_delay(t) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(l, "scale", Vector2.ONE, LETTER_TIME).set_delay(t) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t += LETTER_STEP
	_tween.tween_property(_underline, "progress", 1.0, 0.4).set_delay(t + 0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_lift).set_delay(LIFT_AT)


## The sheet lifts away like a page and shows the start screen.
func _lift() -> void:
	if _lifting:
		return
	_lifting = true
	if _tween:
		_tween.kill()
	_finish_poses()
	var away := -(_sheet.size.y + EDGE + 20.0)
	var t := create_tween()
	t.tween_property(_sheet, "position:y", away, LIFT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(_done)


## A skip lands everything where it was going, so the lift shows the finished title.
func _finish_poses() -> void:
	_set_paper(Palette.CREAM)
	for n: CanvasItem in [_burst, _raccoon]:
		n.modulate.a = 1.0
	_burst.scale = Vector2.ONE
	_raccoon.scale = Vector2.ONE
	for l in _letters:
		l.modulate.a = 1.0
		l.position = Vector2.ZERO
		l.scale = Vector2.ONE
	_underline.progress = 1.0


func _done() -> void:
	finished.emit()
	queue_free()


func _on_input(event: InputEvent) -> void:
	var press := (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed()
	if press and Time.get_ticks_msec() - _started_ms >= SKIP_AFTER * 1000.0:
		_lift()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and Time.get_ticks_msec() - _started_ms >= SKIP_AFTER * 1000.0:
		get_viewport().set_input_as_handled()
		_lift()


## A soft pop as Racoon lands (looked up, so the script also loads where there are no autoloads).
func _pop() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("pop")


func _set_paper(c: Color) -> void:
	(_paper.material as ShaderMaterial).set_shader_parameter("paper", c)


static func _boot_color() -> Color:
	return ProjectSettings.get_setting("application/boot_splash/bg_color", Palette.CREAM)


## The crayon squiggle under "Racoon" (like Squiggle, D-028), drawn in from left to right.
class _Underline:
	extends Control
	var width := 0.0:
		set(v):
			width = v
			queue_redraw()
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _draw() -> void:
		var w := maxf(width - 16.0, 0.0)
		if w <= 0.0 or progress <= 0.0:
			return
		var x0 := (size.x - w) / 2.0
		var pts := PackedVector2Array()
		var n := maxi(8, int(w / 6.0))
		for i in int(n * progress) + 1:
			var t := float(i) / n
			pts.append(Vector2(x0 + t * w, size.y / 2.0 + sin(t * w / 15.0 * PI) * 2.6))
		if pts.size() > 1:
			draw_polyline(pts, Palette.YELLOW, 6.0, true)


## The sheet's hand-cut bottom edge and its soft shadow, seen as the sheet lifts (D-028).
class _Edge:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 37   # the same cut every time
		var top := 0.0
		var cut := PackedVector2Array([Vector2(0, top)])
		var x := 0.0
		while x < size.x:
			cut.append(Vector2(x, 10.0 + rng.randf_range(-5.0, 7.0)))
			x += rng.randf_range(14.0, 26.0)
		cut.append(Vector2(size.x, 10.0 + rng.randf_range(-5.0, 7.0)))
		cut.append(Vector2(size.x, top))
		var shadow := PackedVector2Array()
		for p in cut:
			shadow.append(p + Vector2(0, 9))
		draw_colored_polygon(shadow, Palette.SHADOW)
		draw_colored_polygon(cut, Palette.CREAM)
