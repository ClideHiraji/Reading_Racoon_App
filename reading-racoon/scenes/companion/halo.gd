@tool
class_name Halo
extends Node2D
## A halo floating behind Racoon's head (D-031): the Star halo, a diamond item in the Closet's hats.
## Drawn in code, in his ink style: a golden ring with four little gems and a ring of beads inside it,
## a star on top, three small stars travelling round it, and a soft glow that breathes. It bobs
## gently and turns with his head: a full ring when he faces you, a thin one side-on, and in front of
## his head when he's turned away. On the Closet's still cards it's drawn once.

const KINDS := ["star_halo"]
const INK := Color("3b2d3a")
const GOLD := Color("f2c94c")
const GOLD_DARK := Color("c99a3a")
const GOLD_LITE := Color("fff1b0")
const R := 126.0             # the ring's radius, in his drawing's units (his head is 216 wide)
const N := 72
const STILL_T := 0.6

var kind := ""
var still := false:
	set(v):
		still = v
		set_process(not v and not Engine.is_editor_hint())

var _t := STILL_T
var _at := Vector2(200.5, 150.0)
var _turn := 1.0


static func has_kind(id: String) -> bool:
	return KINDS.has(id)


func show_kind(id: String, is_still: bool) -> void:
	if id != kind:
		kind = id
		queue_redraw()
	if is_still != still or (is_still and _t != STILL_T):
		still = is_still
		if still:
			_t = STILL_T
		queue_redraw()


## Its middle (in his body's units) and how far his head has turned: cos of his head's turn
## (1 facing you, 0 side-on, -1 turned away).
func place(at: Vector2, turn: float) -> void:
	if at.is_equal_approx(_at) and is_equal_approx(turn, _turn):
		return
	_at = at
	_turn = turn
	if still or not is_processing():
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# --- drawing --------------------------------------------------------------------------------------

## A point on an ellipse round its middle: a circle of radius r, narrowed as his head turns.
func _pt(a: float, r: float) -> Vector2:
	var k := _turn if absf(_turn) >= 0.1 else (0.1 if _turn >= 0.0 else -0.1)
	return _at + Vector2(0, sin(_t * 1.6) * 3.0) + Vector2(cos(a) * r * k, sin(a) * r)


func _ring(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in N + 1:
		pts.append(_pt(TAU * i / N, r))
	return pts


func _draw() -> void:
	if kind == "":
		return
	# the glow: a soft ring of light that breathes
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	var outer := _ring(R)
	for g in [[40.0, 0.06], [26.0, 0.09], [14.0, 0.13]]:
		draw_polyline(outer, Color(1.0, 0.9, 0.5, g[1] * (0.7 + 0.6 * pulse)), g[0], true)
	# beads on a thin inner ring, turning slowly
	var inner := _ring(R * 0.84)
	draw_polyline(inner, Color(GOLD_DARK, 0.85), 2.4, true)
	for i in 16:
		var p := _pt(TAU * i / 16.0 + _t * 0.25, R * 0.84)
		draw_circle(p, 4.2, INK, true, -1.0, true)
		draw_circle(p, 2.8, GOLD_LITE if i % 2 == 0 else GOLD, true, -1.0, true)
	# the golden ring, inked, with a light line along it
	draw_polyline(outer, INK, 11.0, true)
	draw_polyline(outer, GOLD, 7.0, true)
	var lite := PackedVector2Array()
	for i in range(int(N * 0.5) + 4, N - 3):     # along its top
		lite.append(_pt(TAU * i / N, R - 1.2))
	draw_polyline(lite, GOLD_LITE, 2.2, true)
	# four gems on the ring
	for k in 4:
		var a := PI / 4.0 + k * PI / 2.0
		_gem(_pt(a, R), Color("8fd3f2") if k % 2 == 0 else Color("ff9fc8"))
	# three small stars travelling round it
	for k in 3:
		var a := -_t * 0.45 + k * TAU / 3.0
		var tw := 1.0 + 0.25 * sin(_t * 4.0 + k * 2.1)
		_star(_pt(a, R), 4, 9.0 * tw, 0.4, Color.WHITE, 0.0)
	# the star on top, rocking a little
	var top := _pt(-PI / 2.0, R) + Vector2(0, -6)
	_star(top, 5, 22.0 * (1.0 + 0.05 * sin(_t * 3.0)), 0.46, GOLD, sin(_t * 1.2) * 0.14)
	draw_circle(top + Vector2(-4, -5), 2.4, Color(1, 1, 1, 0.85), true, -1.0, true)
	# twinkles that come and go round it
	for k in 4:
		var cycle := floorf(_t / 1.3 + k * 0.25)
		var life := fposmod(_t / 1.3 + k * 0.25, 1.0)
		var h := float(absi(hash(int(cycle) * 7 + k)) % 1000) / 1000.0
		var p := _pt(TAU * h, R * (0.95 + 0.25 * fposmod(h * 7.3, 1.0)))
		var r := 6.0 * sin(life * PI)
		draw_line(p + Vector2(-r, 0), p + Vector2(r, 0), Color(1, 1, 0.9, 0.9), 2.0, true)
		draw_line(p + Vector2(0, -r), p + Vector2(0, r), Color(1, 1, 0.9, 0.9), 2.0, true)


func _gem(c: Vector2, col: Color) -> void:
	var k := absf(_turn) if absf(_turn) >= 0.1 else 0.1
	var pts := PackedVector2Array([c + Vector2(0, -10), c + Vector2(7 * k, 0), c + Vector2(0, 10), c + Vector2(-7 * k, 0)])
	draw_colored_polygon(pts, col)
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, INK, 2.2, true)
	draw_line(c + Vector2(-2 * k, -4), c + Vector2(0, -7), Color(1, 1, 1, 0.9), 1.8, true)


func _star(c: Vector2, points: int, r: float, inner: float, fill: Color, rot: float) -> void:
	var pts := PackedVector2Array()
	for k in points * 2:
		var a := -PI / 2.0 + rot + k * PI / points
		pts.append(c + Vector2.from_angle(a) * (r if k % 2 == 0 else r * inner))
	draw_colored_polygon(pts, fill)
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, INK, 2.2, true)
