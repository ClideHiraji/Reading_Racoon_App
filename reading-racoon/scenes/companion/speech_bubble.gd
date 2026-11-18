class_name SpeechBubble
extends PanelContainer
## The raccoon's speech bubble: a paper card with a little tail pointing at the
## speaker (D-009). Lines pop in; keep them short (companion guardrails,
## docs/knowledge/06-game-design.md).
##
## Its point always points at Racoon (D-024): at his head, from whichever edge of the bubble faces
## him, on every screen. The screen can name him (`speaker`); otherwise the bubble finds the
## nearest Racoon on the screen. When he walks about (his own moves on Home, the start screen and
## the Closet) the bubble goes with him, kept inside its box (the nearest parent that clips, else
## the screen).

## Where the tail points from when there's no Racoon on the screen: "left", "down" or "up".
@export_enum("left", "down", "up") var tail := "left"
## Where an "up" or "down" tail starts then, from the bubble's left edge.
@export var tail_x := 36.0
## The Racoon who's speaking.
var speaker: Raccoon = null

const TAIL_HALF := 13.0    # half the tail's width where it meets the bubble
const TAIL_REACH := 24.0   # how far the tail sticks out
const CORNER := 22.0       # the bubble's round corners: the tail stays off them

var _label: Label
var _home := Vector2.INF       # where the screen's layout put the bubble
var _moved_to := Vector2.INF   # where the bubble was last moved to
var _tail_pts := PackedVector2Array()   # the tail as aimed at the speaker
var _look_in := 0              # frames until the next look for a Racoon on the screen


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(int(CORNER))
	sb.shadow_color = Color(Palette.SHADOW, 0.18)
	sb.shadow_offset = Vector2(0, 5)
	sb.shadow_size = 1
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 28)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(220, 0)
	add_child(_label)
	modulate.a = 0.0


func _process(_delta: float) -> void:
	if speaker != null and not is_instance_valid(speaker):
		speaker = null
	if speaker == null:
		_look_in -= 1
		if _look_in <= 0 and is_visible_in_tree():
			_look_in = 30
			speaker = _find_speaker()
		if speaker == null:
			if not _tail_pts.is_empty():
				_tail_pts = PackedVector2Array()
				queue_redraw()
			return
	_walk_with(speaker)
	_aim_at(speaker)


## The nearest Racoon on the screen who isn't a still picture (the Closet's cards).
func _find_speaker() -> Raccoon:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var best: Raccoon = null
	var best_d := INF
	var me := get_global_rect().get_center()
	for n in scene.find_children("*", "Control", true, false):
		var r := n as Raccoon
		if r and not r.still and r.is_visible_in_tree():
			var d := r.get_global_rect().get_center().distance_to(me)
			if d < best_d:
				best = r
				best_d = d
	return best


## Goes along with his walk, inside its box.
func _walk_with(r: Raccoon) -> void:
	# the layout (a container, or the screen placing it) moved the bubble: that's its home now
	if _moved_to == Vector2.INF or not position.is_equal_approx(_moved_to):
		_home = position
	var parent_scale := 1.0
	var parent := get_parent() as CanvasItem
	if parent:
		parent_scale = maxf(absf(parent.get_global_transform().get_scale().x), 0.001)
	var want := r.walk_offset() / parent_scale
	if is_zero_approx(want) and position.is_equal_approx(_home):
		_moved_to = position
		return
	var box := get_viewport_rect()
	var n := get_parent()
	while n is CanvasItem:
		var c := n as Control
		if c and (c.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED or c.clip_contents):
			box = c.get_global_rect()
			break
		n = n.get_parent()
	var home_global := (parent.get_global_transform() * _home) if parent else _home
	var lo := (box.position.x + 8.0 - home_global.x) / parent_scale
	var hi := (box.end.x - 8.0 - home_global.x - size.x * parent_scale) / parent_scale
	position = _home + Vector2(clampf(want, minf(lo, 0.0), maxf(hi, 0.0)), 0.0)
	_moved_to = position


## Points the tail at his head, from the edge of the bubble that faces him.
func _aim_at(r: Raccoon) -> void:
	var t := get_global_transform_with_canvas().affine_inverse() * r.speak_point()
	var w := size.x
	var h := size.y
	var d := t - size / 2.0
	var pts: PackedVector2Array
	if absf(d.y) / maxf(h, 1.0) >= absf(d.x) / maxf(w, 1.0):
		# above or below him: the tail comes out of the bottom (or the top)
		var down := d.y > 0.0
		var base := Vector2(clampf(t.x, CORNER + TAIL_HALF, maxf(CORNER + TAIL_HALF, w - CORNER - TAIL_HALF)),
				h - 2.0 if down else 2.0)
		var dir := (t - base).normalized()
		dir.y = maxf(dir.y, 0.45) if down else minf(dir.y, -0.45)
		pts = PackedVector2Array([base - Vector2(TAIL_HALF, 0), base + Vector2(TAIL_HALF, 0),
				base + dir.normalized() * TAIL_REACH])
	else:
		# beside him: the tail comes out of the side that faces him
		var right := d.x > 0.0
		var base := Vector2(w - 2.0 if right else 2.0,
				clampf(t.y, CORNER + TAIL_HALF, maxf(CORNER + TAIL_HALF, h - CORNER - TAIL_HALF)))
		var dir := (t - base).normalized()
		dir.x = maxf(dir.x, 0.45) if right else minf(dir.x, -0.45)
		pts = PackedVector2Array([base - Vector2(0, TAIL_HALF), base + Vector2(0, TAIL_HALF),
				base + dir.normalized() * TAIL_REACH])
	var changed := pts.size() != _tail_pts.size()
	if not changed:
		for i in pts.size():
			if pts[i].distance_squared_to(_tail_pts[i]) > 0.25:
				changed = true
				break
	if changed:
		_tail_pts = pts
		queue_redraw()


func _draw() -> void:
	if not _tail_pts.is_empty():
		Smooth.polygon(self, _tail_pts, Palette.CARD)
		return
	var pts: PackedVector2Array
	match tail:
		"down":
			pts = PackedVector2Array([Vector2(tail_x, size.y - 2), Vector2(tail_x + 28, size.y - 2),
					Vector2(tail_x - 6, size.y + 22)])
		"up":
			pts = PackedVector2Array([Vector2(tail_x, 2), Vector2(tail_x + 28, 2), Vector2(tail_x - 2, -20)])
		_:
			pts = PackedVector2Array([Vector2(2, size.y * 0.5 - 14), Vector2(2, size.y * 0.5 + 12),
					Vector2(-20, size.y * 0.5 + 8)])
	Smooth.polygon(self, pts, Palette.CARD)


func say(text: String) -> void:
	if text.is_empty():
		hide_bubble()
		return
	_label.text = text
	queue_redraw()
	pivot_offset = Vector2(0, size.y)
	scale = Vector2(0.85, 0.85)
	var t := create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 1.0, 0.12)
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func hide_bubble() -> void:
	create_tween().tween_property(self, "modulate:a", 0.0, 0.12)
