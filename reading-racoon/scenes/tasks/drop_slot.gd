class_name DropSlot
extends PanelContainer
## The gap in a word that accepts a dragged LetterTile.

signal dropped(letter: String)

var _label: Label
var _style: StyleBoxFlat


func _init() -> void:
	custom_minimum_size = Vector2(120, 140)
	_style = StyleBoxFlat.new()
	_style.bg_color = Color("fff1d6")
	_style.border_color = Color("e0b55a")
	_style.set_border_width_all(4)
	_style.border_width_bottom = 8
	_style.set_corner_radius_all(20)
	add_theme_stylebox_override("panel", _style)
	_label = Label.new()
	_label.theme_type_variation = &"ReadWord"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.text = "?"
	_label.modulate.a = 0.35
	add_child(_label)


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("letter")


func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.emit(data.letter)


func show_letter(letter: String) -> void:
	_label.text = letter
	_label.modulate.a = 1.0


func set_color(c: Color) -> void:
	_style.bg_color = c.lightened(0.6)
	_style.border_color = c
	_label.add_theme_color_override("font_color", c.darkened(0.35))
