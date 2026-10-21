class_name PathNode
extends BaseButton
## One stop on the learning path (D-007, D-009): a paper disc with a stitched
## ring and an SVG icon, lifted on a shadow; it presses flat when tapped. The
## current node pulses under a paper "START" tag.

const LIFT := 9.0
const SIZE := Vector2(200, 190)

var kind := "lesson"        # lesson | chest | trophy
var state := "locked"
var world_color := Palette.TEAL
var bob := 0.0:
	set(v):
		bob = v
		queue_redraw()
var pulse := 0.0:
	set(v):
		pulse = v
		queue_redraw()

var _font: Font


func setup(p_kind: String, p_state: String, p_world_color: Color) -> void:
	kind = p_kind
	state = p_state
	world_color = p_world_color
	custom_minimum_size = SIZE
	size = SIZE
	if state in ["current", "practice"]:
		var t := create_tween().set_loops()
		t.tween_property(self, "bob", -8.0, 0.55).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(self, "pulse", 1.0, 0.55)
		t.tween_property(self, "bob", 0.0, 0.55).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(self, "pulse", 0.0, 0.55)
	elif kind == "chest" and state == "ready":
		var t := create_tween().set_loops()
		t.tween_interval(1.2)
		for d in [-1.0, 1.0, -1.0, 0.0]:
			t.tween_property(self, "bob", d * 3.0, 0.07)
	queue_redraw()


func _ready() -> void:
	_font = get_theme_default_font()
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func radius() -> float:
	return 70.0 if kind == "trophy" else 60.0


## Center of the disc in local coordinates (used to draw the trail).
func disc_center() -> Vector2:
	return Vector2(size.x / 2.0, size.y - radius() - LIFT - 6)


func _face() -> Color:
	match state:
		"done", "won", "bonus_done":
			return Palette.MANGO
		"current":
			return world_color
		"ready":
			return Palette.CORAL
		"practice":
			return Palette.BAY
		"bonus", "open":
			return Palette.CARD
	return Palette.PAPER_DEEP


func _icon() -> String:
	match kind:
		"chest":
			return "chest_open" if state == "open" else "chest"
		"trophy":
			return "trophy"
	match state:
		"done":
			return "star"
		"current":
			return "book"
		"practice":
			return "repeat"
		"bonus", "bonus_done":
			return "sparkles"
	return "lock"


func _icon_color() -> Color:
	match state:
		"locked":
			return Color(Palette.INK_SOFT, 0.55)
		"bonus":
			return Palette.MANGO_DEEP
		"open":
			return Palette.NIPA
	return Palette.text_on(_face())


func _draw() -> void:
	var r := radius()
	var c := disc_center() + Vector2(0, bob)
	var is_down := get_draw_mode() == DRAW_PRESSED
	var sink := LIFT - 2.0 if is_down else 0.0
	var face := _face()
	if state in ["current", "practice"]:
		draw_circle(c + Vector2(0, LIFT * 0.5), r + 16 + pulse * 6, Color(face, 0.16 + pulse * 0.08))
	# Shadow, face, cut-paper top lip, stitched ring.
	draw_circle(c + Vector2(0, LIFT), r, Palette.SHADOW)
	draw_circle(c + Vector2(0, sink), r, face)
	draw_arc(c + Vector2(0, sink), r - 2, PI * 1.12, PI * 1.88, 24, face.lightened(0.22), 4.0, true)
	if state == "bonus":
		draw_arc(c + Vector2(0, sink), r - 1, 0, TAU, 48, Palette.MANGO, 3.0, true)
	var stitch := Color(1, 1, 1, 0.45) if state not in ["locked", "bonus", "open"] \
			else Color(Palette.INK_SOFT, 0.25)
	for i in 18:
		var a := TAU * i / 18.0
		draw_arc(c + Vector2(0, sink), r - 11, a, a + TAU / 36.0, 4, stitch, 3.0, true)
	Icons.draw(self, _icon(), c + Vector2(0, sink), r * 0.95, _icon_color())
	if kind == "trophy" and state == "won":
		Icons.draw(self, "crown", c + Vector2(0, sink - r - 6), 44, Palette.MANGO_DEEP)
	if state == "current":
		_tag("START", c + Vector2(0, -r - 30 + sink))
	elif state == "practice":
		_tag("PRACTICE", c + Vector2(0, -r - 30 + sink))


## A small paper tag with a pointer, above the node.
func _tag(text: String, at: Vector2) -> void:
	var fs := 24
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 34
	var rect := Rect2(at - Vector2(w / 2, 24), Vector2(w, 44))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(Palette.SHADOW, 0.2)
	sb.shadow_offset = Vector2(0, 4)
	sb.shadow_size = 1
	draw_style_box(sb, rect)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-10, 19), at + Vector2(10, 19),
			at + Vector2(0, 31)]), Palette.CARD)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, at + Vector2(-tw / 2, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Palette.deep(_face()))
