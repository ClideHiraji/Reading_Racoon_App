class_name DropSlot
extends Control
## The gap in a word: a dashed paper outline that accepts a dragged LetterTile.

signal dropped(letter: String)

var _label: Label
var _color := Palette.MANGO_DEEP
var _filled := false


func _init() -> void:
	custom_minimum_size = Vector2(124, 140)
	_label = Label.new()
	_label.theme_type_variation = &"ReadWord"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.text = "?"
	_label.add_theme_color_override("font_color", Color(Palette.MANGO_DEEP, 0.4))
	add_child(_label)


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
	# Dashed outline: short segments around the rounded rectangle's sides.
	var dash := 14.0
	var gap := 10.0
	var col := Color(_color, 0.8)
	for side in 4:
		var a: Vector2 = [r.position + Vector2(20, 0), r.end - Vector2(0, r.size.y - 20),
				r.end - Vector2(20, 0), r.position + Vector2(0, r.size.y - 20)][side]
		var b: Vector2 = [Vector2(r.end.x - 20, r.position.y), Vector2(r.end.x, r.end.y - 20),
				Vector2(r.position.x + 20, r.end.y), r.position + Vector2(0, 20)][side]
		var len := a.distance_to(b)
		var dir := (b - a) / len
		var t := 0.0
		while t < len:
			draw_line(a + dir * t, a + dir * minf(t + dash, len), col, 4.0, true)
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


func set_color(c: Color) -> void:
	_color = c
	_label.add_theme_color_override("font_color", c.darkened(0.35))
	queue_redraw()
