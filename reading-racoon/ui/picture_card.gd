class_name PictureCard
extends Control
## The task's main picture on a slightly tilted paper card, like a photo pinned
## to a storybook page (D-009). The picture is a tinted SVG silhouette.
## The card lives inside this plain Control because containers reset rotation.

var _card: PanelContainer
var _tilt := -2.5


func setup(picture: String, word: String, px: float = 190.0, tilt: float = -2.5) -> void:
	_tilt = tilt
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(26)
	sb.shadow_color = Color(Palette.SHADOW, 0.2)
	sb.shadow_offset = Vector2(4, 9)
	sb.shadow_size = 1
	sb.set_content_margin_all(22)
	_card.add_theme_stylebox_override("panel", sb)
	add_child(_card)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	_card.add_child(v)
	if picture != "":
		var holder := PanelContainer.new()
		var bg := StyleBoxFlat.new()
		bg.bg_color = Palette.pale(Icons.picture_color(picture), 0.82)
		bg.set_corner_radius_all(20)
		bg.set_content_margin_all(16)
		holder.add_theme_stylebox_override("panel", bg)
		holder.add_child(Icons.rect(picture, px, Icons.picture_color(picture)))
		v.add_child(holder)
	if word != "":
		var l := Label.new()
		l.text = word
		l.theme_type_variation = &"ReadWord"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if word.contains(" ") or word.length() > 12:
			# A sentence (fluency completion, vocabulary in context).
			l.add_theme_font_size_override("font_size", 44)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(540, 0)
		elif picture != "":
			l.add_theme_font_size_override("font_size", 64)
		v.add_child(l)
	_card.minimum_size_changed.connect(_fit)
	_fit.call_deferred()


func _fit() -> void:
	var s := _card.get_combined_minimum_size()
	custom_minimum_size = s
	_card.size = s
	_card.pivot_offset = s / 2
	_card.rotation_degrees = _tilt
