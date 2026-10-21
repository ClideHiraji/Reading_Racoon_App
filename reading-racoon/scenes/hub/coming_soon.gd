extends Control
## A hub section that isn't built yet (D-015): Racoon says he's still making it,
## and the Home button goes back. GameState.soon_section names the section.


func _ready() -> void:
	%HomeButton.pressed.connect(GameState.go_home)
	var info := HubSections.get_info(GameState.soon_section)
	var title := str(info.get("name", "This place"))
	var color: Color = info.get("color", Palette.BLUE)
	%Title.text = title
	%Icon.texture = Icons.tex(str(info.get("icon", "star")))
	%Icon.self_modulate = Palette.text_on(color)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(75)
	sb.shadow_color = Color(Palette.SHADOW, 0.2)
	sb.shadow_offset = Vector2(0, 6)
	sb.shadow_size = 1
	%Disc.add_theme_stylebox_override("panel", sb)
	await get_tree().process_frame
	var text := "I'm still building the %s. Come back soon!" % title
	%Raccoon.set_mood("thinking")
	%Bubble.say(text)
	Speech.say(text)
