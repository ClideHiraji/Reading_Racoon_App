extends Control
## The Play picker (D-015, the approved "Play picker" wireframe): diamond tiles
## like a game's mode screen. Adventure is always the big gold diamond in the
## middle, with the current world; Library, Practice, Watch & Listen and the Big
## Test sit around it. A locked tile stays in place, grey, and Racoon says when
## it opens (FR-12): only Adventure follows the school schedule.

const BIG := 380.0
const SMALL := 260.0
## Centre-to-centre distance along each axis between the big tile and a small one.
const STEP := 172.0

@onready var raccoon: Raccoon = %Raccoon
@onready var bubble: SpeechBubble = %Bubble

var tiles := {}


func _ready() -> void:
	if not GameState.guard_hub():
		return
	%HomeButton.pressed.connect(GameState.go_home)
	_style()
	%Coins.text = str(GameState.wallet.coins)
	_build()
	resized.connect(_place)
	_place()
	await get_tree().process_frame
	_say("Where shall we go today?", "happy")


func _say(text: String, mood: String) -> void:
	raccoon.set_mood(mood)
	bubble.say(text)
	Speech.say(text)


func _build() -> void:
	var level := mini(GameState.model.highest_unlocked, maxi(GameState.content_max_level(), 1))
	var info := SkillCatalog.world(level)
	var adventure_open := AccessPolicy.is_open(GameState.access_decision())
	var free := GameState.free_play_decision()
	var free_open := AccessPolicy.is_open(free)

	var at := GameState.adventure_opens_text()
	_add("adventure", "Adventure", info.name if adventure_open else (
			"Opens %s" % at if at != "" else "Resting"), info.icon, Palette.MANGO,
			not adventure_open, BIG, 40, true)
	for id in ["library", "practice", "watch"]:
		var s := HubSections.get_info(id)
		_add(id, s.name, _free_line(id, free), s.icon, s.color, not free_open, SMALL,
				26 if id == "watch" else 30)
	var post := GameState.post_test_ready()
	_add("post", "Big Test", "Ready!" if post and adventure_open else "Not yet", "stories",
			Palette.PLUM_LIGHT, not (post and adventure_open), SMALL, 30)
	_update_footer(adventure_open, free)


func _free_line(id: String, free: Dictionary) -> String:
	if free.status == "free_limit":
		return "Tomorrow"
	return {"library": "Stories", "practice": "Games", "watch": "Videos"}[id]


func _add(id: String, title: String, sub: String, icon: String, color: Color, locked: bool,
		px: float, title_px: int, dark := false) -> void:
	var t := DiamondTile.new()
	t.title = title
	t.subtitle = sub
	t.icon_name = icon
	t.face_color = color
	t.locked = locked
	t.dark_text = dark
	t.title_size = title_px
	t.size = Vector2(px, px + t.lift)
	t.tooltip_text = title
	t.pressed.connect(_on_tile.bind(id))
	%Tiles.add_child(t)
	tiles[id] = t


## The big tile sits low in the middle; the four small ones touch its edges.
func _place() -> void:
	if tiles.is_empty():
		return
	var c := Vector2(size.x / 2.0, size.y - 470.0)
	var at := {"adventure": c, "library": c + Vector2(-STEP, -STEP),
			"practice": c + Vector2(STEP, -STEP), "watch": c + Vector2(-STEP, STEP),
			"post": c + Vector2(STEP, STEP)}
	for id in tiles:
		var t: DiamondTile = tiles[id]
		t.position = at[id] - Vector2(t.size.x, t.size.y - t.lift) / 2.0
	# The big tile is drawn last so its corners overlap the small ones.
	%Tiles.move_child(tiles.adventure, -1)


func _on_tile(id: String) -> void:
	var t: DiamondTile = tiles[id]
	if t.locked:
		_shake(t)
		match id:
			"adventure":
				var at := GameState.adventure_opens_text()
				_say("Adventure is resting%s. Try the Library!" % (
						" until %s" % at if at != "" else ""), "thinking")
			"post":
				_say("Your teacher will open the Big Test.", "thinking")
			_:
				_say("Free play is done for today. See you tomorrow!", "encourage")
		return
	Speech.stop()
	if id == "post":
		GameState.start_assessment("post")
	else:
		GameState.open_section(id)


func _shake(node: Control) -> void:
	var x := node.position.x
	var tw := create_tween()
	for d in [12.0, -12.0, 8.0, 0.0]:
		tw.tween_property(node, "position:x", x + d, 0.05)


func _update_footer(adventure_open: bool, free: Dictionary) -> void:
	%Footer.visible = true
	match free.status:
		"free_play":
			%FooterIcon.texture = Icons.tex("sun")
			%FooterText.text = "Free play left today: %d min" % free.minutes_left
			var cap := float(GameState.access.schedule.get("free_play_minutes",
					AccessPolicy.DEFAULTS.free_play_minutes))
			%FooterBar.value = clampf(free.minutes_left / maxf(cap, 1.0), 0.0, 1.0)
			%FooterBar.visible = true
		"free_limit":
			%FooterIcon.texture = Icons.tex("star")
			%FooterText.text = "Free play is done for today!"
			%FooterBar.visible = false
		_:
			if not adventure_open:
				%Footer.visible = false
				return
			%FooterIcon.texture = Icons.tex("book")
			%FooterText.text = "Reading time! Everything is open."
			%FooterBar.visible = false
	%FooterIcon.self_modulate = Palette.MANGO_DEEP


func _style() -> void:
	var glass := Color(Palette.CARD, 0.94)
	%CoinsPill.add_theme_stylebox_override("panel", _box(glass, 30, 4, Vector4(14, 8, 18, 8)))
	%CoinsIcon.texture = Icons.tex("coins")
	%CoinsIcon.self_modulate = Palette.MANGO_DEEP
	%Footer.add_theme_stylebox_override("panel", _box(glass, 26, 5, Vector4(24, 14, 24, 14)))
	%FooterBar.add_theme_stylebox_override("background", _box(Palette.PAPER_DEEP, 7, 0))
	%FooterBar.add_theme_stylebox_override("fill", _box(Palette.ORANGE, 7, 0))


func _box(col: Color, r: int, lift: int, pad := Vector4.ZERO) -> StyleBoxFlat:
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
