class_name SettingsCard
## Settings (D-042), from the gear on Home: how loud the voice and the sounds are, graphics and frame rate,
## the buddy and language, full screen on a laptop, and signing out or closing the game. Sound and display
## settings are the device's, saved in user://settings.cfg; the buddy and language stay in the student's
## profile.

const PATH := "user://settings.cfg"
## Volume steps (0-100), big chips rather than a thin slider for small fingers (NFR-02).
const LEVELS := [[0, "Off"], [40, "Soft"], [80, "Medium"], [100, "Loud"]]   # 80: the loudness before Settings
## High draws at the screen's own resolution with smoothed edges; Low draws the game at its base size
## (720 x 1280, or 1280 x 720 on a laptop) and scales the picture up: lighter for slow laptops and phones.
const QUALITY := [["high", "High"], ["low", "Low"]]
## Frames a second: 30 saves battery and heat.
const FRAME_RATES := [["60", "60"], ["30", "30"]]


## Puts the saved settings in place at start-up (Screen calls it once the autoloads are ready).
static func apply_saved(tree: SceneTree) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # no file yet: the defaults below
	tree.root.get_node("Speech").volume = int(cfg.get_value("sound", "voice", 80))
	tree.root.get_node("Sfx").volume = int(cfg.get_value("sound", "effects", 80))
	graphics(tree, str(cfg.get_value("display", "quality", "high")))
	Engine.max_fps = int(cfg.get_value("display", "fps", 0))   # never picked: the screen's own rate, as before
	if OS.has_feature("pc") and not OS.has_feature("editor"):
		_full_screen(bool(cfg.get_value("display", "full_screen", true)))


## High or Low graphics, at once.
static func graphics(tree: SceneTree, quality: String) -> void:
	var low := quality == "low"
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if low else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Smooth.enabled = not low


static func _save(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value(section, key, value)
	cfg.save(PATH)


static func _full_screen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


static func open(root: Control) -> void:
	var col := Kit.overlay(root)
	var dim: Control = col.get_meta("overlay")
	col.add_child(Kit.label("Settings", 40, Palette.INK, true))
	var left := col
	var right := col
	if Kit.landscape():   # a laptop's screen is short: the chips beside the buttons (D-023)
		var two := HBoxContainer.new()
		two.add_theme_constant_override("separation", 40)
		col.add_child(two)
		left = VBoxContainer.new()
		right = VBoxContainer.new()
		left.custom_minimum_size.x = 480    # four chips on one line (a flow asks for no width of its own)
		right.custom_minimum_size.x = 440
		for v in [left, right]:
			v.add_theme_constant_override("separation", 18)
			two.add_child(v)
	# Autoloads looked up, not named: the tests load this class before they exist.
	var gs: Node = root.get_node("/root/GameState")
	var speech: Node = root.get_node("/root/Speech")
	var sfx: Node = root.get_node("/root/Sfx")
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	left.add_child(_volume(speech, "Voice", "voice", func(): speech.say(gs.talk("read_together"))))
	left.add_child(_volume(sfx, "Sounds", "effects", func(): sfx.play("correct")))
	var display := HBoxContainer.new()
	display.add_theme_constant_override("separation", 40)
	left.add_child(display)
	display.add_child(_group("Graphics", QUALITY, str(cfg.get_value("display", "quality", "high")), func(v):
		graphics(root.get_tree(), v)
		_save("display", "quality", v)))
	display.add_child(_group("Frame rate", FRAME_RATES, str(cfg.get_value("display", "fps", 60)), func(v):
		Engine.max_fps = int(v)
		_save("display", "fps", int(v))))
	var buddy := Kit.button("Buddy and language", Palette.BLUE, "talk", 96)
	buddy.add_theme_font_size_override("font_size", 30)
	buddy.pressed.connect(func():
		speech.stop()
		root.get_tree().change_scene_to_file(gs.BUDDY_SCENE))
	right.add_child(buddy)
	if OS.has_feature("pc"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		var fs := Kit.button("Full screen: on" if full else "Full screen: off", Palette.BLUE,
				"full_screen_exit" if full else "full_screen", 96)
		fs.add_theme_font_size_override("font_size", 30)
		fs.pressed.connect(func():
			var on := DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
			_full_screen(on)
			_save("display", "full_screen", on)
			fs.text = "Full screen: on" if on else "Full screen: off"
			fs.icon_name = "full_screen_exit" if on else "full_screen")
		right.add_child(fs)
	var leave := HBoxContainer.new()
	leave.add_theme_constant_override("separation", 16)
	right.add_child(leave)
	leave.add_child(_two_tap("Sign out", "Tap again to sign out", func(b: ChunkyButton):
		if gs.sign_out():
			speech.stop()
			root.get_tree().change_scene_to_file("res://scenes/login/login.tscn")
			return
		b.text = "Saving first..."   # answers still waiting: nothing is lost (sign_out)
		speech.say(gs.talk("start_wait_saving"))
		root.get_node("/root/Sync").request_soon()))
	var done := Kit.button("Done", Palette.ORANGE, "check", 96)
	done.add_to_group("back_cancel")   # Back or Escape closes the card (Screen.back)
	done.pressed.connect(dim.queue_free)
	if OS.has_feature("pc"):   # a phone or tablet just goes Home, and has Done beside Sign out instead
		leave.add_child(_two_tap("Close game", "Tap again to close", func(_b): root.get_tree().quit()))
		right.add_child(done)
	else:
		done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		leave.add_child(done)


## A volume's chips: a pick is saved and plays a sample at the new loudness.
static func _volume(target: Node, title: String, key: String, sample: Callable) -> VBoxContainer:
	return _group(title, LEVELS.map(func(l): return [str(l[0]), l[1]]), str(_nearest(target.volume)), func(v):
		target.volume = int(v)
		_save("sound", key, int(v))
		if int(v) > 0:
			sample.call())


## A title over a row of chips, one of them picked; `on_pick` gets the new value.
static func _group(title: String, options: Array, selected: String, on_pick: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # two groups in a row share it (chips ask no width)
	box.add_child(Kit.label(title, 30, Palette.INK, true))
	var row := []   # the chips, for the pick below (a lambda keeps a copy of a plain local)
	row.append(Kit.chips(options, selected, func(v):
		for i in row[0].get_child_count():
			row[0].get_child(i).card_style = str(options[i][0]) != v
		on_pick.call(v)))
	box.add_child(row[0])
	return box


static func _nearest(volume: int) -> int:
	var best: int = LEVELS[0][0]
	for l in LEVELS:
		if absi(int(l[0]) - volume) < absi(best - volume):
			best = l[0]
	return best


## A button that asks for a second tap before it acts (as the start screen's Switch student does).
static func _two_tap(text: String, again: String, act: Callable) -> ChunkyButton:
	var b := Kit.button(text, Palette.CARD, "", 96)
	b.add_theme_font_size_override("font_size", 28)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func():
		if b.text != again:
			b.text = again
			return
		act.call(b))
	return b
