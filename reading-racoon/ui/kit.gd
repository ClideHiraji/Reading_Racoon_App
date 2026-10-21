class_name Kit
extends RefCounted
## Shared builders for the hub's sections (D-017), in the paper-cut look (D-009)
## and the thesis colors (D-016): the paper page, a header with Home or Close and
## coins, filter chips, labels, discs, an overlay card and the reward card.
## Autoloads are looked up through the scene tree (/root/...), so tests that load
## this class before the autoloads exist still compile.

const PAPER_SHADER := preload("res://ui/paper.gdshader")
const ANDIKA := preload("res://assets/fonts/Andika-Bold.ttf")


## A full-screen paper page with a column for the screen's content. Returns the column.
static func page(root: Control, scene: String = "", scene_height: float = 0.0) -> VBoxContainer:
	var bg := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = PAPER_SHADER
	bg.material = mat
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	if scene != "":
		var s := PaperScenery.new()
		s.scene = scene
		s.show_sky = false
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		s.offset_top = -scene_height
		root.add_child(s)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 24)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 20)
	root.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	m.add_child(v)
	return v


## Top row: Home (or Close for a screen inside a section), the title and coins.
## Returns {row, back, coins}.
static func header(column: Control, title: String, on_back: Callable, close := false) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var back: BaseButton
	if close:
		back = CloseButton.new()
	else:
		var b := ChunkyButton.new()
		b.card_style = true
		b.icon_name = "house"
		b.icon_px = 46
		b.icon_tint = Palette.BAY_DEEP
		b.lift = 5
		b.radius = 44
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(88, 88)
		back = b
	back.tooltip_text = "Back" if close else "Home"
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(on_back)
	row.add_child(back)
	var t := label(title, 42, Palette.INK, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(t)
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", box(Palette.CARD, 30, 4, Vector4(14, 8, 18, 8)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	pill.add_child(h)
	h.add_child(Icons.rect("coins", 36, Palette.MANGO_DEEP))
	var gs := column.get_node_or_null("/root/GameState")
	var coins := label(str(gs.wallet.coins) if gs else "0", 28, Palette.INK, true)
	coins.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(coins)
	row.add_child(pill)
	return {"row": row, "back": back, "coins": coins}


## A row of filter chips; the picked one is blue. on_pick(id) is called on tap.
static func chips(options: Array, selected: String, on_pick: Callable) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	for o in options:
		var b := ChunkyButton.new()
		b.text = o[1]
		b.card_style = o[0] != selected
		b.face_color = Palette.BLUE
		b.lift = 4
		b.radius = 22
		b.add_theme_font_size_override("font_size", 24)
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(on_pick.bind(o[0]))
		flow.add_child(b)
	return flow


static func label(text: String, fs: int = 28, col: Color = Palette.INK, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if bold:
		l.theme_type_variation = &"TitleLabel"
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A word in the reading font (Andika).
static func word_label(text: String, fs: int = 40) -> Label:
	var l := label(text, fs)
	l.add_theme_font_override("font", ANDIKA)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


static func box(col: Color, r: int, lift: int = 0, pad := Vector4.ZERO) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(r)
	sb.anti_aliasing = true
	if lift > 0:
		sb.shadow_color = Color(Palette.SHADOW, 0.2)
		sb.shadow_offset = Vector2(0, lift)
		sb.shadow_size = 1
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


## A paper card (PanelContainer) with padding.
static func card(pad: float = 20, col: Color = Palette.CARD) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(col, 26, 6, Vector4(pad, pad, pad, pad)))
	return p


## A round colored disc with an icon in readable ink.
static func disc(icon: String, color: Color, px: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, int(px / 2), 4))
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := Icons.rect(icon, px * 0.6, Palette.text_on(color))
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(r)
	return p


## A picture in its own color on a pale square (like the lesson picture cards).
static func picture(icon: String, px: float) -> PanelContainer:
	var col := Icons.picture_color(icon)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Palette.pale(col, 0.82), 18))
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := Icons.rect(icon, px * 0.72, col)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(r)
	return p


## A big paper button in a palette color with dark text.
static func button(text: String, color: Color, icon: String = "", h: float = 96) -> ChunkyButton:
	var b := ChunkyButton.new()
	b.text = text
	b.face_color = color
	b.icon_name = icon
	b.icon_px = 44
	b.custom_minimum_size = Vector2(0, h)
	return b


## A dimmed full-screen layer with a centered paper card; returns the card's
## column. Free `column.get_meta("overlay")` to close it.
static func overlay(root: Control) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var c := card(32)
	c.custom_minimum_size = Vector2(minf(root.size.x - 80, 600), 0)
	center.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	v.set_meta("overlay", dim)
	c.pivot_offset = Vector2(300, 200)
	c.scale = Vector2(0.9, 0.9)
	c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	return v


## A sticker as it sits in the album: its group color with the picture.
static func sticker(id: String, px: float) -> PanelContainer:
	return disc(id if Icons.exists(id) else "star", Collection.color_of(id), px)


## The card after an activity: coins, new stickers and today's goals.
## `result` = GameState.finish_*(): {coins, stickers: [ids], goals_done}.
static func reward(root: Control, title: String, result: Dictionary, on_done: Callable) -> void:
	var v := overlay(root)
	var t := label(title, 44, Palette.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var said := title
	var coins := int(result.get("coins", 0))
	if coins > 0:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		row.add_child(Icons.rect("coins", 44, Palette.MANGO_DEEP))
		var c := label("+%d coins" % coins, 34, Palette.readable(Palette.MANGO_DEEP), true)
		c.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(c)
		v.add_child(row)
	var stickers: Array = result.get("stickers", [])
	if not stickers.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 18)
		for id in stickers:
			var col := VBoxContainer.new()
			col.add_child(sticker(id, 110))
			var n := label(Collection.sticker(id).get("name", ""), 24, Palette.INK, true)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(n)
			row.add_child(col)
		v.add_child(row)
		var s := label("New sticker for your album!" if stickers.size() == 1
				else "New stickers for your album!", 26, Palette.INK_SOFT)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
		said += " " + s.text
	if result.get("goals_done", false):
		var g := label("You finished today's goals!", 28, Palette.readable(Palette.LEAF), true)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(g)
	var ok := button("OK!", Palette.ORANGE)
	ok.pressed.connect(func():
		v.get_meta("overlay").queue_free()
		on_done.call())
	v.add_child(ok)
	var sfx := root.get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("fanfare" if not stickers.is_empty() else "coin")
	var speech := root.get_node_or_null("/root/Speech")
	if speech:
		speech.say(said)
