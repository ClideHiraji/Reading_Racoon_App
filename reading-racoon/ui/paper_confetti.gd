class_name PaperConfetti
extends Control
## Pale cut-paper bits scattered on a page's paper (D-028): leaves, stars, dots, little rings and
## banig zigzags, in light tints of the game's colours. They sit behind everything, so cards cover
## most of them and they only show in the gaps. Drawn once; nothing moves, so it costs nothing per frame.

const TINTS := [Palette.YELLOW, Palette.ORANGE, Palette.LEAF, Palette.BLUE, Palette.PLUM_LIGHT, Palette.TEAL]
const CELL := 150.0
const CHANCE := 0.55

## Which scatter; each page can have its own.
@export var pattern := 0:
	set(v):
		pattern = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + pattern * 104729
	var cols := ceili(size.x / CELL) + 1
	var rows := ceili(size.y / CELL) + 1
	for row in rows:
		for col in cols:
			var kind := rng.randi_range(0, 5)
			var tint: Color = TINTS[rng.randi_range(0, TINTS.size() - 1)]
			var at := Vector2((col + rng.randf_range(0.15, 0.85)) * CELL, (row + rng.randf_range(0.15, 0.85)) * CELL)
			var px := rng.randf_range(14.0, 26.0)
			var turn := rng.randf_range(-PI, PI)
			if rng.randf() > CHANCE:
				continue
			var c := Palette.pale(tint, 0.5)
			draw_set_transform(at, turn)
			match kind:
				0:
					_leaf(px, c)
				1:
					_star(px, c)
				2:
					draw_circle(Vector2.ZERO, px * 0.32, c, true, -1.0, true)
				3:
					_zigzag(px, c)
				4:
					draw_arc(Vector2.ZERO, px * 0.36, 0.0, TAU, 20, c, 3.0, true)
				_:
					_drop(px, c)
	draw_set_transform(Vector2.ZERO)


func _leaf(px: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		pts.append(Vector2(lerpf(-px * 0.6, px * 0.6, t), -sin(t * PI) * px * 0.32))
	for i in range(11, 0, -1):
		var t := float(i) / 12.0
		pts.append(Vector2(lerpf(-px * 0.6, px * 0.6, t), sin(t * PI) * px * 0.32))
	draw_colored_polygon(pts, c)
	draw_line(Vector2(-px * 0.5, 0), Vector2(px * 0.5, 0), c.darkened(0.12), 1.5, true)


func _star(px: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var r := px * (0.5 if i % 2 == 0 else 0.24)
		pts.append(Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * r)
	draw_colored_polygon(pts, c)


## A short banig zigzag, like the woven mats' stripes.
func _zigzag(px: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(Vector2(-px * 0.7 + i * px * 0.28, (-1 if i % 2 == 0 else 1) * px * 0.16))
	draw_polyline(pts, c, 3.0, true)


func _drop(px: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		var r := px * 0.34 * (1.0 + 0.35 * maxf(0.0, -sin(a)))
		pts.append(Vector2.from_angle(a) * r)
	draw_colored_polygon(pts, c)
