class_name PathNode
extends BaseButton
## One round node on the learning path (D-007): a chunky circle that sinks when
## pressed. The current node bounces under a "START" bubble.

const DEPTH := 10.0
const RADIUS := 62.0
const GOLD := Color("ffc531")
const LOCKED := Color("d9d2c5")
const PRACTICE := Color("3fa7d6")

var kind := "lesson"        # lesson | chest | trophy
var state := "locked"
var world_color := Color("6bbf59")
var bob := 0.0:
	set(v):
		bob = v
		queue_redraw()

var _font: Font


func setup(p_kind: String, p_state: String, p_world_color: Color) -> void:
	kind = p_kind
	state = p_state
	world_color = p_world_color
	custom_minimum_size = Vector2(200, 210)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if state in ["current", "practice"]:
		var t := create_tween().set_loops()
		t.tween_property(self, "bob", -10.0, 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_property(self, "bob", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	queue_redraw()


func _ready() -> void:
	_font = get_theme_default_font()
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _face() -> Color:
	match state:
		"done", "won", "open", "bonus_done":
			return GOLD
		"current", "ready":
			return world_color
		"practice":
			return PRACTICE
		"bonus":
			return GOLD.lightened(0.45)
	return LOCKED


func _icon() -> String:
	if kind == "chest":
		return "🎁" if state != "open" else "💰"
	if kind == "trophy":
		return "🏆"
	match state:
		"done":
			return "⭐"
		"current":
			return "📖"
		"practice":
			return "🔁"
		"bonus":
			return "✨"
		"bonus_done":
			return "🌟"
	return "🔒"


func _draw() -> void:
	var c := Vector2(size.x / 2.0, size.y - RADIUS - DEPTH - 4 + bob)
	var pressed := get_draw_mode() == DRAW_PRESSED
	var sink := DEPTH - 2.0 if pressed else 0.0
	var face := _face()
	if state in ["current", "practice", "ready"]:
		draw_arc(c + Vector2(0, DEPTH / 2), RADIUS + 14, 0, TAU, 64, face.lightened(0.5), 10, true)
	draw_circle(c + Vector2(0, DEPTH), RADIUS, face.darkened(0.25))
	draw_circle(c + Vector2(0, sink), RADIUS, face)
	draw_circle(c + Vector2(-RADIUS * 0.3, -RADIUS * 0.35 + sink), RADIUS * 0.22,
			Color(1, 1, 1, 0.25))
	var dim := 0.45 if state == "locked" and kind != "lesson" else 1.0
	_text(_icon(), c + Vector2(0, sink + 20), 56, Color(1, 1, 1, dim))
	if state == "current":
		_bubble("START", c + Vector2(0, -RADIUS - 34))
	elif state == "practice":
		_bubble("PRACTICE", c + Vector2(0, -RADIUS - 34))


func _bubble(text: String, at: Vector2) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 32
	var r := Rect2(at - Vector2(w / 2, 26), Vector2(w, 46))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = Color("e8dcc3")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	draw_style_box(sb, r)
	_text(text, at + Vector2(0, 7), 26, _face().darkened(0.2))


func _text(text: String, center_baseline: Vector2, font_size: int, color: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, center_baseline - Vector2(w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, color)
