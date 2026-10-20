@tool
class_name PaperScenery
extends Control
## Layered paper-cut landscapes for the five Butuan worlds (D-009), drawn with
## Godot's 2D drawing API. Each layer casts a soft shadow on the one behind it.
## Scenes: river (Agusan River), grove (Mango Grove), village (Bahay Kubo
## Village), bay (Balangay Bay), mountain (Mount Mayapay), home (start screen).

@export_enum("river", "grove", "village", "bay", "mountain", "home") var scene := "river":
	set(v):
		scene = v
		queue_redraw()
## 0 = full color, 1 = fully faded into the paper (locked worlds).
@export_range(0.0, 1.0) var fade := 0.0:
	set(v):
		fade = v
		queue_redraw()
@export var show_sky := true:
	set(v):
		show_sky = v
		queue_redraw()

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	resized.connect(queue_redraw)


func _c(col: Color) -> Color:
	return col.lerp(Palette.PAPER_DEEP, fade * 0.8)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2 or h < 2:
		return
	_rng.seed = hash(scene)
	if show_sky:
		draw_rect(Rect2(0, 0, w, h), _c(Palette.SKY))
		_sun(Vector2(w * 0.82, h * 0.26), h * 0.13)
		_cloud(Vector2(w * 0.18, h * 0.2), h * 0.08)
		_cloud(Vector2(w * 0.55, h * 0.12), h * 0.06)
	match scene:
		"river":
			_hills(h * 0.48, h * 0.08, 1.3, _c(Palette.LEAF.lightened(0.35)))
			_trees(h * 0.5, 7, h * 0.09, 0.0)
			_hills(h * 0.62, h * 0.05, 2.1, _c(Palette.LEAF))
			_water(h * 0.72, _c(Palette.TEAL))
			_reeds(h * 0.72, 9)
		"grove":
			_hills(h * 0.5, h * 0.07, 1.1, _c(Palette.LEAF.lightened(0.3)))
			_trees(h * 0.56, 5, h * 0.16, 1.0)
			_hills(h * 0.74, h * 0.05, 1.7, _c(Palette.LEAF_DEEP.lightened(0.1)))
			_trees(h * 0.8, 3, h * 0.12, 1.0)
		"village":
			_hills(h * 0.52, h * 0.07, 1.4, _c(Palette.LEAF.lightened(0.3)))
			_trees(h * 0.55, 4, h * 0.1, 0.0)
			_hills(h * 0.7, h * 0.03, 1.0, _c(Palette.SAND))
			_huts(h * 0.74, 3, h * 0.22)
			_hills(h * 0.88, h * 0.02, 2.0, _c(Palette.LEAF))
		"bay":
			_hills(h * 0.5, h * 0.1, 0.9, _c(Palette.LEAF.lightened(0.25)))
			_water(h * 0.58, _c(Palette.BAY))
			_boat(Vector2(w * 0.36, h * 0.7), h * 0.2)
			_boat(Vector2(w * 0.74, h * 0.64), h * 0.12)
			_hills(h * 0.9, h * 0.03, 1.5, _c(Palette.SAND))
		"mountain":
			_peaks(h * 0.72, h * 0.5, _c(Palette.PLUM.lightened(0.3)), 3)
			_peaks(h * 0.8, h * 0.4, _c(Palette.PLUM), 2)
			_hills(h * 0.82, h * 0.04, 1.8, _c(Palette.LEAF_DEEP))
			_trees(h * 0.86, 6, h * 0.08, 0.0)
		"home":
			_hills(h * 0.5, h * 0.08, 1.2, _c(Palette.LEAF.lightened(0.35)))
			_trees(h * 0.52, 5, h * 0.08, 1.0)
			_hills(h * 0.62, h * 0.04, 1.9, _c(Palette.LEAF))
			_huts(h * 0.64, 1, h * 0.2, 0.8)
			_water(h * 0.78, _c(Palette.TEAL))
			_reeds(h * 0.78, 7)


# --- Layers ------------------------------------------------------------------------

