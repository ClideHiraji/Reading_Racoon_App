class_name PictureCard
extends Control
## The task's main picture and word: what the question is about (D-009).
## D-022: it is flat and straight, not a tilted, lifted card, so it never looks
## like one more answer; a tap reads the word aloud (a small speaker shows it).
## The card lives inside this plain Control so a tilt can still be passed in.

var _card: PanelContainer
var _tilt := 0.0


func setup(picture: String, word: String, px: float = 190.0, tilt: float = 0.0) -> void:
	_tilt = tilt
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	var tint := Palette.pale(Icons.picture_color(picture), 0.84) if picture != "" else Palette.CARD
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(20)
	_card.add_theme_stylebox_override("panel", sb)
	add_child(_card)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(v)
	if picture != "":
		var icon := Icons.rect(picture, px, Icons.picture_color(picture))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
	if word != "":
		var l := Label.new()
		l.text = word
		l.theme_type_variation = &"ReadWord"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if word.contains(" ") or word.length() > 12:
			# A sentence (fluency completion, vocabulary in context).
			l.add_theme_font_size_override("font_size", 44)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(540, 0)
		elif picture != "":
			l.add_theme_font_size_override("font_size", 64)
		v.add_child(l)
		# Tap to hear the word (FR-20).
		_card.mouse_filter = Control.MOUSE_FILTER_STOP
		_card.tooltip_text = "Hear the word"
		_card.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				var speech := get_node_or_null("/root/Speech")
				if speech:
					speech.say(word))
		var badge := PanelContainer.new()
		var bb := StyleBoxFlat.new()
		bb.bg_color = Palette.CARD
		bb.set_corner_radius_all(26)
		badge.add_theme_stylebox_override("panel", bb)
		badge.custom_minimum_size = Vector2(52, 52)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var speaker := Icons.rect("speaker", 30, Palette.BAY_DEEP)
		speaker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		speaker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_child(speaker)
		add_child(badge)
		_card.resized.connect(func(): badge.position = Vector2(_card.size.x - 40, -12))
	_card.minimum_size_changed.connect(_fit)
	_fit.call_deferred()


func _fit() -> void:
	var s := _card.get_combined_minimum_size()
	custom_minimum_size = s
	_card.size = s
	_card.pivot_offset = s / 2
	_card.rotation_degrees = _tilt
