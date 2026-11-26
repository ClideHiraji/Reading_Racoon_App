@tool
class_name ChunkyButton
extends Button
## Paper-cut button: a flat paper face lifted on a crisp shadow that presses down when tapped.
## Uses Button's own icon for the SVG icons, except when there's text too: then the icon is
## drawn right beside the text, and both sit centred together.
## Keep custom_minimum_size >= 96 px; `slop` keeps a small face easy to hit.

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
## Name of an SVG in res://assets/icons (no emoji).
@export var icon_name := "":
	set(v):
		icon_name = v
		var was := _picture
		_picture = full_color and Icons.has_picture(v)
		_glyph = (Icons.picture_tex(v) if _picture else Icons.tex(v)) if v != "" else null
		_place_icon()
		if was != _picture:
			_restyle()
## Draw the icon as its full-colour picture when it has one, in its own colours.
@export var full_color := false:
	set(v):
		full_color = v
		icon_name = icon_name
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
## so a slim chip still has a 96 px tap area.
@export var slop := 0:
	set(v):
		slop = v
		_restyle()
## Sewn round the inside, like a felt patch: only for the special big pieces.
@export var stitched := false:
	set(v):
		stitched = v
		_restyle()
## A small turn, like a patch pinned on at an angle.
@export var tilt := 0.0:
	set(v):
		tilt = v
		_turn()
## Icon color; transparent = same as the text.
@export var icon_tint := Color(0, 0, 0, 0):
	set(v):
		icon_tint = v
		_restyle()

## Taps that come too fast do nothing: a second tap on the same button within SAME_BUTTON_MS,
## or a tap on any button within ANY_BUTTON_MS of another. So a quick double tap can't open a
## screen twice, buy twice or start two things at once.
## (Touches reach a button as mouse presses, so only those are counted.)
const SAME_BUTTON_MS := 450
const ANY_BUTTON_MS := 200
static var _last_any_press := -100000
var _last_press := -100000
var _glyph: Texture2D
var _cut := randi() % 100000   # this button's hand-cut shape, the same in every state
var _picture := false      # true while the icon is a full-colour picture (never tinted)
var _beside := false   # true while the icon is drawn by hand beside the text
var _built := false        # _ready has built the look; until then a change only waits for it
var _style_queued := false


func _turn() -> void:
	pivot_offset = size / 2.0
	rotation_degrees = tilt


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and tilt != 0.0:
		_turn()


func _ready() -> void:
	add_theme_constant_override("icon_max_width", icon_px)
	if not has_theme_constant_override("h_separation"):
		add_theme_constant_override("h_separation", 14)
	_built = true
	_apply_style()
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


## A property changed: the look is rebuilt once, at the end of the frame, however many properties
## change before then. Before the button is on screen, _ready builds it once.
## (Each rebuild sets about 17 theme overrides; doing it for every property made screens slow to open.)
func _restyle() -> void:
	if not _built or _style_queued:
		return
	_style_queued = true
	_apply_style.call_deferred()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var now := Time.get_ticks_msec()
	if now - _last_press < SAME_BUTTON_MS or now - _last_any_press < ANY_BUTTON_MS:
		accept_event()   # too soon: this tap does nothing
		return
	_last_press = now
	_last_any_press = now


func _apply_style() -> void:
	_style_queued = false
	begin_bulk_theme_override()
	var face := Palette.CARD if card_style else face_color
	# Dark ink on coloured paper; cream only on faces too dark for ink.
	var ink := Palette.INK if card_style else Palette.text_on(face_color)
	add_theme_stylebox_override("normal", _box(face, lift, 0))
	# Under a laptop's mouse the face lifts 2 px and brightens, so a child sees what
	# they're about to press. Phones have no hover.
	if OS.has_feature("pc"):
		add_theme_stylebox_override("hover", _box(face.lightened(0.07), lift + 2, -2))
	else:
		add_theme_stylebox_override("hover", _box(face.lightened(0.04), lift, 0))
	add_theme_stylebox_override("pressed", _box(face.darkened(0.06), 2, lift - 2))
	add_theme_stylebox_override("hover_pressed", _box(face.darkened(0.06), 2, lift - 2))
	add_theme_stylebox_override("disabled", _box(face, lift, 0))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		add_theme_color_override(c, ink)
	var tint := icon_tint if icon_tint.a > 0.0 else ink
	if _picture:
		tint = Color.WHITE   # a full-colour picture keeps its own colours
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_hover_pressed_color", "icon_focus_color", "icon_disabled_color"]:
		add_theme_color_override(c, tint)
	end_bulk_theme_override()
	queue_redraw()


## `sink` moves the whole face down (top expand margin in, bottom out) and the
## shadow shrinks to `shadow` px, so the paper looks pressed onto the page.
func _box(face: Color, shadow: int, sink: int) -> PaperBox:
	var sb := PaperBox.new()   # cut from paper; every state keeps the same cut
	sb.cut = _cut
	sb.stitch = stitched
	sb.bg_color = face
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Palette.SHADOW if not card_style else Color(Palette.SHADOW, 0.16)
	sb.shadow_offset = Vector2(0, shadow)
	sb.shadow_size = 1
	if card_style:
		# A faint neutral ring, not a coloured border: the shadow gives the depth.
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
