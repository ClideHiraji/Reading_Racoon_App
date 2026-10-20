@tool
class_name ChunkyButton
extends Button
## Paper-cut button (D-009): a flat paper face lifted on a crisp shadow that
## presses down when tapped. Uses Button's built-in icon for the SVG icons.
## NFR-02: keep custom_minimum_size >= 96 px (48 dp).

@export var face_color := Palette.LEAF:
	set(v):
		face_color = v
		_restyle()
## Cream paper card with dark text (answer cards, secondary buttons).
@export var card_style := false:
	set(v):
		card_style = v
		_restyle()
@export var lift := 7:
	set(v):
		lift = v
		_restyle()
@export var radius := 22:
	set(v):
		radius = v
		_restyle()
## Name of an SVG in res://assets/icons (no emoji, D-009).
@export var icon_name := "":
	set(v):
		icon_name = v
		icon = Icons.tex(v) if v != "" else null
@export var icon_px := 44:
	set(v):
		icon_px = v
		add_theme_constant_override("icon_max_width", v)
@export var tap_sound := true
## Icon color; transparent = same as the text.
@export var icon_tint := Color(0, 0, 0, 0):
	set(v):
		icon_tint = v
		_restyle()


func _ready() -> void:
	_restyle()
	add_theme_constant_override("icon_max_width", icon_px)
	add_theme_constant_override("h_separation", 14)
	if not Engine.is_editor_hint():
		button_down.connect(_on_down)


func _on_down() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if tap_sound and sfx:
		sfx.play("tap")


func _restyle() -> void:
	var face := Palette.CARD if card_style else face_color
	var ink := Palette.INK if card_style else Color.WHITE
	add_theme_stylebox_override("normal", _box(face, lift, 0))
	add_theme_stylebox_override("hover", _box(face.lightened(0.04), lift, 0))
	add_theme_stylebox_override("pressed", _box(face.darkened(0.06), 2, lift - 2))
	add_theme_stylebox_override("hover_pressed", _box(face.darkened(0.06), 2, lift - 2))
	add_theme_stylebox_override("disabled", _box(face, lift, 0))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		add_theme_color_override(c, ink)
	var tint := icon_tint if icon_tint.a > 0.0 else ink
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_hover_pressed_color", "icon_focus_color", "icon_disabled_color"]:
		add_theme_color_override(c, tint)


## `sink` moves the whole face down (top expand margin in, bottom out) and the
## shadow shrinks to `shadow` px, so the paper looks pressed onto the page.
func _box(face: Color, shadow: int, sink: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Palette.SHADOW if not card_style else Color(Palette.SHADOW, 0.16)
	sb.shadow_offset = Vector2(0, shadow)
	sb.shadow_size = 1
	if card_style:
		sb.border_color = Palette.PAPER_DEEP
		sb.set_border_width_all(2)
	else:
		# A lighter top lip, like the cut edge of colored paper.
		sb.border_color = face.lightened(0.18)
		sb.border_width_top = 3
	sb.expand_margin_top = -sink
	sb.expand_margin_bottom = sink
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12 + sink
	sb.content_margin_bottom = 14 - sink
	sb.anti_aliasing = true
	return sb
