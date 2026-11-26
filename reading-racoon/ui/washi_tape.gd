class_name WashiTape
extends Control
## A strip of see-through paper tape, like the tape holding a picture in a scrapbook:
## torn zigzag ends and two thin stripes. Place it over a card's corner.

@export var color := Palette.YELLOW:
	set(v):
		color = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var teeth := 4
	var pts := PackedVector2Array()
	pts.append(Vector2(0, 0))
	pts.append(Vector2(w, 0))
	for i in range(1, teeth * 2 + 1):     # the right end, torn
		pts.append(Vector2(w - (3.0 if i % 2 == 1 else 0.0), h * i / (teeth * 2.0)))
	pts.append(Vector2(0, h))
	for i in range(teeth * 2 - 1, 0, -1):  # the left end, torn
		pts.append(Vector2(3.0 if i % 2 == 1 else 0.0, h * i / (teeth * 2.0)))
	var body := Color(color, 0.62)
	draw_colored_polygon(pts, body)
	var stripe := Color(color.lightened(0.5), 0.7)
	draw_line(Vector2(4, h * 0.3), Vector2(w - 4, h * 0.3), stripe, 2.0, true)
	draw_line(Vector2(4, h * 0.7), Vector2(w - 4, h * 0.7), stripe, 2.0, true)
