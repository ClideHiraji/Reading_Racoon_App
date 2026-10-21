@tool
class_name DiamondTile
extends Button
## A diamond paper tile for the Play picker (D-015), like a game's mode screen:
## a square turned 45 degrees with an icon, a name and a short line. Taps count
## only inside the diamond. Locked tiles turn grey with a lock.
## A flat Button with no text: all of its look is drawn here.

const LOCKED := Color("c9c0b2")

@export var face_color := Palette.TEAL:
	set(v):
		face_color = v
		_restyle()
@export var title := "":
	set(v):
		title = v
		_restyle()
@export var subtitle := "":
	set(v):
		subtitle = v
		_restyle()
@export var icon_name := "":
	set(v):
		icon_name = v
		_restyle()
@export var locked := false:
	set(v):
		locked = v
		_restyle()
## Always dark ink text; otherwise the most readable of ink or cream (D-016).
@export var dark_text := false:
	set(v):
		dark_text = v
		_restyle()
@export var title_size := 30:
	set(v):
		title_size = v
		_restyle()
@export var lift := 8

var _box: VBoxContainer
var _icon: TextureRect
var _title: Label
var _sub: Label


func _ready() -> void:
	flat = true
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 2)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_box)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_icon)
	_title = _label()
	_box.add_child(_title)
	_sub = _label()
	_box.add_child(_sub)
	resized.connect(_restyle)
	if not Engine.is_editor_hint():
		button_down.connect(_on_down)
		button_up.connect(queue_redraw)
	_restyle()


func _label() -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.theme_type_variation = &"TitleLabel"
	return l


func _on_down() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("tap")
	queue_redraw()


func _restyle() -> void:
	queue_redraw()
	if _box == null:
		return
	var ink := Palette.INK if dark_text or locked else Palette.text_on(face_color)
	_icon.texture = Icons.tex("lock" if locked else icon_name)
	var px := size.x * 0.2
	_icon.custom_minimum_size = Vector2(px, px)
	_icon.self_modulate = ink
	_title.text = title
	_title.add_theme_font_size_override("font_size", title_size)
	_title.add_theme_color_override("font_color", ink)
	_sub.text = subtitle
	_sub.visible = subtitle != ""
	_sub.add_theme_font_size_override("font_size", 24)
	_sub.add_theme_color_override("font_color", Color(ink, 0.85))
	_box.offset_bottom = -lift


func _face() -> Color:
	return LOCKED if locked else face_color


func _draw() -> void:
	var down := get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED]
	var sink := float(lift - 2) if down else 0.0
	var hw := size.x / 2.0
	var hh := (size.y - lift) / 2.0
	var c := Vector2(hw, hh)
	draw_colored_polygon(_diamond(c + Vector2(0, lift), hw, hh), Palette.SHADOW)
	draw_colored_polygon(_diamond(c + Vector2(0, sink), hw, hh), Palette.CARD)
	var face := _diamond(c + Vector2(0, sink), hw - 10, hh - 10)
	var col := _face()
	draw_polygon(face, PackedColorArray([col.lightened(0.2), col, col.darkened(0.14), col]))


## Top, right, bottom, left.
func _diamond(c: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh),
			c + Vector2(-hw, 0)])


func _has_point(p: Vector2) -> bool:
	var hw := size.x / 2.0
	var hh := (size.y - lift) / 2.0
	return absf(p.x - hw) / hw + absf(p.y - hh) / hh <= 1.0
