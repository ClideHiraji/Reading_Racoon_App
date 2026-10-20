@tool
class_name Raccoon
extends Control
## Racoon, the companion (FR-14), drawn as layered paper cut-outs (D-009): each
## piece casts a small shadow on the piece behind it. Wears a teal river scarf.
## Moods: idle, happy, thinking, encourage, celebrate, sleepy.
## Swap for real art later; keep the set_mood() API.

const FUR := Color("8e8899")
const FUR_LIGHT := Color("b8b2c2")
const FUR_DARK := Color("5d5766")
const MASK := Color("37303d")
const CREAM := Color("fbf3e4")
const EAR_IN := Color("e7b9a8")
const BLUSH := Color(0.93, 0.47, 0.4, 0.35)

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
var wag := 0.0:
	set(v):
		wag = v
		queue_redraw()

## What Racoon wears, {slot: item id} (FR-07, Wardrobe). By default it follows the
## child's saved outfit; the shop sets it directly to try things on.
var outfit := {"neck": "scarf_teal"}:
	set(v):
		outfit = v
		queue_redraw()
@export var follow_saved_outfit := true

var _tween: Tween


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(180, 180)
	var gs := get_node_or_null("/root/GameState")
	if follow_saved_outfit and gs and not Engine.is_editor_hint():
		outfit = gs.wardrobe.equipped.duplicate()
		gs.outfit_changed.connect(func(): outfit = gs.wardrobe.equipped.duplicate())
	if not Engine.is_editor_hint():
		var idle := create_tween().set_loops()
		idle.tween_property(self, "squash", 1.025, 1.3).set_trans(Tween.TRANS_SINE)
		idle.parallel().tween_property(self, "wag", 1.0, 1.3).set_trans(Tween.TRANS_SINE)
		idle.tween_property(self, "squash", 1.0, 1.3).set_trans(Tween.TRANS_SINE)
		idle.parallel().tween_property(self, "wag", 0.0, 1.3).set_trans(Tween.TRANS_SINE)


func set_mood(m: String) -> void:
	mood = m
	if _tween:
		_tween.kill()
	_tween = create_tween()
	match m:
		"happy":
			_tween.tween_property(self, "hop", -24.0, 0.13).set_trans(Tween.TRANS_QUAD)
			_tween.tween_property(self, "hop", 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE)
		"celebrate":
			for i in 2:
				_tween.tween_property(self, "hop", -42.0, 0.16).set_trans(Tween.TRANS_QUAD)
				_tween.parallel().tween_property(self, "tilt", 0.14 * (1 - 2 * (i % 2)), 0.16)
				_tween.tween_property(self, "hop", 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE)
			_tween.tween_property(self, "tilt", 0.0, 0.1)
		"thinking":
			_tween.tween_property(self, "tilt", -0.12, 0.25).set_trans(Tween.TRANS_SINE)
			_tween.tween_interval(0.8)
			_tween.tween_property(self, "tilt", 0.0, 0.25)
		"encourage":
			for i in 2:
				_tween.tween_property(self, "squash", 0.94, 0.12)
				_tween.tween_property(self, "squash", 1.0, 0.12)
		_:
			_tween.tween_property(self, "hop", 0.0, 0.1)


func _draw() -> void:
	var k := minf(size.x, size.y) / 210.0
	var base := Vector2(size.x / 2.0, size.y - 4)
	# Ground shadow stays on the floor while the body hops.
	var gs := clampf(1.0 + hop / 120.0, 0.6, 1.0)
	_ellipse_at(base, Vector2(58 * gs, 9 * gs) * k, Color(Palette.SHADOW, 0.25), false)
	draw_set_transform(base + Vector2(0, hop * k), tilt, Vector2(1.0 / squash, squash) * k)
	# Coordinates below: a 210x210 box with the feet at (0, 0).
	_tail()
	_piece(Vector2(-24, -6), Vector2(17, 9), FUR_DARK)             # feet
	_piece(Vector2(24, -6), Vector2(17, 9), FUR_DARK)
	_piece(Vector2(0, -46), Vector2(50, 44), FUR)                  # body
	_piece(Vector2(0, -40), Vector2(31, 30), CREAM)                # belly
	_pin(outfit.get("badge", ""))
	_neck(outfit.get("neck", ""))
	_piece(Vector2(-16, -60), Vector2(10, 8), FUR_DARK)            # paws
	_piece(Vector2(16, -60), Vector2(10, 8), FUR_DARK)
	_ear(-1)
	_ear(1)
	_head()
	_face()
	_glasses(outfit.get("eyes", ""))
	_hat(outfit.get("hat", ""))


# --- Parts ----------------------------------------------------------------------------

func _tail() -> void:
	var sway := wag * 0.12
	for i in 6:
		var t := i / 5.0
		var p := Vector2(46 + t * 36, -30 - t * 78).rotated(sway * t)
		var r := 21.0 - i * 1.6
		_piece(p, Vector2(r, r), MASK if i % 2 == 1 else FUR_LIGHT)


