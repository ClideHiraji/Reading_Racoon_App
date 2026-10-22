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


## Top row (D-022): Home on a section, or Close on an activity (it asks first),
## the title and coins. Both buttons are 96 px (NFR-02). Returns {row, back, coins}.
static func header(column: Control, title: String, on_back: Callable, close := false,
		coins := true) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var back: BaseButton
	if close:
		back = CloseButton.new()
	else:
		back = home_button()
	back.tooltip_text = "Back" if close else "Home"
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(on_back)
	row.add_child(back)
	var t := label(title, 40, Palette.INK, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# A long title gets a little smaller before it is ever cut short (D-022).
	t.resized.connect(func(): fit_font(t, [40, 36, 32, 28]))
	row.add_child(t)
	if not coins:
		return {"row": row, "back": back, "coins": null}
	var pill := coin_pill(column)
	row.add_child(pill)
	return {"row": row, "back": back, "coins": pill.get_meta("label")}


## A game's top row (D-022): Close, the name and one dot per round in place of
## the coins (the reward card shows those). Fill the dots with show_rounds().
## Returns {row, back, dots}.
static func game_header(column: Control, title: String, on_back: Callable) -> Dictionary:
	var head := header(column, title, on_back, true, false)
	var row: HBoxContainer = head.row
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 10)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dots)
	return {"row": row, "back": head.back, "dots": dots}


## Round dots: `results` holds "right" or "almost" for each round played so far
## (green only for a right answer, D-022); the round being played has a blue ring.
static func show_rounds(dots: HBoxContainer, total: int, results: Array) -> void:
	for c in dots.get_children():
		dots.remove_child(c)
		c.queue_free()
	for i in total:
		var sb := box(Palette.CARD, 11)
		if i < results.size():
			sb.bg_color = Palette.RIGHT if results[i] == "right" else Palette.ALMOST
		elif i == results.size():
			sb.border_color = Palette.BAY_DEEP
			sb.set_border_width_all(4)
		var d := Panel.new()
		d.custom_minimum_size = Vector2(22, 22)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.add_theme_stylebox_override("panel", sb)
		dots.add_child(d)


## The round Home button every section starts with (D-022).
static func home_button() -> ChunkyButton:
	var b := ChunkyButton.new()
	b.card_style = true
	b.icon_name = "house"
	b.icon_px = 50
	b.icon_tint = Palette.BAY_DEEP
	b.lift = 6
	b.radius = 48
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(96, 96)
	return b


## The coins pill; its Label is in get_meta("label").
static func coin_pill(anchor: Node) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", box(Palette.CARD, 36, 5, Vector4(14, 12, 22, 12)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	pill.add_child(h)
	h.add_child(Icons.rect("coins", 42, Palette.MANGO_DEEP))
	var gs := anchor.get_node_or_null("/root/GameState")
	var coins := label(str(gs.wallet.coins) if gs else "0", 30, Palette.INK, true)
	coins.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(coins)
	pill.set_meta("label", coins)
	return pill


## A row of filter chips; the picked one is blue. on_pick(id) is called on tap.
## Options are [id, label] or [id, label, icon]. Racoon reads the chip's name
## aloud, since a child may not read it yet (D-022).
static func chips(options: Array, selected: String, on_pick: Callable) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 0)
	for o in options:
		var b := ChunkyButton.new()
		b.text = o[1]
		b.card_style = o[0] != selected
		b.face_color = Palette.BLUE
		b.lift = 5
		b.radius = 36
		b.pad = 18
		b.add_theme_constant_override("h_separation", 8)
		if o.size() > 2:
			# [value, label, icon, tint]: a language chip shows its color dot (D-022).
			b.icon_name = o[2]
			b.icon_px = 22 if o[2] == "dot" else 34
			b.icon_tint = o[3] if o.size() > 3 else (Palette.INK if o[0] == selected else Palette.BAY_DEEP)
		b.add_theme_font_size_override("font_size", 26)
		# A 72 px chip with a 96 px tap area (NFR-02, D-022).
		b.slop = 12
		b.custom_minimum_size = Vector2(0, 96)
		b.pressed.connect(func():
			var speech := flow.get_node_or_null("/root/Speech")
			if speech:
				speech.say(o[1])
			on_pick.call(o[0]))
		flow.add_child(b)
	return flow


