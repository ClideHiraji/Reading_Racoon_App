class_name LottiePlayer
extends Control
## Plays a Lottie animation (the JSON inside a .lottie file) as live vector
## shapes drawn by Godot, so it stays sharp at any size and needs no frames
## (D-022). It covers what the team's animations use: shape and precomp layers
## (with start offset and time stretch), groups, animated bezier paths,
## ellipses, solid and linear-gradient fills, strokes with butt or round caps,
## trim paths, and eased keyframes. No masks, mattes, effects or text.
## Plays once and holds the last frame, unless `loop`.
## Kept light for low-end phones: paths are prepared once per file, and each
## half-frame is worked out once (in the animation's own units, cut into
## triangles) and shared by every player of that file at any size. Drawing a
## frame is then just replaying those triangles, and only when the frame changes.

## Seconds to wait before it starts (to stagger a row).
@export var delay := 0.0
@export var loop := false
## How much of the box the animation's canvas fills (1 = fit), and which point
## of the canvas (0..1) sits in the middle, to frame what the callers expect.
var zoom := 1.0
var focus := Vector2(0.5, 0.5)

static var _cache := {}       # path + colors -> prepared animation
static var _built := {}       # path + colors -> {half-frame: draw commands}
static var _gradients := {}   # stops -> GradientTexture1D

var _data := {}
var _assets := {}
var _fr := 30.0
var _ip := 0.0
var _op := 1.0
var _w := 1.0
var _h := 1.0
var _key := ""
var _t := 0.0
var _frame := 0.0             # the half-frame on screen
var _out: Array = []          # commands being worked out


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Loads an animation. `colors` swaps Lottie colors, {Color(from): Color(to)},
## for example to the game's palette; the original file is never changed.
## Without colors, a bake next to the file (LottieBake) is used when there is
## one; `use_bake` false reads the .json (the bake tool does).
func load_lottie(path: String, colors: Dictionary = {}, use_bake := true) -> void:
	var key := path + str(colors) + ("" if use_bake else "#json")
	if not _cache.has(key) and colors.is_empty() and use_bake:
		_load_bake(path, key)
	if not _cache.has(key):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(data) != TYPE_DICTIONARY:
			push_error("LottiePlayer: can't read " + path)
			return
		if not colors.is_empty():
			_recolor(data, colors)
		_prepare(data)
		_cache[key] = data
	_data = _cache[key]
	_key = key
	if not _built.has(key):
		_built[key] = {}
	_fr = float(_data.get("fr", 30.0))
	_ip = float(_data.get("ip", 0.0))
	_op = float(_data.get("op", 1.0))
	_w = float(_data.get("w", 1.0))
	_h = float(_data.get("h", 1.0))
	_assets = {}
	for a in _data.get("assets", []):
		if a.has("layers"):
			_assets[a.id] = a.layers
	_frame = _ip
	queue_redraw()


## A baked animation: its frames are all there already, so nothing is read,
## prepared or built (tools/lottie-bake).
static func _load_bake(path: String, key: String) -> void:
	var bake_path := LottieBake.path_for(path)
	if not ResourceLoader.exists(bake_path):
		return
	var bake := load(bake_path) as LottieBake
	if bake == null or bake.frames.is_empty():
		return
	_cache[key] = {"fr": bake.fr, "ip": bake.ip, "op": bake.op, "w": bake.w, "h": bake.h,
			"layers": [], "assets": [], "baked": true}
	_built[key] = bake.frames


## Starts again from the first frame.
func replay() -> void:
	_t = 0.0
	set_process(true)


## Shows one moment (in frames of the animation) and stops there.
func seek(frame: float) -> void:
	set_process(false)
	_show(clampf(frame, _ip, _op - 0.01))


func duration() -> float:
	return (_op - _ip) / _fr


func _process(delta: float) -> void:
	if _data.is_empty():
		return
	_t += delta
	var f := _ip + maxf(_t - delay, 0.0) * _fr
	if loop:
		f = _ip + fmod(f - _ip, _op - _ip)
	elif f >= _op - 0.01:
		f = _op - 0.01
		set_process(false)
	_show(f)


func _show(f: float) -> void:
	var half := floorf(f * 2.0) / 2.0
	if half != _frame:
		_frame = half
		queue_redraw()