## A paper layer: shadow nudged upward onto the layer behind, then the layer.
func _layer(pts: PackedVector2Array, col: Color) -> void:
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, -6))
	draw_colored_polygon(shadow, Color(Palette.SHADOW, Palette.SHADOW.a * (1.0 - fade * 0.7)))
	draw_colored_polygon(pts, col)


func _hills(top: float, amp: float, freq: float, col: Color) -> void:
	var w := size.x
	var phase := _rng.randf() * TAU
	var pts := PackedVector2Array()
	var steps := 48
	for i in steps + 1:
		var x := w * i / steps
		var y := top - sin(x / w * TAU * freq + phase) * amp - sin(x / w * TAU * freq * 2.3) * amp * 0.3
		pts.append(Vector2(x, y))
	pts.append(Vector2(w, size.y))
	pts.append(Vector2(0, size.y))
	_layer(pts, col)


func _water(top: float, col: Color) -> void:
	var w := size.x
	var pts := PackedVector2Array()
	for i in 41:
		var x := w * i / 40.0
		pts.append(Vector2(x, top + sin(x / w * TAU * 1.5) * 6))
	pts.append(Vector2(w, size.y))
	pts.append(Vector2(0, size.y))
	_layer(pts, col)
	# Light wave strokes on the water.
	var light := col.lightened(0.35)
	for r in 3:
		var y := top + (size.y - top) * (0.3 + r * 0.22)
		for k in 4:
			var x0 := w * (0.08 + k * 0.25 + (r % 2) * 0.1)
			draw_arc(Vector2(x0, y), 14, PI * 1.15, PI * 1.85, 8, light, 3.0, true)
			draw_arc(Vector2(x0 + 26, y), 14, PI * 1.15, PI * 1.85, 8, light, 3.0, true)


func _trees(base: float, count: int, crown: float, mango: float) -> void:
	var w := size.x
	for i in count:
		var x := w * (i + 0.5) / count + _rng.randf_range(-0.06, 0.06) * w
		var y := base + _rng.randf_range(-0.02, 0.03) * size.y
		var r := crown * _rng.randf_range(0.8, 1.15)
		draw_rect(Rect2(x - r * 0.12, y - r * 0.4, r * 0.24, r * 0.9), _c(Palette.NIPA_DEEP))
		var leaf := _c(Palette.LEAF_DEEP if i % 2 == 0 else Palette.LEAF.darkened(0.08))
		draw_circle(Vector2(x, y - r * 0.6 - 5), r, Color(Palette.SHADOW, 0.18))
		draw_circle(Vector2(x, y - r * 0.6), r, leaf)
		draw_circle(Vector2(x - r * 0.35, y - r * 0.85), r * 0.45, leaf.lightened(0.12))
		if _rng.randf() < mango:
			for m in 3:
				var a := _rng.randf() * TAU
				draw_circle(Vector2(x, y - r * 0.6) + Vector2(cos(a), sin(a)) * r * 0.55,
						r * 0.14, _c(Palette.MANGO))


func _reeds(base: float, count: int) -> void:
	var w := size.x
	for i in count:
		var x := w * (i + 0.3) / count + _rng.randf_range(-12, 12)
		var hh := _rng.randf_range(18, 34)
		draw_line(Vector2(x, base + 4), Vector2(x - 4, base - hh), _c(Palette.LEAF_DEEP), 4.0, true)
		draw_line(Vector2(x + 6, base + 4), Vector2(x + 9, base - hh * 0.7), _c(Palette.LEAF), 4.0, true)


