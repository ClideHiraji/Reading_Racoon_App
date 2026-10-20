class_name BackspaceIcon
extends Control
## A drawn "delete" key symbol: a left-pointing tag with an X (no emoji or glyph font).

var color := Palette.INK


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2
	var w := minf(size.x, 64.0)
	var h := w * 0.62
	var l := c.x - w / 2
	var pts := PackedVector2Array([Vector2(l, c.y), Vector2(l + w * 0.3, c.y - h / 2),
			Vector2(l + w, c.y - h / 2), Vector2(l + w, c.y + h / 2), Vector2(l + w * 0.3, c.y + h / 2)])
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, color, 4.0, true)
	var x := Vector2(l + w * 0.62, c.y)
	var d := h * 0.2
	draw_line(x + Vector2(-d, -d), x + Vector2(d, d), color, 4.0, true)
	draw_line(x + Vector2(-d, d), x + Vector2(d, -d), color, 4.0, true)