func _scarf(col: Color) -> void:
	var pts := PackedVector2Array([Vector2(-42, -86), Vector2(42, -86), Vector2(30, -70),
			Vector2(0, -64), Vector2(-30, -70)])
	_poly(pts, col)
	_poly(PackedVector2Array([Vector2(14, -74), Vector2(34, -76), Vector2(28, -44),
			Vector2(16, -52)]), col.darkened(0.25))
	_piece(Vector2(18, -74), Vector2(8, 7), col.darkened(0.25))   # knot


# --- Outfit (Wardrobe.ITEMS) ----------------------------------------------------------

func _neck(id: String) -> void:
	match id:
		"scarf_teal":
			_scarf(Palette.TEAL)
		"scarf_coral":
			_scarf(Palette.CORAL)
		"scarf_mango":
			_scarf(Palette.MANGO)
		"bow_tie":
			_poly(PackedVector2Array([Vector2(0, -78), Vector2(-28, -92), Vector2(-28, -64)]), Palette.PLUM)
			_poly(PackedVector2Array([Vector2(0, -78), Vector2(28, -92), Vector2(28, -64)]), Palette.PLUM)
			_piece(Vector2(0, -78), Vector2(9, 9), Palette.PLUM_DEEP)
		"lei":
			# Sampaguita garland: small white flowers with yellow centers.
			for i in 11:
				var a := PI * (0.08 + 0.84 * i / 10.0)
				var p := Vector2(cos(a) * 44, -84 + sin(a) * 24)
				_piece(p, Vector2(9, 9), Color("fbfaf3"))
				draw_circle(p, 3.5, Palette.MANGO)


func _hat(id: String) -> void:
	match id:
		"cap":
			_poly(_arc_pts(Vector2(0, -164), Vector2(62, 34), PI, TAU), Palette.TEAL)
			_piece(Vector2(-46, -164), Vector2(40, 9), Palette.TEAL_DEEP)
			_piece(Vector2(0, -196), Vector2(7, 5), Palette.TEAL_DEEP, false)
		"party_hat":
			_poly(PackedVector2Array([Vector2(-28, -170), Vector2(4, -242), Vector2(30, -168)]), Palette.CORAL)
			for k in 3:
				var t := 0.25 + k * 0.22
				draw_line(Vector2(-28 + 32 * t, -170 - 72 * t), Vector2(30 - 26 * t, -168 - 74 * t),
						Palette.MANGO, 5.0, true)
			_piece(Vector2(4, -244), Vector2(10, 10), Palette.MANGO)
		"flower_crown":
			for i in 9:
				var a := PI * (1.12 + 0.76 * i / 8.0)
				var p := Vector2(cos(a) * 64, -150 + sin(a) * 38)
				var col: Color = [Color("fbfaf3"), Palette.CORAL.lightened(0.3), Palette.MANGO][i % 3]
				_piece(p, Vector2(11, 11), col)
				draw_circle(p, 4, Palette.MANGO_DEEP)
		"salakot":
			# Filipino woven hat: a wide, low cone with radiating weave lines and a knob.
			_piece(Vector2(0, -166), Vector2(98, 20), Palette.NIPA_DEEP)
			var cone := PackedVector2Array([Vector2(-94, -168), Vector2(0, -214), Vector2(94, -168)])
			_poly(cone, Palette.NIPA)
			for k in 7:
				var x := -80.0 + k * 26.7
				draw_line(Vector2(0, -212), Vector2(x, -170), Palette.NIPA_DEEP, 2.0, true)
			_piece(Vector2(0, -216), Vector2(8, 7), Palette.NIPA_DEEP)
		"gold_crown":
			var pts := PackedVector2Array([Vector2(-44, -168), Vector2(-46, -210), Vector2(-24, -188),
					Vector2(0, -220), Vector2(24, -188), Vector2(46, -210), Vector2(44, -168)])
			_poly(pts, Palette.MANGO)
			for x in [-26.0, 0.0, 26.0]:
				draw_circle(Vector2(x, -180), 6, Palette.CORAL)


func _glasses(id: String) -> void:
	match id:
		"round_glasses":
			for s in [-1, 1]:
				draw_arc(Vector2(30 * s, -122), 17, 0, TAU, 28, Palette.INK, 4.0, true)
			draw_line(Vector2(-13, -124), Vector2(13, -124), Palette.INK, 4.0, true)
		"sunglasses":
			for s in [-1, 1]:
				_piece(Vector2(30 * s, -121), Vector2(20, 14), Color(0.13, 0.11, 0.14, 0.92), false)
				draw_line(Vector2(30 * s - 10, -127), Vector2(30 * s - 2, -130), Color(1, 1, 1, 0.5), 3.0)
			draw_line(Vector2(-10, -124), Vector2(10, -124), Palette.INK, 4.0, true)
		"star_glasses":
			for s in [-1, 1]:
				_poly(_star_pts(Vector2(30 * s, -122), 22, 11), Palette.MANGO, false)
				_poly(_star_pts(Vector2(30 * s, -122), 13, 7), Color(0.2, 0.17, 0.2, 0.85), false)
			draw_line(Vector2(-10, -124), Vector2(10, -124), Palette.MANGO_DEEP, 4.0, true)


