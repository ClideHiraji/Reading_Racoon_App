class_name Balloon
extends Button
## A paper balloon with a picture and a word, for Rhyme Pop (D-017). Drawn in
## Godot (no image files); a flat Button so a tap anywhere on it counts.

var color := Palette.BLUE:
	set(v):
		color = v
		queue_redraw()
var word := ""
var picture := ""


func _ready() -> void:
	flat = true
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	custom_minimum_size = Vector2(170, 250)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.position = Vector2(0, 16)
	v.size = Vector2(170, 160)
	add_child(v)
	if picture != "":
		var r := Icons.rect(picture, 72, Palette.text_on(color))
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(r)
	var l := Kit.word_label(word, 34)
	l.add_theme_color_override("font_color", Palette.text_on(color))
	v.add_child(l)


func _draw() -> void:
	var c := Vector2(85, 96)
	var r := Vector2(80, 92)
	var shadow := _oval(c + Vector2(0, 6), r)
	draw_colored_polygon(shadow, Palette.SHADOW)
	draw_colored_polygon(_oval(c, r), color)
	draw_colored_polygon(_oval(c + Vector2(-30, -42), Vector2(14, 22)), Color(1, 1, 1, 0.35))
	var knot := PackedVector2Array([c + Vector2(-10, r.y + 10), c + Vector2(10, r.y + 10), c + Vector2(0, r.y - 4)])
	draw_colored_polygon(knot, color.darkened(0.15))
	var pts := PackedVector2Array()
	for i in 12:
		var t := i / 11.0
		pts.append(c + Vector2(sin(t * PI * 3.0) * 8.0, r.y + 10 + t * 50))
	draw_polyline(pts, Palette.INK_SOFT, 3.0, true)


func _oval(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