## The biggest of `sizes` at which the one-line label fits its width; the last
## size (with the ellipsis) if none does.
static func fit_font(l: Label, sizes: Array) -> void:
	var font := l.get_theme_font("font")
	for fs in sizes:
		if font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= l.size.x:
			l.add_theme_font_size_override("font_size", fs)
			return
	l.add_theme_font_size_override("font_size", sizes[-1])


## Breaks a two-line label where its lines come out even, so no word sits
## alone on the second line (text-wrap: balance, D-022). Call it on `resized`.
static func balance(l: Label) -> void:
	var full: String = l.get_meta("full_text", l.text)
	l.set_meta("full_text", full)
	var font := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var width := l.size.x
	if width <= 0.0 or font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
		l.text = full
		return
	var words := full.split(" ", false)
	var best := full
	var best_w := INF
	for i in range(1, words.size()):
		var a := " ".join(words.slice(0, i))
		var b := " ".join(words.slice(i))
		var w := maxf(font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
				font.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		if w <= width and w < best_w:
			best_w = w
			best = a + "\n" + b
	l.text = best


## A faint inset edge for a photo, so a light picture doesn't melt into the
## card: pure black at 10%, never a palette color (D-022). Corners match the photo.
static func photo_edge(top_r: int, bottom_r: int) -> Panel:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(0, 0, 0, 0.1)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = top_r
	sb.corner_radius_top_right = top_r
	sb.corner_radius_bottom_left = bottom_r
	sb.corner_radius_bottom_right = bottom_r
	sb.anti_aliasing = true
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A small side-to-side "not now" shake. A tap in the middle of one starts again
## from the resting spot, so quick taps never leave the node off-center (D-022).
static func shake(node: Control, amount: float = 12.0) -> void:
	if node.has_meta("shake_tween") and node.get_meta("shake_tween").is_valid():
		node.get_meta("shake_tween").kill()
	if not node.has_meta("rest_x"):
		node.set_meta("rest_x", node.position.x)
	var x: float = node.get_meta("rest_x")
	var t := node.create_tween()
	for d in [amount, -amount, amount * 0.66, 0.0]:
		t.tween_property(node, "position:x", x + d, 0.05)
	t.finished.connect(func(): node.remove_meta("rest_x"))
	node.set_meta("shake_tween", t)


## A quick grow-and-settle for a tapped thing; a new tap restarts it instead of
## stacking a second animation on the same scale (D-022).
static func pop(node: Control, to: float = 1.12) -> void:
	if node.has_meta("pop_tween") and node.get_meta("pop_tween").is_valid():
		node.get_meta("pop_tween").kill()
	node.pivot_offset = node.size / 2
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2(to, to), 0.1)
	t.tween_property(node, "scale", Vector2.ONE, 0.15)
	node.set_meta("pop_tween", t)


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
## Inside a card, `corner` is the card's corner minus its padding (D-022).
static func picture(icon: String, px: float, corner: int = 18) -> PanelContainer:
	var col := Icons.picture_color(icon)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Palette.pale(col, 0.82), corner))
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := Icons.rect(icon, px * 0.72, col)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(r)
	return p


## A big paper button in a palette color with dark text. Main buttons are
## orange and 120 px tall; green only answers "right" (D-022).
static func button(text: String, color: Color, icon: String = "", h: float = 120) -> ChunkyButton:
	var b := ChunkyButton.new()
	b.text = text
	b.face_color = color
	b.icon_name = icon
	b.icon_px = 52
	b.radius = 28
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
	# Grow from the card's own center once it is laid out (D-022).
	c.resized.connect(func(): c.pivot_offset = c.size / 2)
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
	var t := label(title, 48, Palette.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var said := title
	var coins := int(result.get("coins", 0))
	if coins > 0:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		row.add_child(Icons.rect("coins", 52, Palette.MANGO_DEEP))
		var c := label("+%d coins" % coins, 38, Palette.readable(Palette.MANGO_DEEP), true)
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
			col.add_child(sticker(id, 140))
			var n := label(Collection.sticker(id).get("name", ""), 28, Palette.INK, true)
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
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		row.add_child(AnimatedStar.make(96))
		var g := label("You finished today's goals!", 28, Palette.readable(Palette.LEAF), true)
		g.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(g)
		v.add_child(row)
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
