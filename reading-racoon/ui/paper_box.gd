@tool
class_name PaperBox
extends StyleBox
## A box cut from paper. It takes the same settings as StyleBoxFlat (colour, corners, a crisp
## shadow, a border or a lighter top lip, expand margins), but its edge looks hand-cut: corners a
## little uneven and sides gently wavy, so cards, buttons and discs look like paper instead of
## perfect rectangles. Circles and pills (every corner fully round) stay perfectly round.
## Big boxes can be stitched round the inside, like the path's stops.
##
## Each box keeps its own cut (`cut`), and a shape is worked out once per size, so drawing is cheap.

@export var bg_color := Color(0.6, 0.6, 0.6):
	set(v):
		bg_color = v
		emit_changed()
@export var draw_center := true:
	set(v):
		draw_center = v
		emit_changed()
@export var border_color := Color(0.8, 0.8, 0.8):
	set(v):
		border_color = v
		emit_changed()
@export var border_width_left := 0:
	set(v):
		border_width_left = v
		emit_changed()
@export var border_width_top := 0:
	set(v):
		border_width_top = v
		emit_changed()
@export var border_width_right := 0:
	set(v):
		border_width_right = v
		emit_changed()
@export var border_width_bottom := 0:
	set(v):
		border_width_bottom = v
		emit_changed()
@export var corner_radius_top_left := 0:
	set(v):
		corner_radius_top_left = v
		emit_changed()
@export var corner_radius_top_right := 0:
	set(v):
		corner_radius_top_right = v
		emit_changed()
@export var corner_radius_bottom_right := 0:
	set(v):
		corner_radius_bottom_right = v
		emit_changed()
@export var corner_radius_bottom_left := 0:
	set(v):
		corner_radius_bottom_left = v
		emit_changed()
@export var shadow_color := Color(0, 0, 0, 0.6):
	set(v):
		shadow_color = v
		emit_changed()
## Kept for StyleBoxFlat's settings; paper shadows are crisp, so it isn't used.
@export var shadow_size := 0
@export var shadow_offset := Vector2.ZERO:
	set(v):
		shadow_offset = v
		emit_changed()
@export var expand_margin_left := 0.0:
	set(v):
		expand_margin_left = v
		emit_changed()
@export var expand_margin_top := 0.0:
	set(v):
		expand_margin_top = v
		emit_changed()
@export var expand_margin_right := 0.0:
	set(v):
		expand_margin_right = v
		emit_changed()
@export var expand_margin_bottom := 0.0:
	set(v):
		expand_margin_bottom = v
		emit_changed()
## Kept for StyleBoxFlat's settings; the edge is always smoothed.
@export var anti_aliasing := true
## How far the cut wanders from a straight line, in px; below 0 it grows with the box (0.8 to 3).
@export var wobble := -1.0:
	set(v):
		wobble = v
		emit_changed()
## Sews a dashed stitch round the inside of a box at least 96 px across.
@export var stitch := false:
	set(v):
		stitch = v
		emit_changed()
## Which hand-cut shape this box has. Copies keep it, so a button keeps its shape as it's pressed.
@export var cut := 0:
	set(v):
		cut = v
		emit_changed()

const STEP := 10.0            # px between points along a straight side
const CORNER_VARY := 0.2      # how uneven the corners are
const STITCH_DASH := 8.0
const STITCH_GAP := 6.0

var _shapes := {}


func _init() -> void:
	cut = randi() % 100000


func set_corner_radius_all(r: int) -> void:
	corner_radius_top_left = r
	corner_radius_top_right = r
	corner_radius_bottom_right = r
	corner_radius_bottom_left = r


func set_border_width_all(w: int) -> void:
	border_width_left = w
	border_width_top = w
	border_width_right = w
	border_width_bottom = w


func set_expand_margin_all(m: float) -> void:
	expand_margin_left = m
	expand_margin_top = m
	expand_margin_right = m
	expand_margin_bottom = m