func _draw() -> void:
	if _data.is_empty():
		return
	var frames: Dictionary = _built[_key]
	if not frames.has(_frame):
		frames[_frame] = _build(_frame)
	var s := minf(size.x / _w, size.y / _h) * zoom
	if s <= 0.0:
		return
	draw_set_transform(size * 0.5 - Vector2(_w, _h) * focus * s, 0.0, Vector2(s, s))
	var edge := Smooth.EDGE / s   # soft edges stay about a pixel wide at any size
	var ci := get_canvas_item()
	for c in frames[_frame]:
		match int(c.t):
			0:   # solid fill, with a soft edge when opaque
				RenderingServer.canvas_item_add_triangle_array(ci, c.idx, c.pts, PackedColorArray([c.col]))
				if c.soft and Smooth.enabled:
					draw_polyline(c.ring, c.col, edge, true)
			1:   # gradient fill
				RenderingServer.canvas_item_add_triangle_array(ci, c.idx, c.pts, PackedColorArray([c.col]),
						c.uvs, PackedInt32Array(), PackedFloat32Array(), (c.tex as Texture2D).get_rid())
			2:   # stroke
				if c.pts.size() >= 2:
					draw_polyline(c.pts, c.col, c.w, true)
				if c.round:
					Smooth.circle(self, c.pts[0], c.w / 2.0, c.col, edge)
					Smooth.circle(self, c.pts[c.pts.size() - 1], c.w / 2.0, c.col, edge)
	draw_set_transform(Vector2.ZERO)


## Works out an animation's frames ahead of time, a couple per game frame, so
## its first play is as light as a replay on a slow phone. Call it a while
## before the animation is needed (a lesson warms the hearts and the star).
static func warm_up(path: String, colors: Dictionary = {}, per_frame := 2) -> void:
	var p := LottiePlayer.new()
	p.load_lottie(path, colors)
	var frames: Dictionary = _built.get(p._key, {})
	var todo: Array = []
	var f := p._ip
	while not p._data.is_empty() and f < p._op:
		if not frames.has(f):
			todo.append(f)
		f += 0.5
	if todo.is_empty():
		p.free()
		return
	var w := Warmer.new()
	w.player = p
	w.todo = todo
	w.per_frame = per_frame
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(w)


## Builds a player's frames in the background; a node in the tree, so quitting
## mid-way cleans it up.
class Warmer extends Node:
	var player: LottiePlayer
	var todo: Array = []
	var per_frame := 2

	func _process(_delta: float) -> void:
		var frames: Dictionary = LottiePlayer._built[player._key]
		for _n in per_frame:
			if todo.is_empty():
				break
			var half: float = todo.pop_front()
			if not frames.has(half):
				frames[half] = player._build(half)
		if todo.is_empty():
			queue_free()

	func _exit_tree() -> void:
		if is_instance_valid(player):
			player.free()


## One half-frame as draw commands, in the animation's own units.
func _build(half: float) -> Array:
	_out = []
	_layers(_data.get("layers", []), half, Transform2D.IDENTITY, 1.0)
	var commands := _out
	_out = []
	return commands


# --- Layers ----------------------------------------------------------------------------

