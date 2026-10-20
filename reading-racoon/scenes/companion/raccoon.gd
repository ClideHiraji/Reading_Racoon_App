@tool
class_name Raccoon
extends Control
## Placeholder raccoon companion drawn from shapes, with mood poses (D-007, FR-14).
## Swap for real 2D art later; keep the set_mood() API.
## Moods: idle, happy, thinking, encourage, celebrate, sleepy.

const FUR := Color("9a9aa8")
const FUR_DARK := Color("6e6e7c")
const MASK := Color("2e2e38")
const LIGHT := Color("f4f1ea")
const BLUSH := Color(1.0, 0.55, 0.6, 0.35)

@export var mood := "idle":
	set(v):
		mood = v
		queue_redraw()

## Animated offsets, applied in _draw so containers never fight the tweens.
var hop := 0.0:
	set(v):
		hop = v
		queue_redraw()
var tilt := 0.0:
	set(v):
		tilt = v
		queue_redraw()
var squash := 1.0:
	set(v):
		squash = v
		queue_redraw()

var _tween: Tween
var _idle: Tween


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(180, 180)
	if not Engine.is_editor_hint():
		_breathe()


func set_mood(m: String) -> void:
	mood = m
	if _tween:
		_tween.kill()
	_tween = create_tween()
	match m:
		"happy":
			_tween.tween_property(self, "hop", -22.0, 0.12).set_trans(Tween.TRANS_QUAD)
			_tween.tween_property(self, "hop", 0.0, 0.18).set_trans(Tween.TRANS_BOUNCE)
		"celebrate":
			for i in 2:
				_tween.tween_property(self, "hop", -40.0, 0.16).set_trans(Tween.TRANS_QUAD)
				_tween.parallel().tween_property(self, "tilt", 0.15 * (1 - 2 * (i % 2)), 0.16)
				_tween.tween_property(self, "hop", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE)
			_tween.tween_property(self, "tilt", 0.0, 0.1)
		"thinking":
			_tween.tween_property(self, "tilt", -0.14, 0.25).set_trans(Tween.TRANS_SINE)
			_tween.tween_interval(0.8)
			_tween.tween_property(self, "tilt", 0.0, 0.25)
		"encourage":
			for i in 2:
				_tween.tween_property(self, "squash", 0.94, 0.12)
				_tween.tween_property(self, "squash", 1.0, 0.12)
		_:
			_tween.tween_property(self, "hop", 0.0, 0.1)


func _breathe() -> void:
	_idle = create_tween().set_loops()
	_idle.tween_property(self, "squash", 1.025, 1.2).set_trans(Tween.TRANS_SINE)
	_idle.tween_property(self, "squash", 1.0, 1.2).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	var k := minf(size.x, size.y) / 200.0
	var base := Vector2(size.x / 2.0, size.y)
	# Squash around the feet, hop up, tilt around the feet.
	draw_set_transform(base + Vector2(0, hop * k), tilt, Vector2(1.0 / squash, squash) * k)
	# Coordinates below are in a 200x200 box with the feet at (0, 0).
	_tail()
	_ellipse(Vector2(0, -38), Vector2(56, 40), FUR)                 # body
	_ellipse(Vector2(0, -32), Vector2(34, 28), LIGHT)               # belly
	_ellipse(Vector2(-60, -122), Vector2(22, 24), FUR_DARK)         # ears
	_ellipse(Vector2(60, -122), Vector2(22, 24), FUR_DARK)
	_ellipse(Vector2(-60, -120), Vector2(11, 12), Color("d9a3a8"))
	_ellipse(Vector2(60, -120), Vector2(11, 12), Color("d9a3a8"))
	_ellipse(Vector2(0, -102), Vector2(74, 60), FUR)                # head
	_ellipse(Vector2(-30, -126), Vector2(22, 9), LIGHT)             # brows
	_ellipse(Vector2(30, -126), Vector2(22, 9), LIGHT)
	_ellipse(Vector2(-30, -104), Vector2(31, 19), MASK)             # mask
	_ellipse(Vector2(30, -104), Vector2(31, 19), MASK)
	draw_rect(Rect2(-12, -112, 24, 14), MASK)
	_ellipse(Vector2(0, -76), Vector2(40, 26), LIGHT)               # muzzle
	_ellipse(Vector2(-46, -80), Vector2(9, 7), BLUSH)               # blush
	_ellipse(Vector2(46, -80), Vector2(9, 7), BLUSH)
	_eyes()
	_ellipse(Vector2(0, -88), Vector2(10, 7), MASK)                 # nose
	_mouth()


func _tail() -> void:
	var pts := [Vector2(52, -30), Vector2(70, -48), Vector2(82, -70), Vector2(88, -94),
			Vector2(88, -116)]
	for i in pts.size():
		_ellipse(pts[i], Vector2(17, 17) * (1.0 - i * 0.06), MASK if i % 2 == 1 else FUR)


func _eyes() -> void:
	for side in [-1, 1]:
		var c := Vector2(30 * side, -104)
		if mood in ["happy", "celebrate"]:
			draw_arc(c + Vector2(0, 4), 9, PI + 0.3, TAU - 0.3, 12, Color.WHITE, 4.0, true)
		elif mood == "sleepy":
			draw_line(c + Vector2(-8, 2), c + Vector2(8, 2), Color.WHITE, 3.0, true)
		else:
			var look := Vector2(3 * side, -5) if mood == "thinking" else Vector2(0, 0)
			draw_circle(c, 11, Color.WHITE)
			draw_circle(c + look, 7, Color("1b1b22"))
			draw_circle(c + look + Vector2(-2.5, -2.5), 2.5, Color.WHITE)


func _mouth() -> void:
	var c := Vector2(0, -74)
	match mood:
		"celebrate":
			_ellipse(c + Vector2(0, 4), Vector2(12, 10), Color("5a2a2a"))
			_ellipse(c + Vector2(0, 9), Vector2(7, 4), Color("ff8a8a"))
		"thinking":
			draw_circle(c + Vector2(6, 4), 4, Color("5a2a2a"))
		"encourage":
			draw_arc(c, 10, 0.4, PI - 0.4, 12, MASK, 3.0, true)
		_:
			draw_arc(c + Vector2(-7, 0), 7, 0.2, PI - 0.2, 10, MASK, 3.0, true)
			draw_arc(c + Vector2(7, 0), 7, 0.2, PI - 0.2, 10, MASK, 3.0, true)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