## Bahay kubo: a stilt hut with a steep thatched roof.
func _huts(base: float, count: int, hut: float, at_x: float = -1.0) -> void:
	var w := size.x
	for i in count:
		var x := w * (i + 0.5) / count + _rng.randf_range(-0.05, 0.05) * w
		if at_x >= 0.0:
			x = w * at_x
		var s := hut * _rng.randf_range(0.85, 1.1)
		var body := Rect2(x - s * 0.45, base - s * 0.55, s * 0.9, s * 0.45)
		for k in 3:
			draw_rect(Rect2(body.position.x + s * (0.06 + k * 0.36), base - s * 0.12, s * 0.07, s * 0.2),
					_c(Palette.NIPA_DEEP))
		draw_rect(Rect2(body.position + Vector2(0, -5), body.size), Color(Palette.SHADOW, 0.2))
		draw_rect(body, _c(Palette.SAND))
		for k in 5:
			var lx := body.position.x + body.size.x * (k + 0.5) / 5
			draw_line(Vector2(lx, body.position.y), Vector2(lx, body.end.y), _c(Palette.NIPA), 2.0)
		draw_rect(Rect2(x - s * 0.1, base - s * 0.4, s * 0.2, s * 0.3), _c(Palette.NIPA_DEEP))
		var roof := PackedVector2Array([Vector2(x - s * 0.62, base - s * 0.5),
				Vector2(x, base - s * 1.15), Vector2(x + s * 0.62, base - s * 0.5)])
		_layer(roof, _c(Palette.NIPA))
		for k in 4:
			var t := (k + 1) / 5.0
			draw_line(Vector2(x - s * 0.62 * t, base - s * (1.15 - 0.65 * t)),
					Vector2(x + s * 0.62 * t, base - s * (1.15 - 0.65 * t)), _c(Palette.NIPA_DEEP), 2.0)


## Balangay: the long wooden boat of Butuan, with a woven sail.
func _boat(at: Vector2, s: float) -> void:
	var hull := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		hull.append(at + Vector2((t - 0.5) * s * 2.2, sin(t * PI) * s * 0.32 - s * 0.05 * (1.0 - absf(t - 0.5) * 2)))
	hull.append(at + Vector2(s * 1.25, -s * 0.18))
	hull.append(at + Vector2(-s * 1.25, -s * 0.18))
	_layer(hull, _c(Palette.NIPA_DEEP))
	draw_line(at + Vector2(0, -s * 0.1), at + Vector2(0, -s * 1.2), _c(Palette.INK), 3.0)
	var sail := PackedVector2Array([at + Vector2(-s * 0.05, -s * 1.15), at + Vector2(s * 0.75, -s * 0.3),
			at + Vector2(-s * 0.05, -s * 0.25)])
	_layer(sail, _c(Palette.CARD))
	draw_line(at + Vector2(0.1 * s, -s * 0.85), at + Vector2(0.45 * s, -s * 0.35), _c(Palette.CORAL), 3.0)


func _peaks(base: float, height: float, col: Color, count: int) -> void:
	var w := size.x
	for i in count:
		var cx := w * (i + 0.5) / count + _rng.randf_range(-0.08, 0.08) * w
		var hw := w / count * _rng.randf_range(0.6, 0.85)
		var hh := height * _rng.randf_range(0.8, 1.0)
		var pts := PackedVector2Array([Vector2(cx - hw, base), Vector2(cx - hw * 0.12, base - hh),
				Vector2(cx + hw * 0.12, base - hh), Vector2(cx + hw, base)])
		_layer(pts, col)
		var cap := PackedVector2Array([Vector2(cx - hw * 0.26, base - hh * 0.72),
				Vector2(cx - hw * 0.12, base - hh), Vector2(cx + hw * 0.12, base - hh),
				Vector2(cx + hw * 0.26, base - hh * 0.72), Vector2(cx, base - hh * 0.8)])
		draw_colored_polygon(cap, col.lightened(0.25))


func _sun(at: Vector2, r: float) -> void:
	draw_circle(at, r * 1.45, _c(Palette.MANGO.lightened(0.6)))
	draw_circle(at, r, _c(Palette.MANGO.lightened(0.15)))


func _cloud(at: Vector2, r: float) -> void:
	var col := _c(Palette.CARD)
	for pass_i in 2:
		var off := Vector2(0, 5) if pass_i == 0 else Vector2.ZERO
		var c := Color(Palette.SHADOW, 0.14) if pass_i == 0 else col
		draw_circle(at + off + Vector2(-r * 1.1, r * 0.2), r * 0.75, c)
		draw_circle(at + off, r, c)
		draw_circle(at + off + Vector2(r * 1.05, r * 0.25), r * 0.7, c)
		draw_rect(Rect2(at + off + Vector2(-r * 1.1, r * 0.2), Vector2(r * 2.15, r * 0.75)), c)