## The last layer in the list is at the bottom. A precomp's own layers run on
## (time - start) / stretch; a shape layer's keyframes are in its comp's time.
func _layers(list: Array, frame: float, parent: Transform2D, parent_op: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var layer: Dictionary = list[i]
		if frame < float(layer.get("ip", -INF)) or frame >= float(layer.get("op", INF)):
			continue
		var ks: Dictionary = layer.get("ks", {})
		var op := parent_op * _num(ks.get("o"), frame, 100.0) / 100.0
		if op <= 0.002:
			continue
		var xf := parent * _transform(ks, frame)
		if absf(xf.determinant()) < 0.0000001:
			continue   # scaled to nothing
		match int(layer.get("ty", -1)):
			0:
				var sub = _assets.get(layer.get("refId", ""))
				if sub != null:
					var child := (frame - float(layer.get("st", 0.0))) / float(layer.get("sr", 1.0))
					_layers(sub, child, xf, op)
			4:
				_paint(_shapes(layer.get("shapes", []), frame, xf).paint, op)


## Anchor, position, scale, rotation: translate(p) * rotate(r) * scale(s) * translate(-a).
func _transform(ks: Dictionary, frame: float) -> Transform2D:
	var p := _vec(ks.get("p"), frame, Vector2.ZERO)
	var a := _vec(ks.get("a"), frame, Vector2.ZERO)
	var sc := _vec(ks.get("s"), frame, Vector2(100, 100)) / 100.0
	var r := deg_to_rad(_num(ks.get("r"), frame, 0.0))
	return Transform2D(r, sc, 0.0, p) * Transform2D(0.0, Vector2.ONE, 0.0, -a)


# --- Shapes ----------------------------------------------------------------------------

## Walks a shape list. Fills and strokes paint the paths before them (also those
## in earlier groups); trim paths cut them; earlier items are drawn on top.
## Returns {paint: [...] back to front, geoms: [...] for styles further out}.
func _shapes(items: Array, frame: float, parent: Transform2D) -> Dictionary:
	var xf := parent
	var op := 1.0
	for it in items:
		if str(it.get("ty", "")) == "tr":
			xf = parent * _transform(it, frame)
			op = _num(it.get("o"), frame, 100.0) / 100.0
	var geoms: Array = []
	var entries: Array = []   # [index, paint list]
	for i in items.size():
		var it: Dictionary = items[i]
		match str(it.get("ty", "")):
			"sh":
				geoms.append(_path_points(_path_at(it.get("ks", {}), frame), xf))
			"el":
				geoms.append(_ellipse_points(it, frame, xf))
			"gr":
				var sub := _shapes(it.get("it", []), frame, xf)
				geoms.append_array(sub.geoms)
				entries.append([i, sub.paint])
			"tm":
				geoms = _trim(geoms, it, frame)
			"fl":
				entries.append([i, [{"kind": "fill", "geoms": geoms.duplicate(),
						"color": _color(it.get("c"), frame), "op": op * _num(it.get("o"), frame, 100.0) / 100.0}]])
			"gf":
				entries.append([i, [{"kind": "gradient", "geoms": geoms.duplicate(), "fill": it,
						"xf": xf, "op": op * _num(it.get("o"), frame, 100.0) / 100.0, "frame": frame}]])
			"st":
				var grow := sqrt(absf(xf.determinant()))   # how much the shape is scaled up
				entries.append([i, [{"kind": "stroke", "geoms": geoms.duplicate(),
						"color": _color(it.get("c"), frame), "width": _num(it.get("w"), frame, 1.0) * grow,
						"round": int(it.get("lc", 1)) == 2, "op": op * _num(it.get("o"), frame, 100.0) / 100.0}]])
	var paint: Array = []
	for k in range(entries.size() - 1, -1, -1):
		paint.append_array(entries[k][1])
	return {"paint": paint, "geoms": geoms}


## A prepared path ({v, o, i} as points, handles made absolute) at a frame.
func _path_at(ks: Dictionary, frame: float) -> Dictionary:
	if int(ks.get("a", 0)) != 1:
		return ks.get("_p", {})
	var k: Array = ks.k
	if frame <= float(k[0].t):
		return k[0].get("_p", {})
	for i in range(k.size() - 1):
		var a: Dictionary = k[i]
		var b: Dictionary = k[i + 1]
		if frame < float(b.t):
			if int(a.get("h", 0)) == 1:
				return a.get("_p", {})
			var span := float(b.t) - float(a.t)
			var y := _ease(a, 0.0 if span <= 0.0 else (frame - float(a.t)) / span)
			return _lerp_path(a.get("_p", {}), b.get("_p", a.get("_pe", {})), y)
	var last: Dictionary = k[k.size() - 1]
	return last.get("_p", k[k.size() - 2].get("_pe", {}))


func _lerp_path(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	if a.is_empty() or b.is_empty():
		return a if not a.is_empty() else b
	var av: PackedVector2Array = a.v
	var ao: PackedVector2Array = a.o
	var ai: PackedVector2Array = a.i
	var bv: PackedVector2Array = b.v
	var bo: PackedVector2Array = b.o
	var bi: PackedVector2Array = b.i
	var n := mini(av.size(), bv.size())
	var v := PackedVector2Array()
	var o := PackedVector2Array()
	var i := PackedVector2Array()
	v.resize(n)
	o.resize(n)
	i.resize(n)
	for j in n:
		v[j] = av[j].lerp(bv[j], t)
		o[j] = ao[j].lerp(bo[j], t)
		i[j] = ai[j].lerp(bi[j], t)
	return {"v": v, "o": o, "i": i, "c": a.c}


## A path as screen points: each cubic segment flattened finely enough for its size.
func _path_points(path: Dictionary, xf: Transform2D) -> Dictionary:
	var pts := PackedVector2Array()
	if path.is_empty():
		return {"pts": pts, "closed": false}
	var v: PackedVector2Array = xf * (path.v as PackedVector2Array)
	var outs: PackedVector2Array = xf * (path.o as PackedVector2Array)
	var ins: PackedVector2Array = xf * (path.i as PackedVector2Array)
	var closed: bool = path.c
	var n := v.size()
	if n == 0:
		return {"pts": pts, "closed": closed}
	pts.append(v[0])
	var segs := n if closed else n - 1
	for k in segs:
		var k2 := (k + 1) % n
		var p0 := v[k]
		var p1 := outs[k]
		var p2 := ins[k2]
		var p3 := v[k2]
		if p1.is_equal_approx(p0) and p2.is_equal_approx(p3):
			pts.append(p3)
			continue
		var steps := clampi(int((p0.distance_to(p1) + p1.distance_to(p2) + p2.distance_to(p3)) / 2.5), 1, 32)
		for s in range(1, steps + 1):
			var t := float(s) / steps
			var u := 1.0 - t
			pts.append(p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t))
	return {"pts": pts, "closed": closed}


func _ellipse_points(it: Dictionary, frame: float, xf: Transform2D) -> Dictionary:
	var c := _vec(it.get("p"), frame, Vector2.ZERO)
	var r := _vec(it.get("s"), frame, Vector2.ZERO) / 2.0
	var pts := PackedVector2Array()
	var n := clampi(int((xf.basis_xform(r)).length() / 2.0), 16, 64)
	for k in n:
		var a := TAU * k / n
		pts.append(xf * (c + Vector2(cos(a) * r.x, sin(a) * r.y)))
	return {"pts": pts, "closed": true}


## Trim paths (each path on its own): keeps start..end percent, turned by offset.
func _trim(geoms: Array, it: Dictionary, frame: float) -> Array:
	var s := _num(it.get("s"), frame, 0.0) / 100.0
	var e := _num(it.get("e"), frame, 100.0) / 100.0
	var o := _num(it.get("o"), frame, 0.0) / 360.0
	if s > e:
		var swap := s
		s = e
		e = swap
	if e - s >= 0.9999:
		return geoms
	var out: Array = []
	for g in geoms:
		var pts: PackedVector2Array = g.pts
		if g.closed and pts.size() > 1:
			pts = pts.duplicate()
			pts.append(pts[0])
		var a := fposmod(s + o, 1.0)
		var b := a + (e - s)
		if b <= 1.0:
			out.append({"pts": _sub_path(pts, a, b), "closed": false})
		else:
			out.append({"pts": _sub_path(pts, a, 1.0), "closed": false})
			out.append({"pts": _sub_path(pts, 0.0, b - 1.0), "closed": false})
	return out


## The part of a polyline between two fractions of its length.
func _sub_path(pts: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		return out
	var total := 0.0
	for k in range(1, pts.size()):
		total += pts[k - 1].distance_to(pts[k])
	if total <= 0.0:
		return out
	var from := a * total
	var to := b * total
	var walked := 0.0
	for k in range(1, pts.size()):
		var seg := pts[k - 1].distance_to(pts[k])
		var next := walked + seg
		if next >= from and walked <= to and seg > 0.0:
			var t0 := clampf((from - walked) / seg, 0.0, 1.0)
			var t1 := clampf((to - walked) / seg, 0.0, 1.0)
			var q0 := pts[k - 1].lerp(pts[k], t0)
			if out.is_empty() or not out[out.size() - 1].is_equal_approx(q0):
				out.append(q0)
			out.append(pts[k - 1].lerp(pts[k], t1))
		walked = next
	return out


# --- Painting --------------------------------------------------------------------------

func _paint(list: Array, layer_op: float) -> void:
	for p in list:
		var op: float = p.op * layer_op
		if op <= 0.002:
			continue
		match p.kind:
			"fill":
				var col: Color = p.color
				col.a *= op
				for g in p.geoms:
					var pts := _clean(g.pts)
					var idx := _triangles(pts)
					if idx.is_empty():
						continue
					var ring := pts.duplicate()
					ring.append(pts[0])
					_out.append({"t": 0, "pts": pts, "idx": idx, "col": col, "soft": col.a >= 0.99, "ring": ring})
			"gradient":
				_gradient_fill(p, op)
			"stroke":
				var col: Color = p.color
				col.a *= op
				var w: float = p.width
				if w <= 0.05:
					continue
				for g in p.geoms:
					var pts := _clean(g.pts)
					if pts.size() == 0:
						continue
					if g.closed and pts.size() > 2:
						pts.append(pts[0])
					_out.append({"t": 2, "pts": pts, "col": col, "w": w, "round": p.round and not g.closed})


## A polygon cut into triangles; empty if it can't be filled (too small, or
## twisted mid-animation).
func _triangles(pts: PackedVector2Array) -> PackedInt32Array:
	if pts.size() < 3:
		return PackedInt32Array()
	return Geometry2D.triangulate_polygon(pts)


## A linear gradient: each point's place along the gradient axis (in the fill's
## own space) picks its color from a gradient texture. No soft edge here: the
## star's facets touch, and an edge would show as a seam between them.
func _gradient_fill(p: Dictionary, op: float) -> void:
	var it: Dictionary = p.fill
	var frame: float = p.frame
	var xf: Transform2D = p.xf
	if absf(xf.determinant()) < 0.0000001:
		return   # scaled to nothing: there is nothing to draw
	var start := _vec(it.get("s"), frame, Vector2.ZERO)
	var axis := _vec(it.get("e"), frame, Vector2(1, 0)) - start
	if axis.length_squared() < 0.0001:
		return
	var tex := _gradient(it, frame)
	var inv := xf.affine_inverse()
	for g in p.geoms:
		var pts := _clean(g.pts)
		if pts.size() < 3:
			continue
		var local: PackedVector2Array = inv * pts
		var uvs := PackedVector2Array()
		uvs.resize(pts.size())
		var len2 := axis.length_squared()
		for k in pts.size():
			uvs[k] = Vector2(clampf((local[k] - start).dot(axis) / len2, 0.0, 1.0), 0.5)
		var idx := _triangles(pts)
		if not idx.is_empty():
			_out.append({"t": 1, "pts": pts, "idx": idx, "col": Color(1, 1, 1, op), "uvs": uvs, "tex": tex})


func _gradient(it: Dictionary, frame: float) -> GradientTexture1D:
	var g: Dictionary = it.get("g", {})
	var n := int(g.get("p", 2))
	var raw: Array = _val(g.get("k"), frame)
	var key := str(raw) + str(n)
	if _gradients.has(key):
		return _gradients[key]
	var grad := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for k in n:
		offsets.append(float(raw[k * 4]))
		colors.append(Color(float(raw[k * 4 + 1]), float(raw[k * 4 + 2]), float(raw[k * 4 + 3])))
	# Optional opacity stops after the color stops: [offset, alpha] pairs.
	if raw.size() > n * 4:
		var alpha := Gradient.new()
		var a_off := PackedFloat32Array()
		var a_col := PackedColorArray()
		for k in range(n * 4, raw.size() - 1, 2):
			a_off.append(float(raw[k]))
			a_col.append(Color(1, 1, 1, float(raw[k + 1])))
		alpha.offsets = a_off
		alpha.colors = a_col
		for k in n:
			colors[k].a = alpha.sample(offsets[k]).a
	grad.offsets = offsets
	grad.colors = colors
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	tex.width = 256
	_gradients[key] = tex
	return tex


func _clean(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		if out.is_empty() or out[out.size() - 1].distance_squared_to(q) > 0.0025:
			out.append(q)
	if out.size() > 2 and out[0].distance_squared_to(out[out.size() - 1]) <= 0.0025:
		out.remove_at(out.size() - 1)
	return out


# --- Values and keyframes ----------------------------------------------------------------

## A property's value at a frame: static, or between two keyframes along the
## keyframe's bezier ease. Numbers and arrays interpolate.
func _val(prop, frame: float):
	if typeof(prop) != TYPE_DICTIONARY:
		return prop
	var k = prop.get("k")
	if int(prop.get("a", 0)) != 1 or typeof(k) != TYPE_ARRAY or k.is_empty() \
			or typeof(k[0]) != TYPE_DICTIONARY:
		return k
	if frame <= float(k[0].t):
		return k[0].get("s")
	for i in range(k.size() - 1):
		var a: Dictionary = k[i]
		var b: Dictionary = k[i + 1]
		if frame < float(b.t):
			if int(a.get("h", 0)) == 1:
				return a.get("s")
			var span := float(b.t) - float(a.t)
			var y := _ease(a, 0.0 if span <= 0.0 else (frame - float(a.t)) / span)
			return _mix(a.get("s"), b.get("s") if b.has("s") else a.get("e"), y)
	var last: Dictionary = k[k.size() - 1]
	return last.get("s") if last.has("s") else k[k.size() - 2].get("e")


func _mix(a, b, t: float):
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		var out := []
		for i in mini(a.size(), b.size()):
			out.append(_mix(a[i], b[i], t))
		return out
	if typeof(a) in [TYPE_FLOAT, TYPE_INT] and typeof(b) in [TYPE_FLOAT, TYPE_INT]:
		return lerpf(float(a), float(b), t)
	return a


## The keyframe's cubic-bezier ease: out handle (o) of this key, in handle (i)
## of the next. Finds the curve's x for the time (Newton steps), returns its y
## (which may overshoot, like a bounce).
func _ease(key: Dictionary, x: float) -> float:
	if not key.has("o") or not key.has("i"):
		return x
	var x1 := _first(key.o.get("x"), 0.0)
	var y1 := _first(key.o.get("y"), 0.0)
	var x2 := _first(key.i.get("x"), 1.0)
	var y2 := _first(key.i.get("y"), 1.0)
	var u := x
	for _n in 6:
		var dx := _bez(x1, x2, u) - x
		if absf(dx) < 0.0005:
			break
		var slope := 3.0 * (1.0 - u) * (1.0 - u) * x1 + 6.0 * (1.0 - u) * u * (x2 - x1) + 3.0 * u * u * (1.0 - x2)
		if absf(slope) < 0.000001:
			break
		u = clampf(u - dx / slope, 0.0, 1.0)
	return _bez(y1, y2, u)


func _bez(p1: float, p2: float, u: float) -> float:
	var v := 1.0 - u
	return 3.0 * v * v * u * p1 + 3.0 * v * u * u * p2 + u * u * u


func _first(v, fallback: float) -> float:
	if typeof(v) == TYPE_ARRAY:
		return float(v[0]) if not v.is_empty() else fallback
	if typeof(v) in [TYPE_FLOAT, TYPE_INT]:
		return float(v)
	return fallback


func _num(prop, frame: float, fallback: float) -> float:
	if prop == null:
		return fallback
	return _first(_val(prop, frame), fallback)


func _vec(prop, frame: float, fallback: Vector2) -> Vector2:
	if typeof(prop) != TYPE_DICTIONARY:
		return fallback
	if prop.get("s", false):   # position split into x and y
		return Vector2(_num(prop.get("x"), frame, fallback.x), _num(prop.get("y"), frame, fallback.y))
	var v = _val(prop, frame)
	if typeof(v) == TYPE_ARRAY and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if typeof(v) in [TYPE_FLOAT, TYPE_INT]:
		return Vector2(float(v), float(v))
	return fallback


func _color(prop, frame: float) -> Color:
	var v = _val(prop, frame)
	if typeof(v) == TYPE_ARRAY and v.size() >= 3:
		return Color(clampf(v[0], 0.0, 1.0), clampf(v[1], 0.0, 1.0), clampf(v[2], 0.0, 1.0))
	return Color.WHITE


# --- Preparing a file --------------------------------------------------------------------

## Turns every path ({v, i, o} as nested lists) into point arrays with absolute
## handles, once per file, so frames only blend and transform them.
static func _prepare(node) -> void:
	if typeof(node) == TYPE_ARRAY:
		for item in node:
			_prepare(item)
		return
	if typeof(node) != TYPE_DICTIONARY:
		return
	# Layers keep their type as a number, shapes as text.
	if str(node.get("ty", "")) == "sh" and typeof(node.get("ks")) == TYPE_DICTIONARY:
		var ks: Dictionary = node.ks
		var k = ks.get("k")
		if int(ks.get("a", 0)) == 1 and typeof(k) == TYPE_ARRAY:
			for key in k:
				if typeof(key) != TYPE_DICTIONARY:
					continue
				if typeof(key.get("s")) == TYPE_ARRAY and not key.s.is_empty():
					key["_p"] = _compact(key.s[0])
				if typeof(key.get("e")) == TYPE_ARRAY and not key.e.is_empty():
					key["_pe"] = _compact(key.e[0])
		elif typeof(k) == TYPE_DICTIONARY:
			ks["_p"] = _compact(k)
		return
	for value in node.values():
		_prepare(value)


static func _compact(shape) -> Dictionary:
	if typeof(shape) != TYPE_DICTIONARY:
		return {}
	var v := PackedVector2Array()
	var o := PackedVector2Array()
	var i := PackedVector2Array()
	var vs: Array = shape.get("v", [])
	var os: Array = shape.get("o", [])
	var ins: Array = shape.get("i", [])
	for j in vs.size():
		var p := Vector2(float(vs[j][0]), float(vs[j][1]))
		v.append(p)
		o.append(p + (Vector2(float(os[j][0]), float(os[j][1])) if j < os.size() else Vector2.ZERO))
		i.append(p + (Vector2(float(ins[j][0]), float(ins[j][1])) if j < ins.size() else Vector2.ZERO))
	return {"v": v, "o": o, "i": i, "c": bool(shape.get("c", false))}


# --- Recoloring ------------------------------------------------------------------------

## Swaps colors in fills, strokes and gradient stops, keyframes included.
static func _recolor(node, colors: Dictionary) -> void:
	if typeof(node) == TYPE_ARRAY:
		for item in node:
			_recolor(item, colors)
		return
	if typeof(node) != TYPE_DICTIONARY:
		return
	var ty := str(node.get("ty", ""))
	if ty in ["fl", "st"] and typeof(node.get("c")) == TYPE_DICTIONARY:
		_recolor_prop(node.c, colors)
	if ty in ["gf", "gs"] and typeof(node.get("g")) == TYPE_DICTIONARY:
		var g: Dictionary = node.g
		var n := int(g.get("p", 0))
		var k = g.get("k", {}).get("k")
		if typeof(k) == TYPE_ARRAY and k.size() >= n * 4 and (k.is_empty() or typeof(k[0]) != TYPE_DICTIONARY):
			for s in n:
				var c := _swap(Color(k[s * 4 + 1], k[s * 4 + 2], k[s * 4 + 3]), colors)
				k[s * 4 + 1] = c.r
				k[s * 4 + 2] = c.g
				k[s * 4 + 3] = c.b
	for value in node.values():
		_recolor(value, colors)


static func _recolor_prop(prop: Dictionary, colors: Dictionary) -> void:
	var k = prop.get("k")
	if typeof(k) != TYPE_ARRAY or k.is_empty():
		return
	if typeof(k[0]) == TYPE_DICTIONARY:
		for key in k:
			for side in ["s", "e"]:
				if typeof(key.get(side)) == TYPE_ARRAY and key[side].size() >= 3:
					_swap_array(key[side], colors)
	elif k.size() >= 3:
		_swap_array(k, colors)


static func _swap_array(arr: Array, colors: Dictionary) -> void:
	var c := _swap(Color(arr[0], arr[1], arr[2]), colors)
	arr[0] = c.r
	arr[1] = c.g
	arr[2] = c.b


static func _swap(c: Color, colors: Dictionary) -> Color:
	for from in colors:
		var f: Color = from
		if absf(f.r - c.r) < 0.02 and absf(f.g - c.g) < 0.02 and absf(f.b - c.b) < 0.02:
			return colors[from]
	return c
