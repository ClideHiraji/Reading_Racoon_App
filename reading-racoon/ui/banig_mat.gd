@tool
class_name BanigMat
extends Control
## A round woven banig mat for Racoon to stand on in the hub (D-015): a paper
## oval with colored rings, like the patterned sleeping mats of Mindanao.

@export var rings := PackedColorArray([Palette.ORANGE, Palette.BLUE, Palette.YELLOW]):
	set(v):
		rings = v
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var c := size / 2.0
	var r := size / 2.0
	_oval(c + Vector2(0, 8), r, Palette.NIPA)
	_oval(c, r - Vector2(4, 4), Palette.SAND)
	for i in rings.size():
		var k := 0.8 - 0.25 * i
		_ring(c, r * k, rings[i], 5.0)


func _oval(c: Vector2, r: Vector2, col: Color) -> void:
	draw_colored_polygon(_pts(c, r), col)


func _ring(c: Vector2, r: Vector2, col: Color, width: float) -> void:
	var pts := _pts(c, r)
	pts.append(pts[0])
	draw_polyline(pts, col, width, true)


func _pts(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
