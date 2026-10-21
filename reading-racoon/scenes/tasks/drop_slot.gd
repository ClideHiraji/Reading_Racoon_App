class_name DropSlot
extends Control
## An empty place for a letter, syllable, word or story event: a dashed paper
## outline that fills with a paper tile. Accepts a dragged LetterTile.

signal dropped(letter: String)

const ANDIKA := preload("res://assets/fonts/Andika-Bold.ttf")

var _label: Label
var _color := Palette.MANGO_DEEP
var _filled := false
var _base_size := Vector2.ZERO
var _hint := "?"


func _init() -> void:
	custom_minimum_size = Vector2(124, 140)
	_label = Label.new()
	_label.theme_type_variation = &"ReadWord"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 12
	_label.offset_right = -12
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = "?"
	_label.add_theme_color_override("font_color", Color(Palette.MANGO_DEEP, 0.4))
	add_child(_label)


## Faint text shown while empty ("?" for letters, a number for story events).
func set_hint(text: String) -> void:
	_hint = text
	_label.text = text
	_label.add_theme_font_size_override("font_size", 44)


func _draw() -> void:
	var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	if _filled:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Palette.pale(_color, 0.75)
		sb.set_corner_radius_all(20)
		sb.shadow_color = Color(Palette.SHADOW, 0.16)
		sb.shadow_offset = Vector2(0, 6)
		sb.shadow_size = 1
		draw_style_box(sb, r)
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(Palette.MANGO, 0.12)
	bg.set_corner_radius_all(20)
	draw_style_box(bg, r)
	# Dashed outline: short segments along each side, solid arcs on the corners.
	var dash := 14.0
	var gap := 10.0
	var col := Color(_color, 0.8)
	var ends := [
		[r.position + Vector2(20, 0), Vector2(r.end.x - 20, r.position.y)],
		[Vector2(r.end.x, r.position.y + 20), Vector2(r.end.x, r.end.y - 20)],
		[Vector2(r.end.x - 20, r.end.y), Vector2(r.position.x + 20, r.end.y)],
		[Vector2(r.position.x, r.end.y - 20), r.position + Vector2(0, 20)],
	]
	for e in ends:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var length := a.distance_to(b)
		if length < 1.0:
			continue
		var dir := (b - a) / length
		var t := 0.0
		while t < length:
			draw_line(a + dir * t, a + dir * minf(t + dash, length), col, 4.0, true)
			t += dash + gap
	var corners := [r.position + Vector2(20, 20), Vector2(r.end.x - 20, r.position.y + 20),
			r.end - Vector2(20, 20), Vector2(r.position.x + 20, r.end.y - 20)]
	for i in 4:
		var start := PI + i * PI / 2
		draw_arc(corners[i], 20, start + 0.35, start + PI / 2 - 0.35, 6, col, 4.0, true)


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("letter")


func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.emit(data.letter)


func show_letter(letter: String) -> void:
	_label.text = letter
	_label.add_theme_color_override("font_color", Palette.INK)
	_filled = true
	queue_redraw()


## Fills the slot with a tile's text, sized for syllables, words or sentences.
func show_tile(text: String, variant: String) -> void:
	if _base_size == Vector2.ZERO:
		_base_size = custom_minimum_size
	var fs: int = {"syllables": 64, "sentence": 44}.get(variant, 30)
	_label.text = text
	_label.add_theme_font_override("font", ANDIKA)
	_label.add_theme_font_size_override("font_size", fs)
	if variant != "sequence":
		var w := ANDIKA.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 44
		custom_minimum_size.x = maxf(_base_size.x, w)
	_label.add_theme_color_override("font_color", Palette.INK)
	_filled = true
	queue_redraw()


func clear() -> void:
	if _base_size != Vector2.ZERO:
		custom_minimum_size = _base_size
	_label.text = _hint
	_label.add_theme_color_override("font_color", Color(Palette.MANGO_DEEP, 0.4))
	_filled = false
	_color = Palette.MANGO_DEEP
	queue_redraw()


func set_color(c: Color) -> void:
	_color = c
	_label.add_theme_color_override("font_color", c.darkened(0.35))
	queue_redraw()
