extends Control
## Racoon's Closet, the reward shop (FR-07): spend coins on hats, scarves, glasses
## and pins. Tap an item to try it on, then buy or wear it with the big button.
## Rewards are personal: no leaderboards (06-game-design.md reward cautions).
## Home button like every section, picture tabs and a big Buy/Wear button (D-022).
## Tiers (D-026): each card shows its item's tier (copper to diamond: a frame, a badge with 1-5
## stars, and from silver up a shine); items to earn show how, read aloud; gold and diamond
## items make Racoon show off when he tries them on. No timers, no random prizes.

const SLOT_ICONS := {"hat": "hat", "neck": "scarf", "eyes": "glasses", "top": "shirt", "paws": "book", "pet": "bird"}
const TIER_CARD := preload("res://ui/tier_card.gdshader")
## What Racoon does when he tries an item on, by tier: the finer the item, the bigger the show.
const SHOW_OFF := {"copper": "happy", "silver": "happy", "violet": "giggle", "gold": "dance",
		"diamond": "big_jump"}

var _slot := "hat"
var _selected := ""

@onready var raccoon: Raccoon = %Raccoon
@onready var bubble: SpeechBubble = %Bubble


func _ready() -> void:
	_fit_shape()
	%BackButton.pressed.connect(_back)
	%BackButton.add_to_group("back_button")   # Android Back and Escape (D-023)
	%ActionButton.pressed.connect(_on_action)
	GameState.wallet_changed.connect(_update_coins)
	raccoon.follow_saved_outfit = false
	raccoon.outfit = GameState.wardrobe.equipped.duplicate()
	raccoon.lively = true   # he turns round, walks about, dances in what he's trying on (D-024)
	bubble.speaker = raccoon   # and his bubble walks with him, pointing at him
	for slot in Wardrobe.SLOTS:
		var tab := ChunkyButton.new()
		# Just the slot's paper picture, big, with no word (the user asked; D-027). Racoon says
		# the slot's name when it's tapped and it's the tooltip, so a child who can't read yet
		# still knows it (D-022). Five fit a phone's width, 110 px tall (NFR-02).
		tab.tooltip_text = Wardrobe.SLOT_NAMES[slot]
		tab.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		tab.full_color = true
		tab.icon_name = SLOT_ICONS.get(slot, "")
		tab.icon_px = 78
		tab.expand_icon = true
		tab.pad = 8
		tab.custom_minimum_size = Vector2(0, 110)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.lift = 5
		tab.radius = 24
		tab.pressed.connect(_on_tab.bind(slot))
		tab.set_meta("slot", slot)
		%Tabs.add_child(tab)
	%Title.text = GameState.talk("closet_title")   # the buddy's own Closet (D-033)
	_update_coins()
	_show_slot("hat")
	await get_tree().process_frame
	bubble.say(GameState.line("shop_hello"))
	# items earned since the last visit (D-026): show them first
	var got := GameState.grant_items()
	if not got.is_empty():
		Kit.reward(self, GameState.talk("reward_new_for"), {"items": got}, func(): _show_slot(_slot))


## Laptops (D-023): Racoon's stage on the left, the tabs, items and Buy/Wear on
## the right. Both shapes keep clear of a notch.
func _fit_shape() -> void:
	var margin: MarginContainer = $Margin
	if Kit.landscape():
		var col: VBoxContainer = $Margin/VBox
		var stage: Control = $Margin/VBox/Stage
		var body := HBoxContainer.new()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 24)
		col.add_child(body)
		stage.reparent(body, false)
		stage.custom_minimum_size = Vector2(440, 0)
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_theme_constant_override("separation", 18)
		body.add_child(right)
		for n: Control in [%Tabs, $Margin/VBox/Scroll, $Margin/VBox/ActionRow]:
			n.reparent(right, false)
		for edge in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + edge, 40)
	Kit.fit_safe(margin)


## A tab tapped: Racoon says its name (the tabs have no words), then its items show.
func _on_tab(slot: String) -> void:
	_speak(Wardrobe.SLOT_NAMES[slot], "en")
	_show_slot(slot)


func _show_slot(slot: String) -> void:
	_slot = slot
	for tab in %Tabs.get_children():
		var on: bool = tab.get_meta("slot") == slot
		tab.card_style = not on
		tab.face_color = Palette.BLUE
		tab.icon_tint = Palette.INK if on else Palette.BAY_DEEP
	for c in %Grid.get_children():
		c.queue_free()
	for id in GameState.wardrobe.items_in(slot):
		%Grid.add_child(_card(id))
	_select("")


