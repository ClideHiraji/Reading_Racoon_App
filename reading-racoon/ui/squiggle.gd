class_name Squiggle
extends Control
## A hand-drawn wavy line under a title, as long as its text, like a child's crayon underline.
## Add it as a child of the Label it underlines.

@export var color := Palette.YELLOW:
	set(v):
		color = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := get_parent() as Label
	if label:
		label.resized.connect(queue_redraw)
		label.draw.connect(queue_redraw)


func _draw() -> void:
	var label := get_parent() as Label
	if label == null or label.text == "":
		return
	var font := label.get_theme_font("font")
	var fs := label.get_theme_font_size("font_size")
	var w := minf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, size.x)
	if w < 24.0:
		return
	var x0 := 0.0
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x0 = (size.x - w) / 2.0
	var y := size.y / 2.0 + fs * 0.62
	var pts := PackedVector2Array()
	var n := maxi(8, int(w / 6.0))
	for i in n + 1:
		var t := float(i) / n
		pts.append(Vector2(x0 + 4.0 + t * (w - 8.0), y + sin(t * w / 15.0 * PI) * 2.6))
	draw_polyline(pts, color, 5.0, true)
