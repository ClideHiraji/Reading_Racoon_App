extends Control
## Choose your buddy: Roco the boy raccoon or Rina the girl, and the language the buddy
## talks in: English, Filipino or Bisaya. Shows the first time a student plays, and again
## from the profile chip on Home. Lessons keep their own language; this only changes
## what the buddy says and the menus.
## Tapping a buddy or a language plays a sample in that voice and language, before anything is saved.

const BUDDIES := ["roco", "rina"]

var _who := ""
var _lang := "en"
var _returning := false
var _cards := {}           # id -> {button, raccoon, name}
var _langs := {}           # lang -> ChunkyButton
var _title: Label
var _lang_title: Label
var _bubble: SpeechBubble
var _go: ChunkyButton


func _ready() -> void:
	_returning = GameState.buddy_chosen()
	_who = GameState.buddy_id() if _returning else ""
	_lang = GameState.talk_language()
	_build()
	_refresh()
	await get_tree().process_frame
	if _who != "":
		_cards[_who].raccoon.set_mood("happy")
	_say(_text("choose_hi") if _who != "" else _text("choose_buddy"))


func _exit_tree() -> void:
	GameState.use_buddy_voice()   # the previews borrowed the voice; give the student's back


func _build() -> void:
	var wide := Kit.landscape()
	var col := Kit.page(self, "village", 300.0)
	col.add_theme_constant_override("separation", 14 if wide else 20)
	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 96)
	col.add_child(top)
	if _returning:
		var home := Kit.home_button()
		home.add_to_group("back_button")   # Android Back and Escape
		home.tooltip_text = "Home"
		home.pressed.connect(GameState.go_home)
		top.add_child(home)
	_title = Kit.label("", 50 if not wide else 44, Palette.INK, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_title)
	_title.add_child(Squiggle.new())   # a crayon line under the title
	if _returning:
		var balance := Control.new()   # keeps the title in the middle
		balance.custom_minimum_size = Vector2(96, 0)
		top.add_child(balance)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 24)
	for id in BUDDIES:
		cards.add_child(_card(id, Vector2(270, 340) if wide else Vector2(300, 400)))
	_bubble = SpeechBubble.new()
	_bubble.tail = "up"
	_bubble.custom_minimum_size = Vector2(420, 0)
	_bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lang_title = Kit.label("", 36, Palette.INK, true)
	_lang_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var langs := HBoxContainer.new()
	langs.alignment = BoxContainer.ALIGNMENT_CENTER
	langs.add_theme_constant_override("separation", 14)
	for lang in GameState.TALK_LANGS:
		langs.add_child(_lang_button(lang))
	_go = Kit.button("", Palette.ORANGE, "arrow_right")
	_go.custom_minimum_size = Vector2(420, 120)
	_go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_go.pressed.connect(_done)
	# From Home, a quiet line on whether the stars have reached school.
	var saved: Control = _saved_line() if _returning else Control.new()
	if wide:
		# Laptop layout: the buddies on the left; what they say, the languages and Let's go on the right.
		var body := HBoxContainer.new()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 40)
		col.add_child(body)
		cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(cards)
		var side := VBoxContainer.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side.alignment = BoxContainer.ALIGNMENT_CENTER
		side.add_theme_constant_override("separation", 20)
		body.add_child(side)
		for n: Control in [_bubble, saved, _lang_title, langs, _go]:
			side.add_child(n)
	else:
		for n: Control in [cards, _bubble, saved]:
			col.add_child(n)
		var gap := Control.new()
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(gap)
		for n: Control in [_lang_title, langs, _go]:
			col.add_child(n)


func _saved_line() -> Label:
	var l := Kit.label(GameState.talk("hub_saved" if GameState.store.queue_size() == 0 else "hub_saving"),
		24, Palette.INK_SOFT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A buddy's card: the raccoon, as the student sees him or her everywhere, and the name.
func _card(id: String, px: Vector2) -> ChunkyButton:
	var b := ChunkyButton.new()
	b.name = id.capitalize()
	b.card_style = true
	b.face_color = Palette.MANGO
	b.radius = 36
	b.lift = 7
	b.custom_minimum_size = px
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = str(GameState.BUDDIES[id].name)
	b.pressed.connect(_pick.bind(id))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 10
	v.offset_bottom = -18
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_END
	b.add_child(v)
	var r := Raccoon.new()
	r.buddy = id
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = Vector2(px.x - 30, px.x - 30)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(r)
	var n := Kit.label(str(GameState.BUDDIES[id].name), 44, Palette.INK, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	_cards[id] = {"button": b, "raccoon": r, "name": n}
	return b


func _lang_button(lang: String) -> ChunkyButton:
	var b := ChunkyButton.new()
	b.text = str(GameState.TALK_LANGS[lang])   # each language's own name
	b.face_color = Palette.BLUE
	b.radius = 36
	b.lift = 5
	b.custom_minimum_size = Vector2(200, 96)
	b.add_theme_font_size_override("font_size", 30)
	b.tap_sound = true
	b.pressed.connect(_pick_lang.bind(lang))
	_langs[lang] = b
	return b


func _pick(id: String) -> void:
	_who = id
	_refresh()
	var r: Raccoon = _cards[id].raccoon
	r.play("happy")
	_say(_text("choose_hi"))


func _pick_lang(lang: String) -> void:
	_lang = lang
	_refresh()
	_say(_text("choose_hi") if _who != "" else _text("choose_buddy"))


## The picked card is yellow, the picked language blue; the words are in the picked language.
func _refresh() -> void:
	for id in _cards:
		var b: ChunkyButton = _cards[id].button
		b.card_style = id != _who
	for lang in _langs:
		_langs[lang].card_style = lang != _lang
	_title.text = _text("choose_buddy")
	_lang_title.text = _text("choose_lang")
	_go.text = _text("choose_done")
	_go.disabled = _who == ""
	_go.modulate.a = 1.0 if _who != "" else 0.45
	if _who != "":
		_bubble.speaker = _cards[_who].raccoon


func _text(key: String) -> String:
	return GameState.talk_as(key, _lang, _who if _who != "" else "roco")


## The picked buddy says it, in the picked language, in his or her own voice.
func _say(text: String) -> void:
	_bubble.say(text)
	GameState.use_buddy_voice(_who)
	Speech.say(text, _lang)


func _done() -> void:
	if _who == "":
		return
	GameState.set_buddy(_who, _lang)
	Speech.stop()
	if GameState.guard_hub():
		get_tree().change_scene_to_file(GameState.HUB_SCENE)