## An item card: its tier (frame, badge, shine), a mini Racoon wearing only that item, its name
## and price (or how to earn it).
func _card(id: String) -> Control:
	var item: Dictionary = Wardrobe.ITEMS[id]
	var tier: Dictionary = Wardrobe.tier_of(id)
	var card := ChunkyButton.new()
	card.card_style = true
	card.custom_minimum_size = Vector2(200, 292)
	card.pressed.connect(_select.bind(id))
	card.set_meta("id", id)
	var frame := ColorRect.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = TIER_CARD
	mat.set_shader_parameter("tier", int(tier.rank) - 1)
	mat.set_shader_parameter("frame_color", tier.color)
	mat.set_shader_parameter("light_color", tier.light)
	mat.set_shader_parameter("seed", float(absi(hash(id)) % 997) / 37.0)
	frame.material = mat
	frame.resized.connect(func(): mat.set_shader_parameter("rect_size", frame.size))
	card.add_child(frame)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 10
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	v.add_child(Kit.tier_badge(str(item.tier), 20))
	var preview := Raccoon.new()
	preview.follow_saved_outfit = false
	preview.outfit = {item.slot: id}
	preview.custom_minimum_size = Vector2(0, 150)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.still = true   # a screen of cards: each drawn once (D-024)
	v.add_child(preview)
	var title := Label.new()
	title.text = item.name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = &"TitleLabel"
	# A long name ("Builder's hard hat") gets smaller to fit the 200 px card, not pushed out of it.
	var w := ThemeDB.get_project_theme().get_font(&"font", &"TitleLabel").get_string_size(
			str(item.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	title.add_theme_font_size_override("font_size", 24 if w <= 184.0 else maxi(18, floori(24.0 * 184.0 / w)))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)
	v.add_child(_price_row(id))
	return card


func _price_row(id: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var w := GameState.wardrobe
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 24)
	if w.is_worn(id):
		row.add_child(Icons.rect("check", 24, Palette.LEAF_DEEP))
		l.text = "Wearing"
		l.add_theme_color_override("font_color", Palette.readable(Palette.LEAF_DEEP))
	elif w.owns(id):
		l.text = "Yours"
		l.add_theme_color_override("font_color", Palette.readable(Palette.BAY_DEEP))
	elif Wardrobe.is_earned_item(id):
		# D-026: earned, not sold
		var deep: Color = Wardrobe.tier_of(id).deep
		row.add_child(Icons.rect("lock", 22, deep))
		l.text = "Earn it"
		l.add_theme_color_override("font_color", Palette.readable(deep))
	else:
		row.add_child(Icons.picture_rect("coin", 28))
		l.text = str(Wardrobe.ITEMS[id].price)
		l.add_theme_color_override("font_color", Palette.readable(Palette.MANGO_DEEP))
	row.add_child(l)
	return row


## Try an item on (or clear the try-on with "") and set up the big button.
func _select(id: String) -> void:
	_selected = id
	var preview: Dictionary = GameState.wardrobe.equipped.duplicate()
	if id != "":
		preview[Wardrobe.ITEMS[id].slot] = id
		raccoon.play(SHOW_OFF.get(str(Wardrobe.ITEMS[id].tier), "happy"))
	raccoon.outfit = preview
	for c in %Grid.get_children():
		if c is ChunkyButton:
			c.card_style = c.get_meta("id") != id
			c.face_color = Palette.pale(Palette.BLUE, 0.55)
	var button: ChunkyButton = %ActionButton
	button.full_color = false
	button.icon_name = ""
	if id == "":
		%ItemName.text = "Tap something to try it on!"
		button.visible = false
		return
	button.visible = true
	%ItemName.text = Wardrobe.ITEMS[id].name   # its tier is the stars on its card
	var w := GameState.wardrobe
	if not w.owns(id) and Wardrobe.is_earned_item(id):
		# D-026: how to earn it, and how far along the child is
		var need: int = Wardrobe.ITEMS[id].earn[1]
		var have := mini(int(GameState.earn_progress().get(Wardrobe.ITEMS[id].earn[0], 0)), need)
		%ItemName.text = "%s\n%s: %d of %d" % [Wardrobe.ITEMS[id].name, Wardrobe.earn_text(id), have, need]
		button.text = "EARN IT"
		button.icon_name = "lock"
		button.face_color = Palette.PAPER_DEEP
		bubble.say(GameState.talk("shop_earn", [Wardrobe.earn_text(id)]))
		_speak(Wardrobe.ITEMS[id].name + ". " + GameState.talk("shop_earn", [Wardrobe.earn_text(id)]))
		return
	# the finest items get a word from Racoon; otherwise his last line goes
	match str(Wardrobe.ITEMS[id].tier):
		"diamond":
			bubble.say(GameState.talk("shop_diamond"))
		"gold":
			bubble.say(GameState.talk("shop_gold"))
		_:
			bubble.hide_bubble()
	if w.is_worn(id):
		button.text = "TAKE OFF"
		button.face_color = Palette.PAPER_DEEP
	elif w.owns(id):
		button.text = "WEAR"
		button.face_color = Palette.BLUE
	else:
		button.text = "BUY  %d" % Wardrobe.ITEMS[id].price
		button.full_color = true   # the gold paper coin (D-027)
		button.icon_name = "coin"
		var can := int(GameState.wallet.coins) >= int(Wardrobe.ITEMS[id].price)
		button.face_color = Palette.ORANGE if can else Palette.PAPER_DEEP.darkened(0.2)


func _on_action() -> void:
	var id := _selected
	if id == "":
		return
	var w := GameState.wardrobe
	var slot: String = Wardrobe.ITEMS[id].slot
	if w.is_worn(id):
		GameState.take_off(slot)
		raccoon.set_mood("encourage")
	elif w.owns(id):
		GameState.wear_item(id)
		raccoon.set_mood("happy")
	else:
		match GameState.buy_item(id):
			"bought":
				Sfx.play("coin")
				raccoon.set_mood("celebrate")
				bubble.say(GameState.line("shop_bought"))
			"poor":
				raccoon.set_mood("thinking")
				bubble.say(GameState.line("shop_poor"))
				return
			"earn":
				raccoon.set_mood("encourage")
				bubble.say(GameState.talk("shop_earn", [Wardrobe.earn_text(id)]))
				_speak(GameState.talk("shop_earn", [Wardrobe.earn_text(id)]))
				return
	_show_slot(slot)
	_select(id)


## Reads a line aloud, for children who can't read it yet.
## Says it in the buddy's language (D-033); "en" for the tabs' English names.
func _speak(text: String, language: String = "") -> void:
	var speech := get_node_or_null("/root/Speech")
	if speech:
		speech.say(text, language)


func _update_coins() -> void:
	%Coins.text = str(GameState.wallet.coins)


## The Closet opens from the hub (Shop, Closet tab), so Back goes home (D-015).
func _back() -> void:
	GameState.go_home()