func _get_draw_rect(rect: Rect2) -> Rect2:
	var r := rect.grow_individual(expand_margin_left, expand_margin_top, expand_margin_right, expand_margin_bottom)
	return r.merge(Rect2(r.position + shadow_offset, r.size))


func _draw(ci: RID, rect: Rect2) -> void:
	var r := rect.grow_individual(expand_margin_left, expand_margin_top, expand_margin_right, expand_margin_bottom)
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	var shape := _shape(r.size)
	if shadow_color.a > 0.0 and shadow_offset != Vector2.ZERO:
		_fill(ci, shape, r.position + shadow_offset, shadow_color)
	if draw_center and bg_color.a > 0.0:
		_fill(ci, shape, r.position, bg_color)
	_draw_border(ci, shape, r.position)
	if stitch and minf(r.size.x, r.size.y) >= 96.0 and draw_center:
		_draw_stitch(ci, shape, r)


func _fill(ci: RID, shape: Dictionary, at: Vector2, col: Color) -> void:
	var fill: PackedVector2Array = shape.fill
	var p := PackedVector2Array()
	p.resize(fill.size())
	for i in fill.size():
		p[i] = fill[i] + at
	RenderingServer.canvas_item_add_triangle_array(ci, shape.idx, p, PackedColorArray([col]))
	# a 1 px smoothed line along the cut, so its edge isn't jagged
	p[p.size() - 1] = p[0]
	RenderingServer.canvas_item_add_polyline(ci, p, PackedColorArray([col]), 1.0, true)


## A full border round the cut, or (StyleBoxFlat's "lip") only along its top.
func _draw_border(ci: RID, shape: Dictionary, at: Vector2) -> void:
	var w := maxi(maxi(border_width_left, border_width_right), border_width_bottom)
	var pts: PackedVector2Array = shape.pts
	var nor: PackedVector2Array = shape.nor
	if w > 0 and border_color.a > 0.0:
		var ring := PackedVector2Array()
		for i in pts.size():
			ring.append(pts[i] + at - nor[i] * w * 0.5)
		ring.append(ring[0])
		RenderingServer.canvas_item_add_polyline(ci, ring, PackedColorArray([border_color]), w, true)
	elif border_width_top > 0 and border_color.a > 0.0:
		var lip := PackedVector2Array()
		for i in pts.size():
			if nor[i].y < -0.55:
				lip.append(pts[i] + at - nor[i] * border_width_top * 0.5)
		if lip.size() > 1:
			RenderingServer.canvas_item_add_polyline(ci, lip, PackedColorArray([border_color]), border_width_top, true)


## A sewn line just inside the edge: dashes in a deeper (or, on a dark colour, lighter) thread.
func _draw_stitch(ci: RID, shape: Dictionary, r: Rect2) -> void:
	var inset := clampf(minf(r.size.x, r.size.y) * 0.07, 7.0, 12.0)
	var pts: PackedVector2Array = shape.pts
	var nor: PackedVector2Array = shape.nor
	var line := PackedVector2Array()
	for i in pts.size():
		line.append(pts[i] + r.position - nor[i] * inset)
	line.append(line[0])
	var thread := bg_color.darkened(0.3) if bg_color.get_luminance() > 0.55 else bg_color.lightened(0.55)
	thread.a = 0.55
	var segs := PackedVector2Array()
	var t := 0.0     # where along the dash-and-gap pattern we are
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var length := a.distance_to(b)
		var done := 0.0
		while done < length:
			var cycle := fmod(t, STITCH_DASH + STITCH_GAP)
			var on := cycle < STITCH_DASH
			var left := (STITCH_DASH - cycle) if on else (STITCH_DASH + STITCH_GAP - cycle)
			var step := minf(left, length - done)
			if on:
				segs.append(a.lerp(b, done / length))
				segs.append(a.lerp(b, (done + step) / length))
			done += step
			t += step
	if segs.size() > 1:
		RenderingServer.canvas_item_add_multiline(ci, segs, PackedColorArray([thread]), 2.2, true)


