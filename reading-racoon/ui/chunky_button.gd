@tool
class_name ChunkyButton
extends Button
## Big tactile "3D" button with a darker bottom edge that sinks when pressed
## (D-007 design direction). NFR-02: keep custom_minimum_size >= 96 px (48 dp).

const INK := Color("3d2e1f")
const CARD_EDGE := Color("e8dcc3")

@export var face_color := Color("6bbf59"):
	set(v):
		face_color = v
		_restyle()
## White card style with a light border and dark text (answer cards).
@export var card_style := false:
	set(v):
		card_style = v
		_restyle()
@export var depth := 8:
	set(v):
		depth = v
		_restyle()
@export var radius := 24:
	set(v):
		radius = v
		_restyle()
@export var tap_sound := true


func _ready() -> void:
	_restyle()
	if not Engine.is_editor_hint():
		button_down.connect(_on_down)


func _on_down() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if tap_sound and sfx:
		sfx.play("tap")


func _restyle() -> void:
	var face := Color.WHITE if card_style else face_color
	var edge := CARD_EDGE if card_style else face_color.darkened(0.25)
	var sink := depth - 2
	add_theme_stylebox_override("normal", _box(face, edge, depth, 0))
	add_theme_stylebox_override("hover", _box(face, edge, depth, 0))
	add_theme_stylebox_override("pressed", _box(face.darkened(0.04), edge, 2, sink))
	add_theme_stylebox_override("hover_pressed", _box(face.darkened(0.04), edge, 2, sink))
	add_theme_stylebox_override("disabled", _box(face, edge, depth, 0))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ink := INK if card_style else Color.WHITE
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		add_theme_color_override(c, ink)


## The face is drawn `sink` px lower when pressed (negative top expand margin),
## and the content margins move the label down by the same amount.
func _box(face: Color, edge: Color, bottom: int, sink: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.border_color = edge
	sb.border_width_bottom = bottom
	if card_style:
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
	sb.set_corner_radius_all(radius)
	sb.expand_margin_top = -sink
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 12 + sink
	sb.content_margin_bottom = 12 + bottom
	sb.anti_aliasing = true
	return sb
