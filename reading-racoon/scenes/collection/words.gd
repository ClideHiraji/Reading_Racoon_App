extends Control
## My Word Book (D-017, wireframe "My Word Book"): every word the child learns in
## Adventure, games and books lands here with its picture. Tap a word to hear it;
## "Practice my words" plays Memory Match with the child's own words.

const FROM := {"lesson": "from Adventure", "book": "from a book", "game": "from a game"}

var _lang := ""
var _column: VBoxContainer
var _chips: Control
var _grid: GridContainer
var _practice: ChunkyButton


func _ready() -> void:
	if not GameState.guard_hub():
		return
	_column = Kit.page(self)
	var head := Kit.header(_column, "My Word Book", GameState.go_home)
	var n := GameState.collection.words.size()
	var count := Kit.label("%d %s" % [n, "word" if n == 1 else "words"], 26, Palette.INK, true)
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.row.add_child(count)
	head.row.move_child(count, 2)
	_practice = Kit.button("Practice my words", Palette.ORANGE, "cat", 96)
	_practice.pressed.connect(_play)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_grid)
	_build()
	_column.add_child(scroll)
	_column.add_child(_practice)
	Speech.say("Your word book!")


func _build() -> void:
	if _chips:
		_chips.queue_free()
	var options := [["", "All"]]
	for l in MediaLibrary.LANGUAGES:
		options.append([l, MediaLibrary.LANGUAGES[l]])
	_chips = Kit.chips(options, _lang, _pick)
	_column.add_child(_chips)
	_column.move_child(_chips, 1)
	for c in _grid.get_children():
		c.queue_free()
	var list := GameState.collection.word_list(_lang)
	if list.is_empty():
		var empty := Kit.label("Words you learn in Adventure, games and books land here.", 28,
				Palette.INK_SOFT)
		empty.custom_minimum_size = Vector2(600, 0)
		_grid.add_child(empty)
	for w in list:
		_grid.add_child(_card(w, GameState.collection.words[w]))
	_practice.disabled = _own_words().size() < 3
	_practice.modulate.a = 0.5 if _practice.disabled else 1.0


func _pick(lang: String) -> void:
	_lang = lang
	_build()


func _card(word: String, info: Dictionary) -> Control:
	var b := ChunkyButton.new()
	b.card_style = true
	b.custom_minimum_size = Vector2(320, 250)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = word
	b.pressed.connect(func(): Speech.say(word, str(info.get("lang", "en"))))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 6)
	b.add_child(v)
	var pic := str(info.get("picture", ""))
	if Icons.exists(pic):
		var p := Kit.picture(pic, 110)
		p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(p)
	v.add_child(Kit.word_label(word, 42))
	var from := Kit.label(FROM.get(str(info.get("from", "")), ""), 20, Palette.INK_SOFT)
	from.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(from)
	return b


## Words with a picture in the current language filter, for Memory Match.
func _own_words() -> Array:
	var out := []
	for w in GameState.collection.word_list(_lang):
		var info: Dictionary = GameState.collection.words[w]
		if Icons.exists(str(info.get("picture", ""))):
			out.append({"word": w, "picture": info.picture, "lang": info.get("lang", "en")})
	return out


func _play() -> void:
	if not GameState.guard_free_play():
		return
	Speech.stop()
	GameState.practice_game = "memory_match"
	GameState.practice_words = _own_words()
	get_tree().change_scene_to_file("res://scenes/practice/memory_match.tscn")
