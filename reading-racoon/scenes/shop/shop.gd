extends Control
## Racoon's Closet, the reward shop (FR-07): spend coins on hats, scarves, glasses
## and pins. Tap an item to try it on, then buy or wear it with the big button.
## Rewards are personal: no leaderboards (06-game-design.md reward cautions).

var _slot := "hat"
var _selected := ""

@onready var raccoon: Raccoon = %Raccoon
@onready var bubble: SpeechBubble = %Bubble


func _ready() -> void:
	%BackButton.pressed.connect(_back)
	%ActionButton.pressed.connect(_on_action)
	GameState.wallet_changed.connect(_update_coins)
	raccoon.follow_saved_outfit = false
	raccoon.outfit = GameState.wardrobe.equipped.duplicate()
	for slot in Wardrobe.SLOTS:
		var tab := ChunkyButton.new()
		tab.text = Wardrobe.SLOT_NAMES[slot]
		tab.custom_minimum_size = Vector2(0, 80)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.lift = 5
		tab.radius = 18
		tab.add_theme_font_size_override("font_size", 26)
		tab.pressed.connect(_show_slot.bind(slot))
		tab.set_meta("slot", slot)
		%Tabs.add_child(tab)
	_update_coins()
	_show_slot("hat")
	await get_tree().process_frame
	bubble.say(GameState.line("shop_hello"))


func _show_slot(slot: String) -> void:
	_slot = slot
	for tab in %Tabs.get_children():
		var on: bool = tab.get_meta("slot") == slot
		tab.card_style = not on
		tab.face_color = Palette.BLUE
	for c in %Grid.get_children():
		c.queue_free()
	for id in GameState.wardrobe.items_in(slot):
		%Grid.add_child(_card(id))
	_select("")


## An item card: a mini Racoon wearing only that item, its name and price.
func _card(id: String) -> Control:
	var item: Dictionary = Wardrobe.ITEMS[id]
	var card := ChunkyButton.new()
	card.card_style = true
	card.custom_minimum_size = Vector2(200, 262)
	card.pressed.connect(_select.bind(id))
	card.set_meta("id", id)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 6
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var mini := Raccoon.new()
	mini.follow_saved_outfit = false
	mini.outfit = {item.slot: id}
	mini.custom_minimum_size = Vector2(0, 150)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(mini)
	var name := Label.new()
	name.text = item.name
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.theme_type_variation = &"TitleLabel"
	name.add_theme_font_size_override("font_size", 22)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name)
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
	else:
		row.add_child(Icons.rect("coins", 26, Palette.MANGO_DEEP))
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
		raccoon.set_mood("happy")
	raccoon.outfit = preview
	for c in %Grid.get_children():
		if c is ChunkyButton:
			c.card_style = c.get_meta("id") != id
			c.face_color = Palette.pale(Palette.BLUE, 0.55)
	var button: ChunkyButton = %ActionButton
	button.icon_name = ""
	if id == "":
		%ItemName.text = "Tap something to try it on!"
		button.visible = false
		return
	button.visible = true
	%ItemName.text = Wardrobe.ITEMS[id].name
	var w := GameState.wardrobe
	if w.is_worn(id):
		button.text = "TAKE OFF"
		button.face_color = Palette.INK_SOFT
	elif w.owns(id):
		button.text = "WEAR"
		button.face_color = Palette.BLUE
	else:
		button.text = "BUY  %d" % Wardrobe.ITEMS[id].price
		button.icon_name = "coins"
		var can := int(GameState.wallet.coins) >= int(Wardrobe.ITEMS[id].price)
		button.face_color = Palette.CORAL if can else Palette.PAPER_DEEP.darkened(0.2)


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
	_show_slot(slot)
	_select(id)


func _update_coins() -> void:
	%Coins.text = str(GameState.wallet.coins)


## The Closet opens from the hub (Shop, Closet tab), so Back goes home (D-015).
func _back() -> void:
	GameState.go_home()
