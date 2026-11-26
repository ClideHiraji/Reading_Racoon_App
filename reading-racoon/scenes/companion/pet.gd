class_name Pet
extends Node2D
## A little pet that floats beside Racoon's head: a maya bird, a butterfly, a bee, an alitaptap
## (firefly), a little dragon or a star sprite. Drawn in code in his ink style: it flaps, bobs,
## and keeps to one side of his head, sometimes flying over to the other.
## It plays with him:
##   - when he's tapped, it does a happy loop with little hearts (cheer)
##   - when he dances, celebrates or jumps, it circles his head (orbit)
##   - sometimes it rests on his head, and when he's sleepy it sleeps there
## It lives inside his puppet, in his drawing's units (400 x 400), so it grows and shrinks
## with him. On the Closet's still cards it's drawn once and doesn't move.

const INK := Color("3b2d3a")
const KINDS := ["pet_maya", "pet_butterfly", "pet_bee", "pet_firefly", "pet_dragon", "pet_star"]
const SIDE_X := 152.0        # how far from his head's middle it floats
const SIDE_Y := -78.0
const SCALE := 1.6
const CARD_SCALE := 2.0      # on the Closet's still cards the pet is what you're picking, so it's bigger
const FLY_S := 1.4           # seconds to fly over his head to the other side
const CHEER_S := 1.3
const ORBIT_S := 2.4
const PERCH_S := 4.5

var kind := ""
var puppet: Node2D
var still := false:
	set(v):
		still = v
		set_process(not v)
var asleep := false

var _t := 0.0
var _pos := Vector2.INF
var _side := 1.0
var _act := ""
var _act_t := 0.0
var _from := Vector2.ZERO
var _switch_in := 10.0
var _perch_in := 28.0
var _bits: Array = []      # hearts, sparkles and z's: {p, v, age, life, kind}
var _trail: Array = []     # the star sprite's rainbow trail
var _face := -1.0          # it looks toward him: -1 to the left
var _behind := false       # round the back of his head, in an orbit


static func has_kind(id: String) -> bool:
	return KINDS.has(id)


func setup(id: String, owner_puppet: Node2D, is_still: bool) -> void:
	kind = id
	puppet = owner_puppet
	still = is_still
	_side = 1.0
	_pos = Vector2.INF
	_place()
	queue_redraw()


## A happy loop with hearts (he was tapped).
func cheer() -> void:
	if still or asleep:
		return
	_start("cheer")
	for i in 3:
		_bits.append({"p": _pos + Vector2(randf_range(-10, 10), -20), "v": Vector2(randf_range(-30, 30), -70),
			"age": -i * 0.15, "life": 1.1, "kind": "heart"})


## Once round his head (he's dancing, celebrating or jumping).
func orbit() -> void:
	if still or asleep:
		return
	_start("orbit")


func set_asleep(on: bool) -> void:
	if on == asleep:
		return
	asleep = on
	_start("perch" if on else "")


func _start(act: String) -> void:
	_act = act
	_act_t = 0.0
	_from = _pos


func _head() -> Vector2:
	return puppet.head_point() if puppet and puppet.has_method("head_point") else Vector2(200.5, 165.6)


func _rest(head: Vector2) -> Vector2:
	var bob := Vector2(sin(_t * 1.7) * 6.0, sin(_t * 2.6) * 7.0)
	return head + Vector2(_side * SIDE_X, SIDE_Y) + bob


func _place() -> void:
	var head := _head()
	_pos = _rest(head) if _pos == Vector2.INF else _pos
	position = _pos
	_face = signf(head.x - _pos.x) if absf(head.x - _pos.x) > 4.0 else _face


func _process(delta: float) -> void:
	if puppet == null:
		return
	_t += delta
	_act_t += delta
	var head := _head()
	var target := _rest(head)
	var follow := 7.0
	match _act:
		"cheer":
			var a := _act_t / CHEER_S * TAU
			target += Vector2(sin(a) * 26.0, -(1.0 - cos(a)) * 26.0)
			follow = 16.0
			if _act_t >= CHEER_S:
				_act = ""
		"orbit":
			# a ring round the top of his head: in front over his forehead, then behind his ears
			var ang := clampf(_act_t / ORBIT_S, 0.0, 1.0) * TAU
			target = head + Vector2(_side * cos(ang) * SIDE_X, -110.0 + sin(ang) * 36.0)
			follow = 14.0
			_set_behind(sin(ang) < -0.15)
			if _act_t >= ORBIT_S:
				_act = ""
				_set_behind(false)
		"fly":
			var u := clampf(_act_t / FLY_S, 0.0, 1.0)
			var e := u * u * (3.0 - 2.0 * u)
			target = _from.lerp(_rest(head), e) + Vector2(0, -sin(e * PI) * 120.0)
			follow = 20.0
			if _act_t >= FLY_S:
				_act = ""
		"perch":
			target = head + Vector2(_side * 26.0, -128.0)
			follow = 10.0
			if not asleep and _act_t >= PERCH_S:
				_start("fly")
	if _act == "":
		_switch_in -= delta
		_perch_in -= delta
		if _switch_in <= 0.0:
			_switch_in = randf_range(9.0, 15.0)
			_side = -_side
			_start("fly")
		elif _perch_in <= 0.0:
			_perch_in = randf_range(25.0, 40.0)
			_start("perch")
	if asleep and int(_t * 10.0) % 14 == 0 and _bits.size() < 4:
		_bits.append({"p": _pos + Vector2(10, -24), "v": Vector2(8, -22), "age": 0.0, "life": 1.6, "kind": "z"})
	_pos = _pos.lerp(target, 1.0 - exp(-follow * delta))
	if _act == "orbit" or _act == "fly":
		_face = signf(target.x - _pos.x) if absf(target.x - _pos.x) > 1.0 else _face
	elif absf(head.x - _pos.x) > 6.0:
		_face = signf(head.x - _pos.x)
	position = _pos
	if kind == "pet_star":
		_trail.push_front(_pos)
		if _trail.size() > 14:
			_trail.pop_back()
		if randf() < delta * 3.0:
			_bits.append({"p": _pos + Vector2(randf_range(-30, 30), randf_range(-26, 20)), "v": Vector2.ZERO,
				"age": 0.0, "life": 0.9, "kind": "spark"})
	for b: Dictionary in _bits:
		b.age += delta
		if b.age > 0.0:
			b.p += b.v * delta
	_bits = _bits.filter(func(b: Dictionary) -> bool: return b.age < b.life)
	queue_redraw()


## Behind his head (drawn before his body) or in front of him.
func _set_behind(on: bool) -> void:
	var p := get_parent()
	if on == _behind or p == null:
		return
	_behind = on
	p.move_child(self, 0 if on else p.get_child_count() - 1)


# --- drawing --------------------------------------------------------------------------------------

func _draw() -> void:
	if kind == "":
		return
	if kind == "pet_star":
		_draw_trail()
	var resting := asleep or _act == "perch"
	var beat := 34.0 if kind == "pet_bee" else (9.0 if kind == "pet_butterfly" else 15.0)
	var flap := -0.7 if resting else sin(_t * beat)
	var tilt := 0.0 if still else sin(_t * 1.9) * 0.08
	var sc := CARD_SCALE if still else SCALE
	draw_set_transform(Vector2.ZERO, tilt, Vector2(_face * sc, sc))
	match kind:
		"pet_maya":
			_maya(flap, resting)
		"pet_butterfly":
			_butterfly(flap, resting)
		"pet_bee":
			_bee(flap)
		"pet_firefly":
			_firefly(flap)
		"pet_dragon":
			_dragon(flap)
		"pet_star":
			_star()
	draw_set_transform(Vector2.ZERO)
	_draw_bits()


func _shape(pts: PackedVector2Array, fill: Color, w := 2.6) -> void:
	draw_colored_polygon(pts, fill)
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, INK, w, true)


func _oval(c: Vector2, rx: float, ry: float, rot := 0.0, n := 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


func _eye(c: Vector2, r := 2.6) -> void:
	draw_circle(c, r, INK, true, -1.0, true)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.4), r * 0.38, Color.WHITE, true, -1.0, true)


func _sleepy_eye(c: Vector2, r := 2.6) -> void:
	draw_arc(c, r, 0.2, PI - 0.2, 8, INK, 1.8, true)


func _blush(c: Vector2) -> void:
	draw_colored_polygon(_oval(c, 3.6, 2.2), Color(1.0, 0.54, 0.61, 0.6))


func _face_eye(c: Vector2, r := 2.6) -> void:
	if asleep:
		_sleepy_eye(c, r)
	else:
		_eye(c, r)


func _maya(flap: float, resting: bool) -> void:
	_shape(PackedVector2Array([Vector2(-14, 2), Vector2(-31, -7), Vector2(-33, 4), Vector2(-28, 11), Vector2(-12, 9)]),
			Color("8a5a3a"))
	_shape(_oval(Vector2(0, 3), 20, 17), Color("c08552"))
	draw_colored_polygon(_oval(Vector2(4, 9), 13, 9), Color("f6e3c4"))
	_shape(_oval(Vector2(10, -9), 12, 11), Color("a8693f"))
	draw_colored_polygon(_oval(Vector2(14, -5), 6.5, 5), Color("fff3dc"))
	draw_colored_polygon(_oval(Vector2(15, 1), 3.2, 2.6), INK)
	_shape(PackedVector2Array([Vector2(21, -10), Vector2(29, -7), Vector2(21, -4)]), Color("ffb52e"), 2.0)
	_face_eye(Vector2(15, -11))
	_blush(Vector2(11, -3))
	_shape(_oval(Vector2(-6, -2), 13, 7.5, -0.45 + flap * 0.85), Color("8a5a3a"))
	if resting:
		draw_line(Vector2(-3, 19), Vector2(-4, 25), Color("e9801f"), 2.4, true)
		draw_line(Vector2(5, 19), Vector2(5, 25), Color("e9801f"), 2.4, true)


func _butterfly(flap: float, resting: bool) -> void:
	var w := 0.5 if resting else 0.35 + 0.65 * absf(flap)
	for sx in [-1.0, 1.0]:
		_shape(_oval(Vector2(sx * 14.0 * w, -8), 15.0 * w, 12, sx * 0.4), Color("5c9bd4"))
		draw_colored_polygon(_oval(Vector2(sx * 16.0 * w, -10), 4.5 * w, 3.6), Color("ffd23f"))
		_shape(_oval(Vector2(sx * 11.0 * w, 9), 10.0 * w, 8, -sx * 0.4), Color("8fd3f2"))
	_shape(_oval(Vector2(0, 2), 3.6, 13), Color("4b3a44"), 2.0)
	_shape(_oval(Vector2(0, -15), 6.5, 6), Color("6b5a78"), 2.0)
	draw_line(Vector2(-2, -20), Vector2(-7, -29), INK, 1.8, true)
	draw_line(Vector2(2, -20), Vector2(7, -29), INK, 1.8, true)
	draw_circle(Vector2(-7, -29), 2.0, INK, true, -1.0, true)
	draw_circle(Vector2(7, -29), 2.0, INK, true, -1.0, true)
	_face_eye(Vector2(-2.4, -15.5), 1.6)
	_face_eye(Vector2(2.4, -15.5), 1.6)


func _bee(flap: float) -> void:
	for wx in [-3.0, 6.0]:
		var wing := _oval(Vector2(wx, -15), 8, 11, flap * 0.5)
		draw_colored_polygon(wing, Color(0.9, 0.97, 1.0, 0.85))
		var ring := wing.duplicate()
		ring.append(wing[0])
		draw_polyline(ring, Color("86b5d2"), 1.8, true)
	_shape(PackedVector2Array([Vector2(-17, 0), Vector2(-26, 3), Vector2(-17, 6)]), INK, 1.6)
	_shape(_oval(Vector2(0, 3), 18, 14), Color("ffd23f"))
	for x in [-6.0, 4.0]:
		var hy := 14.0 * sqrt(maxf(0.0, 1.0 - pow(x / 18.0, 2.0))) - 1.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2.6, 3 - hy), Vector2(x + 2.6, 3 - hy),
				Vector2(x + 2.6, 3 + hy), Vector2(x - 2.6, 3 + hy)]), Color("4b3a44"))
	draw_line(Vector2(11, -8), Vector2(15, -19), INK, 1.8, true)
	draw_circle(Vector2(15, -19), 2.2, INK, true, -1.0, true)
	_face_eye(Vector2(11, 0))
	draw_arc(Vector2(12, 5), 3.0, 0.3, 2.4, 6, INK, 1.6, true)
	_blush(Vector2(8, 7))


func _firefly(flap: float) -> void:
	var pulse := 0.6 + 0.4 * sin(_t * 3.0)
	for i in 5:
		var r := 30.0 - i * 5.0
		draw_circle(Vector2(-12, 6), r, Color(0.92, 1.0, 0.45, (0.05 + i * 0.05) * pulse), true, -1.0, true)
	for wx in [-2.0, 5.0]:
		draw_colored_polygon(_oval(Vector2(wx, -11), 7, 10, flap * 0.6), Color(0.92, 0.97, 1.0, 0.75))
	_shape(_oval(Vector2(-12, 6), 9, 8), Color(0.93, 0.96, 0.42).lerp(Color.WHITE, 0.3 * pulse))
	_shape(_oval(Vector2(2, 0), 13, 10), Color("4a3a44"))
	_shape(_oval(Vector2(13, -3), 7.5, 7), Color("e9801f"))
	draw_line(Vector2(16, -9), Vector2(20, -18), INK, 1.6, true)
	draw_circle(Vector2(20, -18), 1.8, INK, true, -1.0, true)
	_face_eye(Vector2(15, -4), 2.0)


