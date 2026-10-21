@tool
class_name PlayButton
extends Button
## The hub's big PLAY button (D-015): a slanted gold paper card, like a game
## lobby's main button. Lifted on a shadow, it sinks when pressed and glows
## softly to say "start here". Put the labels in a child named "Content".
## A flat Button with no text: all of its look is drawn here.

@export var face_color := Palette.MANGO:
	set(v):
		face_color = v
		queue_redraw()
@export var lift := 10:
	set(v):
		lift = v
		queue_redraw()
## How far the top-left corner leans in, as a share of the width.
@export_range(0.0, 0.4) var lean := 0.16:
	set(v):
		lean = v
		queue_redraw()
@export var glow := true

var _pulse := 0.0:
	set(v):
		_pulse = v
		queue_redraw()
var _rest_y := 0.0


func _ready() -> void:
	flat = true
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if Engine.is_editor_hint():
		return
	button_down.connect(_sink.bind(true))
	button_up.connect(_sink.bind(false))
	if glow:
		var t := create_tween().set_loops()
		t.tween_property(self, "_pulse", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
		t.tween_property(self, "_pulse", 0.0, 1.1).set_trans(Tween.TRANS_SINE)


func _sink(down: bool) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if down and sfx:
		sfx.play("tap")
	queue_redraw()
	var content := get_node_or_null("Content") as Control
	if content:
		if down:
			_rest_y = content.position.y
			content.position.y = _rest_y + lift - 2
		else:
			content.position.y = _rest_y


func _draw() -> void:
	var down := get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED]
	var sink := float(lift - 2) if down else 0.0
	var w := size.x
	var h := size.y - lift
	var card := _shape(Rect2(0, sink, w, h), 0.0)
	if _pulse > 0.0:
		var halo := _shape(Rect2(-8, sink - 8, w + 16, h + 16), 0.0)
		draw_colored_polygon(halo, Color(Palette.MANGO, 0.22 * _pulse))
	draw_colored_polygon(_shape(Rect2(0, lift, w, h), 0.0), Palette.SHADOW)
	draw_colored_polygon(card, Palette.CARD)
	var face := _shape(Rect2(0, sink, w, h), 7.0)
	var top := face_color.lightened(0.22)
	var bottom := face_color.darkened(0.12)
	draw_polygon(face, PackedColorArray([top, top, bottom, bottom]))
	# A lighter cut edge along the top, like folded paper.
	var lip := PackedVector2Array([face[0], face[1], face[1] + Vector2(0, 8),
			face[0] + Vector2(-lean * 8.0, 8)])
	draw_colored_polygon(lip, face_color.lightened(0.4))


## The slanted card inside `r`, shrunk by `inset` px on every side.
## Points: top-left, top-right, bottom-right, bottom-left.
func _shape(r: Rect2, inset: float) -> PackedVector2Array:
	var lx := r.size.x * lean
	var top_y := r.position.y + inset
	var bot_y := r.end.y - inset
	var slide := inset * 1.1
	return PackedVector2Array([
		Vector2(r.position.x + lx * (1.0 - (top_y - r.position.y) / r.size.y) + slide, top_y),
		Vector2(r.end.x - inset, top_y),
		Vector2(r.end.x - inset, bot_y),
		Vector2(r.position.x + lx * (r.end.y - bot_y) / r.size.y + slide, bot_y),
	])


## Taps count only on the card, not the empty corner the slant leaves.
func _has_point(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, _shape(Rect2(0, 0, size.x, size.y), 0.0))
