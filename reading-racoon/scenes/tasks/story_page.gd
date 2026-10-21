class_name StoryPage
extends VBoxContainer
## A story page (Literal Comprehension, levels 3-5): a paper card with the story's
## setting drawn as a Butuan landscape, the title and the passage in Andika. The
## child reads (or listens), then taps "I read it!". Passage word caps follow
## 07-curriculum-content.md: 60 / 100 / 130 words for levels 3 / 4 / 5.

signal done

const ANDIKA := preload("res://assets/fonts/Andika-Regular.ttf")
const ANDIKA_BOLD := preload("res://assets/fonts/Andika-Bold.ttf")


func setup(passage: Dictionary, button_text: String = "I READ IT!") -> void:
	add_theme_constant_override("separation", 18)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(28)
	sb.shadow_color = Color(Palette.SHADOW, 0.2)
	sb.shadow_offset = Vector2(0, 8)
	sb.shadow_size = 1
	card.add_theme_stylebox_override("panel", sb)
	card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	var scenery := PaperScenery.new()
	scenery.scene = passage.get("scene", "river")
	scenery.custom_minimum_size = Vector2(0, 170)
	v.add_child(scenery)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 28)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 20)
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(m)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	var title := Label.new()
	title.text = passage.get("title", "")
	title.add_theme_font_override("font", ANDIKA_BOLD)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Palette.readable(Palette.CORAL_DEEP))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	var text := Label.new()
	text.text = passage.get("text", "")
	text.add_theme_font_override("font", ANDIKA)
	var words := str(passage.get("text", "")).split(" ", false).size()
	text.add_theme_font_size_override("font_size", 36 if words <= 60 else 31)
	text.add_theme_constant_override("line_spacing", 6)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(text)
	var go := ChunkyButton.new()
	go.text = button_text
	go.icon_name = "check"
	go.face_color = Palette.LEAF
	go.custom_minimum_size = Vector2(0, 100)
	go.pressed.connect(func(): done.emit())
	add_child(go)