func _pin(id: String) -> void:
	var icon: String = {"pin_star": "star", "pin_heart": "heart", "pin_book": "book"}.get(id, "")
	if icon == "":
		return
	var c := Vector2(-20, -36)
	_piece(c, Vector2(15, 15), Palette.CARD)
	draw_arc(c, 15, 0, TAU, 24, Palette.MANGO_DEEP, 2.5, true)
	var col: Color = {"star": Palette.MANGO_DEEP, "heart": Palette.CORAL, "book": Palette.BAY}[icon]
	Icons.draw(self, icon, c, 20, col)


func _star_pts(c: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r_out if i % 2 == 0 else r_in))
	return pts


func _arc_pts(c: Vector2, radii: Vector2, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(a0, a1, i / 16.0)
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


func _ear(side: int) -> void:
	var s := float(side)
	_poly(PackedVector2Array([Vector2(s * 30, -160), Vector2(s * 66, -196), Vector2(s * 72, -142)]), FUR_DARK)
	_poly(PackedVector2Array([Vector2(s * 40, -160), Vector2(s * 63, -184), Vector2(s * 66, -150)]),
			EAR_IN, false)


## Head with cheek tufts: an ellipse whose sides are pushed out into points.
func _head() -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var tuft := 1.0 + 0.16 * pow(maxf(0.0, absf(cos(a)) - 0.6) / 0.4, 2.0) * (1.0 if sin(a) > -0.1 else 0.0)
		pts.append(Vector2(0, -120) + Vector2(cos(a) * 74 * tuft, sin(a) * 58))
	_poly(pts, FUR)
	_piece(Vector2(-28, -146), Vector2(22, 8), CREAM, false)       # brows
	_piece(Vector2(28, -146), Vector2(22, 8), CREAM, false)
	# Bandit mask.
	var mask := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		mask.append(Vector2(cos(a) * 66, sin(a) * 19 - 122 + (6 if absf(cos(a)) < 0.25 else 0)))
	_poly(mask, MASK, false)
	_piece(Vector2(0, -94), Vector2(40, 26), CREAM)                # muzzle


func _face() -> void:
	for side in [-1, 1]:
		var c := Vector2(30 * side, -122)
		match mood:
			"happy", "celebrate":
				draw_arc(c + Vector2(0, 5), 10, PI + 0.35, TAU - 0.35, 12, CREAM, 4.5, true)
			"sleepy":
				draw_arc(c + Vector2(0, -3), 9, 0.35, PI - 0.35, 12, CREAM, 4.0, true)
			_:
				var look := Vector2(3 * side, -5) if mood == "thinking" else Vector2.ZERO
				draw_circle(c, 12, CREAM)
				draw_circle(c + look, 7.5, Palette.INK)
				draw_circle(c + look + Vector2(-2.5, -3), 2.6, Color.WHITE)
	_ellipse_at(Vector2(-48, -98), Vector2(10, 7), BLUSH, false)
	_ellipse_at(Vector2(48, -98), Vector2(10, 7), BLUSH, false)
	_ellipse_at(Vector2(0, -105), Vector2(11, 8), Palette.INK, false)   # nose
	draw_circle(Vector2(-3, -108), 2.5, Color(1, 1, 1, 0.6))
	var m := Vector2(0, -91)
	match mood:
		"celebrate":
			_ellipse_at(m + Vector2(0, 4), Vector2(12, 10), Color("5a2b2b"), false)
			_ellipse_at(m + Vector2(0, 9), Vector2(7, 4), Palette.CORAL, false)
		"thinking":
			draw_circle(m + Vector2(7, 3), 4, Color("5a2b2b"))
		"sleepy":
			draw_line(m + Vector2(-6, 2), m + Vector2(6, 2), Palette.INK, 3.0, true)
		_:
			draw_arc(m + Vector2(-7, 0), 7, 0.2, PI - 0.2, 10, Palette.INK, 3.0, true)
			draw_arc(m + Vector2(7, 0), 7, 0.2, PI - 0.2, 10, Palette.INK, 3.0, true)


# --- Paper helpers ---------------------------------------------------------------------

func _piece(center: Vector2, radii: Vector2, color: Color, shadow: bool = true) -> void:
	_poly(_ellipse_pts(center, radii), color, shadow)


func _poly(pts: PackedVector2Array, color: Color, shadow: bool = true) -> void:
	if shadow:
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(0, 4))
		draw_colored_polygon(sh, Color(Palette.SHADOW, 0.28))
	draw_colored_polygon(pts, color)


func _ellipse_at(center: Vector2, radii: Vector2, color: Color, shadow: bool) -> void:
	_poly(_ellipse_pts(center, radii), color, shadow)


func _ellipse_pts(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts
