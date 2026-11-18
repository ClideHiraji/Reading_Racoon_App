@tool
class_name WindScarf
extends Node2D
## A diamond scarf's long ends, blowing in the wind behind Racoon (D-031):
##   - ribbon:  the Starlight ribbon, two pink ribbon tails with little stars and notched ends
##   - comet:   the Comet scarf, a long red hero tail with a gold lightning stripe, a forked end and sparks
##   - rainbow: the Rainbow scarf, rainbow tails
## Drawn in code, in his ink style, in his body's units (his drawing is 400 x 400). Every point along a
## tail goes round a small circle, a little later than the point before it, so waves run down the
## tail and its tip flicks ("moving circles"). The ribbon also twists, showing its darker back. The
## wind comes in gusts, and a bright shimmer runs along it now and then (its diamond shine).
## The puppet places it each frame (place()): the spot behind his neck where it leaves him. It's
## drawn behind him, or in front when he's turned away. On the Closet's still cards it's drawn once.

const INK := Color("3b2d3a")
## Each style's tails are [length, width, how far below the wind's line, phase]; the first is the long one.
const STYLES := {
	"ribbon": {"tails": [[205.0, 36.0, 0.10, 0.0], [158.0, 28.0, 0.42, 2.1]], "face": "ffa8cf", "back": "c9a2ec",
		"edge": "fff1f8", "end": "notch", "trim": "stars", "sparks": ["ffffff", "ffd6ea", "fff3b0"]},
	"comet": {"tails": [[232.0, 38.0, 0.06, 0.0], [150.0, 26.0, 0.36, 1.7]], "face": "e8453c", "back": "8f2420",
		"edge": "ff8a7a", "end": "fork", "trim": "bolt", "sparks": ["ffd23f", "ff9a3c", "fff3b0"]},
	"rainbow": {"tails": [[210.0, 34.0, 0.10, 0.0], [165.0, 26.0, 0.40, 2.0]], "face": "rainbow", "back": "efe9ff",
		"edge": "ffffff", "end": "notch", "trim": "", "sparks": ["ffffff"]},
}
const SEGS := 22
const WAVE_HZ := 0.85        # how often each point goes round its circle
const WAVES := 1.35          # how many waves run along a tail at once
const STILL_T := 0.9         # the moment the Closet's still cards show

var style := ""
var still := false:
	set(v):
		still = v
		set_process(not v and not Engine.is_editor_hint())

var _t := STILL_T
var _at := Vector2(168, 268)
var _s := 1.0
var _tip := Vector2.INF
var _tip_dir := Vector2.LEFT
var _sparks: Array = []      # {p, v, age, life, col, star}
var _spark_in := 0.0


static func has_style(id: String) -> bool:
	return STYLES.has(id)


func show_style(id: String, is_still: bool) -> void:
	if id != style:
		style = id
		_sparks.clear()
		queue_redraw()
	if is_still != still or (is_still and _t != STILL_T):
		still = is_still
		if still:
			_t = STILL_T
			_sparks.clear()
		queue_redraw()


## Where it leaves his neck (in his body's units) and how far it's shown (0 to 1).
func place(at: Vector2, shown: float) -> void:
	if at.is_equal_approx(_at) and is_equal_approx(shown, _s):
		return
	_at = at
	_s = shown
	if still or not is_processing():
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var st: Dictionary = STYLES.get(style, {})
	if not st.is_empty() and _tip != Vector2.INF and _s > 0.5:
		_spark_in -= delta
		if _spark_in <= 0.0:
			_spark_in = randf_range(0.14, 0.3)
			var cols: Array = st.sparks
			_sparks.append({"p": _tip + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
				"v": _tip_dir * randf_range(20, 45) + Vector2(randf_range(-10, 10), randf_range(-18, 6)),
				"age": 0.0, "life": randf_range(0.7, 1.1), "col": Color(str(cols[randi() % cols.size()])),
				"star": randf() < 0.45})
	for b: Dictionary in _sparks:
		b.age += delta
		b.p += b.v * delta
	_sparks = _sparks.filter(func(b: Dictionary) -> bool: return b.age < b.life)
	queue_redraw()


# --- drawing --------------------------------------------------------------------------------------

func _draw() -> void:
	var st: Dictionary = STYLES.get(style, {})
	if st.is_empty() or _s < 0.02:
		return
	var tails: Array = st.tails
	for i in range(tails.size() - 1, -1, -1):   # the long tail last, over the short one
		_draw_tail(st, tails[i], i)
	for b: Dictionary in _sparks:
		var k: float = 1.0 - b.age / b.life
		var c: Color = b.col
		c.a = k
		if b.star:
			var r := 5.5 * sin(k * PI)
			draw_line(b.p + Vector2(-r, 0), b.p + Vector2(r, 0), c, 2.2, true)
			draw_line(b.p + Vector2(0, -r), b.p + Vector2(0, r), c, 2.2, true)
		else:
			draw_circle(b.p, 3.4 * k, c, true, -1.0, true)


func _draw_tail(st: Dictionary, tail: Array, idx: int) -> void:
	var length: float = float(tail[0]) * _s * (0.78 if still else 1.0)   # (shorter on a card, to fit it)
	var width: float = float(tail[1]) * _s
	var phase := float(tail[3])
	var dir := Vector2.from_angle(PI - float(tail[2]))      # the wind blows to your left
	var nrm := Vector2(-dir.y, dir.x)
	var gust := 0.8 + 0.2 * sin(_t * 0.43 + idx) + 0.08 * sin(_t * 1.37)
	var turn := TAU * WAVE_HZ * _t + phase
	# the centre line: each point on its own small circle, later the further along it is
	var mid := PackedVector2Array()
	for i in SEGS + 1:
		var u := float(i) / SEGS
		var ph := turn - TAU * WAVES * u
		var amp := 24.0 * _s * pow(u, 1.3) * gust
		mid.append(_at + dir * length * u + Vector2(0, 24.0 * _s * u * u)
				+ dir * cos(ph) * amp * 0.45 + nrm * sin(ph) * amp)
	# its edges: narrower toward the tip, and narrower still where it twists
	var lefts := PackedVector2Array()
	var rights := PackedVector2Array()
	var fronts: Array[bool] = []
	var sides: Array[Vector2] = []
	for i in SEGS + 1:
		var u := float(i) / SEGS
		var tg := (mid[mini(i + 1, SEGS)] - mid[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-tg.y, tg.x)
		var tw := cos(TAU * 0.5 * _t - TAU * 0.75 * u + phase * 1.3)
		var half := width * 0.5 * (1.0 - 0.28 * u) * (0.3 + 0.7 * absf(tw))
		lefts.append(mid[i] + side * half)
		rights.append(mid[i] - side * half)
		fronts.append(tw >= 0.0)
		sides.append(side)
	var tg_end := (mid[SEGS] - mid[SEGS - 1]).normalized()
	if idx == 0:
		_tip = mid[SEGS]
		_tip_dir = tg_end
	# the end: a notch, or a deep fork
	var half_end := lefts[SEGS].distance_to(rights[SEGS]) / 2.0
	var depth := half_end * (2.2 if st.end == "fork" else 1.2)
	var l_tip := lefts[SEGS] + tg_end * depth + sides[SEGS] * (2.0 if st.end == "fork" else 0.0)
	var r_tip := rights[SEGS] + tg_end * depth - sides[SEGS] * (2.0 if st.end == "fork" else 0.0)
	# fill, a quad at a time (front or back colour, and the diamond shimmer running along it)
	var sweep := fmod(_t * 0.32 + idx * 0.4, 1.7) - 0.35
	for i in SEGS:
		var u := (i + 0.5) / SEGS
		var col := _col(st, fronts[i], u)
		col = col.lerp(Color.WHITE, 0.4 * maxf(0.0, 1.0 - absf(u - sweep) / 0.09))
		draw_primitive(PackedVector2Array([lefts[i], lefts[i + 1], rights[i + 1], rights[i]]),
				PackedColorArray([col, col, col, col]), PackedVector2Array())
	var end_col := _col(st, fronts[SEGS - 1], 1.0)
	draw_primitive(PackedVector2Array([lefts[SEGS], l_tip, mid[SEGS]]), PackedColorArray([end_col, end_col, end_col]),
			PackedVector2Array())
	draw_primitive(PackedVector2Array([mid[SEGS], r_tip, rights[SEGS]]), PackedColorArray([end_col, end_col, end_col]),
			PackedVector2Array())
	# trim
	match str(st.trim):
		"stars":
			for u0 in [0.32, 0.56, 0.8]:
				var i := int(round((u0 + idx * 0.07) * SEGS))
				if i < SEGS and fronts[i]:
					_star4(mid[i], 6.5 * _s * (1.0 - 0.2 * float(i) / SEGS), Color.WHITE)
		"bolt":
			var zig := PackedVector2Array()
			var from := int(0.14 * SEGS)
			var to := int(0.86 * SEGS)
			for i in range(from, to + 1, 2):
				var hw := lefts[i].distance_to(rights[i]) / 2.0
				zig.append(mid[i] + sides[i] * hw * (0.32 if posmod(i, 4) < 2 else -0.32))
			if zig.size() > 1:
				draw_polyline(zig, INK, 7.0 * _s, true)
				draw_polyline(zig, Color("ffd23f"), 4.0 * _s, true)
	# the edge's light line, on the front face
	var edge := Color(str(st.edge))
	for i in SEGS:
		if fronts[i] and fronts[i + 1]:
			var a := mid[i].lerp(lefts[i], 0.62)
			var b := mid[i + 1].lerp(lefts[i + 1], 0.62)
			draw_line(a, b, Color(edge, 0.75), 2.4 * _s, true)
	# ink round it all
	var ring := PackedVector2Array(lefts)
	ring.append(l_tip)
	ring.append(mid[SEGS])
	ring.append(r_tip)
	for i in range(SEGS, -1, -1):
		ring.append(rights[i])
	ring.append(lefts[0])
	draw_polyline(ring, INK, 4.0 * _s, true)


func _col(st: Dictionary, front: bool, u: float) -> Color:
	if not front:
		return Color(str(st.back))
	if st.face == "rainbow":
		return Color.from_hsv(fposmod(u * 0.85 - _t * 0.12, 1.0), 0.5, 1.0)
	return Color(str(st.face))


func _star4(c: Vector2, r: float, fill: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var a := -PI / 2.0 + k * PI / 4.0
		pts.append(c + Vector2.from_angle(a) * (r if k % 2 == 0 else r * 0.42))
	draw_colored_polygon(pts, fill)
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, INK, 1.6, true)