func _dragon(flap: float) -> void:
	var green := Color("6aab4c")
	_shape(PackedVector2Array([Vector2(-12, 10), Vector2(-26, 14), Vector2(-34, 6), Vector2(-38, 0),
			Vector2(-31, 4), Vector2(-25, 8), Vector2(-14, 4)]), green)
	_shape(PackedVector2Array([Vector2(-38, 0), Vector2(-44, -5), Vector2(-42, 4), Vector2(-36, 6)]), Color("f39a2f"), 1.8)
	var wing := PackedVector2Array([Vector2(0, 0), Vector2(-12, -26), Vector2(-9, -17), Vector2(-21, -20),
			Vector2(-11, -10), Vector2(-24, -7), Vector2(-4, 4)])
	var r := -0.2 + flap * 0.55
	var turned := PackedVector2Array()
	for p in wing:
		turned.append((p - Vector2(-2, -2)).rotated(r) + Vector2(-2, -2))
	_shape(turned, Color("3f8a2e"))
	_shape(_oval(Vector2(0, 6), 16, 14), green)
	draw_colored_polygon(_oval(Vector2(3, 10), 9, 8), Color("f6edc8"))
	_shape(PackedVector2Array([Vector2(6, -20), Vector2(9, -30), Vector2(12, -20)]), Color("fff3dc"), 1.8)
	_shape(PackedVector2Array([Vector2(13, -20), Vector2(17, -29), Vector2(19, -19)]), Color("fff3dc"), 1.8)
	_shape(_oval(Vector2(12, -10), 12, 11), green)
	_shape(_oval(Vector2(22, -6), 7, 5), Color("8fcc6c"), 2.2)
	draw_circle(Vector2(25, -7), 1.2, INK, true, -1.0, true)
	_face_eye(Vector2(14, -13))
	_blush(Vector2(12, -4))


func _star() -> void:
	var pts := PackedVector2Array()
	var spin := sin(_t * 1.4) * 0.25
	for i in 10:
		var rr := 22.0 if i % 2 == 0 else 10.5
		pts.append(Vector2.from_angle(-PI / 2.0 + spin + i * PI / 5.0) * rr)
	_shape(pts, Color("ffd23f"))
	_face_eye(Vector2(-4.5, -1), 2.2)
	_face_eye(Vector2(4.5, -1), 2.2)
	draw_arc(Vector2(0, 3.5), 2.6, 0.3, PI - 0.3, 6, INK, 1.6, true)
	_blush(Vector2(-8, 4))
	_blush(Vector2(8, 4))


func _draw_trail() -> void:
	for i in range(_trail.size() - 1, 0, -1):
		var p: Vector2 = _trail[i] - _pos
		var c := Color.from_hsv(fmod(_t * 0.4 + i * 0.07, 1.0), 0.45, 1.0, 0.5 * (1.0 - float(i) / _trail.size()))
		draw_circle(p, 9.0 * (1.0 - float(i) / (_trail.size() + 2)), c, true, -1.0, true)


func _draw_bits() -> void:
	for b: Dictionary in _bits:
		if b.age < 0.0:
			continue
		var k: float = 1.0 - b.age / b.life
		var p: Vector2 = b.p - _pos
		match str(b.kind):
			"heart":
				var s := 9.0
				var h := PackedVector2Array()
				for i in 24:
					var a := TAU * i / 24.0
					h.append(p + Vector2(16.0 * pow(sin(a), 3.0), -(13.0 * cos(a) - 5.0 * cos(2.0 * a)
							- 2.0 * cos(3.0 * a) - cos(4.0 * a))) * s / 16.0)
				draw_colored_polygon(h, Color(1.0, 0.44, 0.53, k))
			"spark":
				var r := 8.0 * sin(k * PI)
				draw_line(p + Vector2(-r, 0), p + Vector2(r, 0), Color(1, 1, 1, k), 2.0, true)
				draw_line(p + Vector2(0, -r), p + Vector2(0, r), Color(1, 1, 1, k), 2.0, true)
			"z":
				var z := 7.0
				draw_polyline(PackedVector2Array([p + Vector2(-z, -z), p + Vector2(z, -z), p + Vector2(-z, z),
						p + Vector2(z, z)]), Color(INK, k * 0.8), 2.6, true)
