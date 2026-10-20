@tool
class_name Sunburst
extends Control
## Slowly turning paper rays behind a celebration (D-009).

@export var color := Color(Palette.MANGO, 0.22)
@export var rays := 16
@export var speed := 0.12

var _angle := 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_angle += delta * speed
	queue_redraw()


func _draw() -> void:
	var c := size / 2
	var r := size.length()
	for i in rays:
		var a := _angle + TAU * i / rays
		var w := TAU / rays * 0.32
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a - w), sin(a - w)) * r,
				c + Vector2(cos(a + w), sin(a + w)) * r]), color)
	draw_circle(c, minf(size.x, size.y) * 0.32, Color(Palette.MANGO, 0.18))
