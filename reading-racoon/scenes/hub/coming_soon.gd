extends Control
## A hub section that isn't built yet: Racoon says he's still making it, and Home goes back.
## GameState.soon_section names the section.


func _ready() -> void:
	%HomeButton.pressed.connect(GameState.go_home)
	%HomeButton.add_to_group("back_button")   # Android Back and Escape
	var safe := Kit.insets()
	%HomeButton.position += Vector2(safe.left, safe.top)
	if Kit.landscape():
		_fit_landscape()
	var info := HubSections.get_info(GameState.soon_section)
	var title := str(info.get("name", "This place"))
	var color: Color = info.get("color", Palette.BLUE)
	%Title.text = title
	%Icon.texture = Icons.tex(str(info.get("icon", "star")))
	%Icon.self_modulate = Palette.text_on(color)
	var sb := PaperBox.new()
	sb.bg_color = color
	sb.set_corner_radius_all(75)
	sb.shadow_color = Color(Palette.SHADOW, 0.2)
	sb.shadow_offset = Vector2(0, 6)
	sb.shadow_size = 1
	%Disc.add_theme_stylebox_override("panel", sb)
	await get_tree().process_frame
	var text := GameState.talk("coming_soon", [title])
	%Raccoon.set_mood("thinking")
	%Bubble.say(text)
	Speech.say(text)


## Laptop layout: the section's name on the left, Racoon and his bubble on the right
## above the village, like the lock screen.
func _fit_landscape() -> void:
	var center: VBoxContainer = $Center
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -560
	right.offset_right = -60
	right.offset_top = 40
	right.offset_bottom = -60
	add_child(right)
	for n: Control in [%Bubble, center.get_node("Gap"), center.get_node("RaccoonRow")]:
		n.reparent(right, false)
	center.get_node("Spacer").queue_free()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.offset_top = 40
	center.offset_bottom = -200
	center.offset_right = -600
	$Scenery.offset_top = -300
