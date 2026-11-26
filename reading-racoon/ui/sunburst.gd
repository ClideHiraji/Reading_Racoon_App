@tool
class_name Sunburst
extends Control
## Slowly turning paper rays behind a celebration. The rays are drawn once onto a
## layer that turns, so they aren't redrawn every frame.

@export var color := Color(Palette.MANGO, 0.22)
@export var rays := 16
@export var speed := 0.12

var _rays := Node2D.new()


func _init() -> void:
	add_child(_rays, false, INTERNAL_MODE_FRONT)
	_rays.draw.connect(_draw_rays)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_rays.rotation += delta * speed


func _layout() -> void:
	_rays.position = size / 2
	_rays.queue_redraw()


## Around the layer's origin, the burst's center.
func _draw_rays() -> void:
	var r := size.length()
	for i in rays:
		var a := TAU * i / rays
		var w := TAU / rays * 0.32
		_rays.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(cos(a - w), sin(a - w)) * r,
				Vector2(cos(a + w), sin(a + w)) * r]), color)
	_rays.draw_circle(Vector2.ZERO, minf(size.x, size.y) * 0.32, Color(Palette.MANGO, 0.18))
