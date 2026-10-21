extends Control
## Today (D-017): three small goals (read a story, play a game, finish a lesson
## or a song), with a Go button for each, and the days played this week. All
## three earn a goals sticker and 10 coins. A missed day is never lost (D-007).

const DAY_NAMES := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


func _ready() -> void:
	if not GameState.guard_hub():
		return
	var column := Kit.page(self, "home", 300)
	Kit.header(column, "Today", GameState.go_home)
	var talk := HBoxContainer.new()
	talk.add_theme_constant_override("separation", 12)
	var raccoon := Raccoon.new()
	raccoon.custom_minimum_size = Vector2(140, 140)
	talk.add_child(raccoon)
	var bubble := SpeechBubble.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	talk.add_child(bubble)
	column.add_child(talk)

	var today := GameState.today()
	var done: Array = GameState.collection.goals_done(today)
	var card := Kit.card(24)
	column.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	card.add_child(v)
	v.add_child(Kit.label("Today's goals", 34, Palette.INK, true))
	for g in Collection.GOALS:
		v.add_child(_goal_row(g, g.id in done))
	var left := GameState.collection.goals_left(today)
	var line := "All done! Great job today!" if left == 0 \
			else "Finish all three for a sticker and 10 coins!"
	v.add_child(Kit.label(line, 26, Palette.readable(Palette.LEAF) if left == 0 else Palette.INK_SOFT, true))

	var week := Kit.card(24)
	column.add_child(week)
	var w := VBoxContainer.new()
	w.add_theme_constant_override("separation", 14)
	week.add_child(w)
	w.add_child(Kit.label("Days you played this week", 30, Palette.INK, true))
	w.add_child(_week_row())

	await get_tree().process_frame
	var say := "You did everything today!" if left == 0 else "Here's what we can do today!"
	raccoon.set_mood("celebrate" if left == 0 else "happy")
	bubble.say(say)
	Speech.say(say)


func _goal_row(g: Dictionary, done: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(Kit.disc("check" if done else g.icon, Palette.LEAF if done else Palette.YELLOW, 76))
	var t := Kit.label(g.text, 30, Palette.INK, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	if not done:
		var go := Kit.button("Go!", Palette.ORANGE, "", 80)
		go.custom_minimum_size.x = 130
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		go.pressed.connect(_go.bind(g.section))
		row.add_child(go)
	return row


func _go(section: String) -> void:
	Speech.stop()
	if section == "adventure":
		get_tree().change_scene_to_file("res://scenes/hub/play_picker.tscn")
	else:
		GameState.open_section(section)


## Monday to Sunday of this week; played days get a sun, today gets a ring.
func _week_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var now := GameState.now_dict()
	var unix := int(Time.get_unix_time_from_datetime_dict(now))
	var from_monday := (int(now.weekday) + 6) % 7
	for i in 7:
		var d := Time.get_datetime_dict_from_unix_time(unix + (i - from_monday) * 86400)
		var date := "%04d-%02d-%02d" % [d.year, d.month, d.day]
		var played := GameState.collection.days.has(date)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		var disc := PanelContainer.new()
		var sb := Kit.box(Palette.YELLOW if played else Palette.CARD, 34)
		if i == from_monday:
			sb.set_border_width_all(4)
			sb.border_color = Palette.ORANGE
		elif not played:
			sb.set_border_width_all(3)
			sb.border_color = Palette.PAPER_DEEP
		disc.add_theme_stylebox_override("panel", sb)
		disc.custom_minimum_size = Vector2(68, 68)
		disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if played:
			var icon := Icons.rect("sun", 42, Palette.text_on(Palette.YELLOW))
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			disc.add_child(icon)
		col.add_child(disc)
		var n := Kit.label(DAY_NAMES[i], 20, Palette.INK_SOFT, true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.autowrap_mode = TextServer.AUTOWRAP_OFF
		col.add_child(n)
		row.add_child(col)
	return row