## The hand-cut outline for a box of this size: points and their outward normals, plus the fill as a
## fan of triangles from the middle (the cut is nearly round, so the fan always fits inside).
func _shape(size: Vector2) -> Dictionary:
	var key := "%d|%d|%d|%d|%d|%d|%d|%.2f" % [roundi(size.x * 2), roundi(size.y * 2), corner_radius_top_left,
			corner_radius_top_right, corner_radius_bottom_right, corner_radius_bottom_left, cut, wobble]
	if _shapes.has(key):
		return _shapes[key]
	if _shapes.size() > 24:
		_shapes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = cut
	var half := minf(size.x, size.y) / 2.0
	var asked: Array[int] = [corner_radius_top_left, corner_radius_top_right, corner_radius_bottom_right,
			corner_radius_bottom_left]
	# a circle or a pill (every corner fully round) stays perfectly round
	var is_round := true
	for c in asked:
		if float(c) < half - 0.5:
			is_round = false
	var radii: Array[float] = []
	for c in asked:
		var vary := 0.0 if is_round else rng.randf_range(-CORNER_VARY, CORNER_VARY)
		radii.append(clampf(float(c) * (1.0 + vary), 0.0, half))
	# small boxes (lines, chips' dots) stay true; bigger ones wander up to 3 px
	var amp := wobble if wobble >= 0.0 else (0.0 if half < 12.0 else clampf(half * 0.035, 0.8, 3.0))
	if is_round:
		amp = 0.0
	var k: Array[int] = [3 + rng.randi_range(0, 1), 5 + rng.randi_range(0, 2), 11]
	var ph: Array[float] = [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	# the outline, clockwise from the top-left corner: four corners, each followed by its side
	var pts := PackedVector2Array()
	var nor := PackedVector2Array()
	var centers: Array[Vector2] = [Vector2(radii[0], radii[0]), Vector2(size.x - radii[1], radii[1]),
			Vector2(size.x - radii[2], size.y - radii[2]), Vector2(radii[3], size.y - radii[3])]
	var sides: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for i in 4:
		var rad := radii[i]
		var c := centers[i]
		if rad > 0.5:
			var a0 := PI + i * PI / 2.0
			var n := maxi(3, ceili(rad * 0.4))
			for j in n + 1:
				var d := Vector2.from_angle(a0 + (PI / 2.0) * j / n)
				pts.append(c + d * rad)
				nor.append(d)
		else:
			pts.append(c)
			nor.append((sides[i] + sides[(i + 3) % 4]).normalized())
		var s0 := c + sides[i] * rad
		var s1 := centers[(i + 1) % 4] + sides[i] * radii[(i + 1) % 4]
		var steps := floori(s0.distance_to(s1) / STEP)
		for j in range(1, steps):
			pts.append(s0.lerp(s1, float(j) / steps))
			nor.append(sides[i])
	# wander every point along its normal by a smooth wave that closes on itself
	var along := PackedFloat32Array([0.0])
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
		along.append(total)
	total += pts[0].distance_to(pts[pts.size() - 1])
	if amp > 0.0:
		for i in pts.size():
			var s := along[i] / total
			var wave := 0.55 * sin(TAU * k[0] * s + ph[0]) + 0.3 * sin(TAU * k[1] * s + ph[1]) 					+ 0.15 * sin(TAU * k[2] * s + ph[2])
			pts[i] += nor[i] * wave * amp
	var fill := pts.duplicate()
	fill.append(size / 2.0)
	var mid := pts.size()
	var idx := PackedInt32Array()
	for i in mid:
		idx.append_array([mid, i, (i + 1) % mid])
	var shape := {"pts": pts, "nor": nor, "fill": fill, "idx": idx}
	_shapes[key] = shape
	return shape
