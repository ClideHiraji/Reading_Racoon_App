@tool
class_name ChunkyButton
extends Button
## Paper-cut button (D-009): a flat paper face lifted on a crisp shadow that
## presses down when tapped. Uses Button's built-in icon for the SVG icons, except
## when there is text too: then the icon is drawn right beside the text, and the
## two sit centered together, as on the redesign canvas (D-022).
## NFR-02: keep custom_minimum_size >= 96 px (48 dp); `slop` keeps a small face
## easy to hit.

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
		_glyph = Icons.tex(v) if v != "" else null
		_place_icon()
@export var icon_px := 44:
	set(v):
		icon_px = v
		add_theme_constant_override("icon_max_width", v)
		_restyle()
@export var tap_sound := true
## Space between the face's edge and its icon and text (chips use less).
@export var pad := 22:
	set(v):
		pad = v
		_restyle()
## The face is drawn this many px smaller at the top and bottom than the button,
## so a slim chip still has a 96 px tap area (NFR-02, D-022).
@export var slop := 0:
	set(v):
		slop = v
		_restyle()
## Icon color; transparent = same as the text.
@export var icon_tint := Color(0, 0, 0, 0):
	set(v):
		icon_tint = v
		_restyle()

var _glyph: Texture2D
var _beside := false   # true while the icon is drawn by hand beside the text


func _ready() -> void:
	add_theme_constant_override("icon_max_width", icon_px)
	if not has_theme_constant_override("h_separation"):
		add_theme_constant_override("h_separation", 14)
	_restyle()
	_place_icon()
	if not Engine.is_editor_hint():
		button_down.connect(_on_down)


func _on_down() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if tap_sound and sfx:
		sfx.play("tap")


## Text and icon together: the icon leaves Button's slot (which pins it to the
## edge) and the left margin makes room for it, so the text centers with it.
func _place_icon() -> void:
	var beside := _glyph != null and text != "" and icon_alignment == HORIZONTAL_ALIGNMENT_LEFT \
			and alignment == HORIZONTAL_ALIGNMENT_CENTER
	icon = null if beside else _glyph
	if beside != _beside:
		_beside = beside
		_restyle()
	queue_redraw()


func _icon_size() -> float:
	return minf(icon_px, _glyph.get_width()) if _glyph else 0.0


func _restyle() -> void:
	var face := Palette.CARD if card_style else face_color
	# Dark ink on colored paper (D-016); cream only on faces too dark for ink.
	var ink := Palette.INK if card_style else Palette.text_on(face_color)
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
	queue_redraw()


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
		# A faint neutral ring, not a tinted border: the shadow gives the depth (D-022).
		sb.border_color = Color(0, 0, 0, 0.06)
		sb.set_border_width_all(1)
	else:
		# A lighter top lip, like the cut edge of colored paper.
		sb.border_color = face.lightened(0.18)
		sb.border_width_top = 3
	sb.expand_margin_top = -sink - slop
	sb.expand_margin_bottom = sink - slop
	# Beside the text, the icon side is 2 px tighter than the text side, which
	# looks even (optical, not geometric, centering).
	var room := _icon_size() + get_theme_constant("h_separation") if _beside else 0.0
	sb.content_margin_left = pad - 1.0 + room if _beside else float(pad)
	sb.content_margin_right = pad + 1.0 if _beside else float(pad)
	sb.content_margin_top = 12 + sink
	sb.content_margin_bottom = 14 - sink
	sb.anti_aliasing = true
	return sb


func _draw() -> void:
	if not _beside:
		# Text set after the icon (or cleared) changes whether they sit together.
		if _glyph != null and text != "" and icon == null:
			_place_icon.call_deferred()
		return
	if text == "":
		_place_icon.call_deferred()
		return
	var sb := get_theme_stylebox(_style_name())
	var font := get_theme_font("font")
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x
	var left := sb.content_margin_left
	var right := size.x - sb.content_margin_right
	var text_left := (left + right - text_w) / 2.0
	var s := _icon_size()
	var top := sb.content_margin_top
	var bottom := size.y - sb.content_margin_bottom
	var at := Vector2(text_left - get_theme_constant("h_separation") - s, (top + bottom - s) / 2.0)
	draw_texture_rect(_glyph, Rect2(at, Vector2(s, s)), false, get_theme_color("icon_normal_color"))


func _style_name() -> String:
	match get_draw_mode():
		DRAW_PRESSED:
			return "pressed"
		DRAW_HOVER:
			return "hover"
		DRAW_HOVER_PRESSED:
			return "hover_pressed"
		DRAW_DISABLED:
			return "disabled"
	return "normal"
