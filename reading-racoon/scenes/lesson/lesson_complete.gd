extends Control
## Lesson-complete screen (FR-15): stars, the coins earned, one stamp per answer,
## paper confetti and a celebrating raccoon in a sunburst. A Level Up shows the
## "New world unlocked!" card next (D-007, D-009). D-022: earned stars are the
## gold animated star; XP and the accuracy % stay in the data and the teacher's
## dashboard but aren't shown to the child; confetti falls behind Racoon's bubble.


var _sum := {}


func _ready() -> void:
	_sum = GameState.last_summary
	move_child(%Confetti, %Burst.get_index() + 1)   # behind the bubble and cards (D-022)
	%ContinueButton.pressed.connect(_on_continue)
	%GoButton.pressed.connect(_to_path)
	%Unlock.hide()
	if _sum.is_empty():
		_to_path.call_deferred()
		return
	if _sum.has("kind"):
		_show_test_done()
		return
	var early: bool = _sum.ended_early
	%Title.text = "Let's rest!" if early else "Lesson complete!"
	%Burst.visible = not early
	_build_stats()
	_build_answers()
	_animate_stars(_sum.stars)
	%Raccoon.set_mood("sleepy" if early else "celebrate")
	Sfx.play("fanfare")
	var line := GameState.line("session_end" if early else "lesson_done")
	%Bubble.say(line)
	Speech.say(line)
	if not early:
		_confetti()
	# D-017: a sticker (once a day) and today's goal, shown after the stars.
	var rewards: Dictionary = _sum.get("rewards", {})
	if not rewards.get("stickers", []).is_empty() or rewards.get("goals_done", false):
		await get_tree().create_timer(2.2).timeout
		if is_inside_tree():
			Kit.reward(self, "Sticker time!", rewards, func(): pass)


## End of the Reading Adventure (pre/post-test), D-021: one bar per reading skill
## with "Great!" (BKT replay reaches mastery, as in placement) or "Practice",
## where the path starts, the coins earned, then GO HOME to the hub (D-015).
func _show_test_done() -> void:
	var pre: bool = _sum.kind == "pre"
	%Title.text = "Adventure complete!" if pre else "Big Reading Day done!"
	%Stars.hide()
	%Answers.hide()
	%Stats.hide()
	%Raccoon.custom_minimum_size = Vector2(180, 180)
	%ContinueButton.text = "GO HOME"
	%ContinueButton.icon_name = "house"
	var results := _results_card(pre)
	var column: Node = %Stats.get_parent()
	column.add_child(results)
	column.move_child(results, %Stats.get_index())
	var foot := _test_footer(pre)
	column.add_child(foot)
	column.move_child(foot, results.get_index() + 1)
	%Raccoon.set_mood("celebrate")
	Sfx.play("fanfare")
	var passed: Dictionary = _sum.get("passed", {})
	var strong := passed.values().count(true)
	var key := "results_mixed"
	if strong == passed.size():
		key = "results_all_strong"
	elif strong == 0:
		key = "results_all_practice"
	var line := GameState.line(key)
	%Bubble.say(line)
	Speech.say(GameState.line("adventure_done") + " " + line)
	_confetti()


## "What you showed Racoon": one row per sub-skill in the test.
func _results_card(pre: bool) -> PanelContainer:
	var card := Kit.card(22)
	card.name = "Results"
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 14)
	card.add_child(rows)
	var before: Dictionary = {} if pre else GameState.assessments.get("pre", {}).get("scores", {})
	var scores: Dictionary = _sum.get("scores", {})
	var passed: Dictionary = _sum.get("passed", {})
	for skill in SkillCatalog.SKILLS:
		if scores.has(skill):
			rows.add_child(_skill_row(skill, scores[skill], bool(passed.get(skill, false)),
					before.get(skill, {})))
	return card


func _skill_row(skill: String, score: Dictionary, strong: bool, before: Dictionary) -> HBoxContainer:
	var color := Palette.LEAF if strong else Palette.ORANGE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(Kit.disc(SkillCatalog.ICONS[skill], color, 62))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	var name_label := Kit.label(SkillCatalog.NAMES[skill], 28, Palette.INK, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var count := "%d / %d" % [score.correct, score.total]
	if not before.is_empty():
		count += "  (was %d)" % before.get("correct", 0)
	var count_label := Kit.label(count, 24, Palette.INK_SOFT)
	count_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(count_label)
	mid.add_child(top)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 24)
	bar.max_value = maxi(int(score.total), 1)
	bar.value = score.correct
	bar.add_theme_stylebox_override("background", Kit.box(Palette.PAPER_DEEP, 12))
	bar.add_theme_stylebox_override("fill", Kit.box(color, 12))
	mid.add_child(bar)
	row.add_child(mid)
	# A colored word, not a pill: it isn't a button (D-022).
	var word := Kit.label("Great!" if strong else "Practice", 26,
			Palette.readable(Palette.deep(color)), true)
	word.autowrap_mode = TextServer.AUTOWRAP_OFF
	word.custom_minimum_size = Vector2(118, 0)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(word)
	return row


## Where the path starts (pre-test) and the coins earned, on one line.
func _test_footer(pre: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Footer"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	if pre:
		var lvl: int = maxi(int(_sum.placed_level), 1)
		row.add_child(Icons.rect("star", 40, Palette.MANGO_DEEP))
		var start := Kit.label("Your path starts at Level %d, %s" % [lvl, SkillCatalog.world(lvl).name],
				26, Palette.INK, true)
		start.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(start)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(14, 0)
		row.add_child(gap)
	row.add_child(Icons.rect("coins", 40, Palette.CORAL_DEEP))
	var coins := Kit.label("+%d" % _sum.coins, 26, Palette.INK, true)
	coins.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(coins)
	return row


func _build_stats() -> void:
	_stat("COINS", "coins", "+%d" % _sum.coins, Palette.CORAL)


## A paper stat card: colored header tab, icon and big number on cream.
func _stat(title: String, icon: String, value: String, color: Color) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(24)
	sb.set_content_margin_all(5)
	sb.shadow_color = Color(Palette.SHADOW, 0.2)
	sb.shadow_offset = Vector2(0, 7)
	sb.shadow_size = 1
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(300, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.theme_type_variation = &"TitleLabel"
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Palette.text_on(color))
	v.add_child(head)
	var body := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Palette.CARD
	bsb.set_corner_radius_all(20)
	bsb.set_content_margin_all(14)
	body.add_theme_stylebox_override("panel", bsb)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.add_child(Icons.rect(icon, 40, Palette.readable(Palette.deep(color))))
	var val := Label.new()
	val.text = value
	val.theme_type_variation = &"TitleLabel"
	val.add_theme_font_size_override("font_size", 38)
	val.add_theme_color_override("font_color", Palette.readable(Palette.deep(color)))
	row.add_child(val)
	body.add_child(row)
	v.add_child(body)
	%Stats.add_child(card)


## One round stamp per answer: green with a check (first try), yellow with a
## check (second try, D-021), or a hollow mango ring (missed or skipped).
func _build_answers() -> void:
	for r in _sum.results:
		var stamp := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(22)
		sb.set_content_margin_all(8)
		var solved: bool = r.get("solved", r.correct)
		var face := Palette.LEAF if r.correct else Palette.YELLOW
		if solved:
			sb.bg_color = face
		else:
			sb.bg_color = Palette.CARD
			sb.border_color = Palette.MANGO_DEEP
			sb.set_border_width_all(4)
		stamp.add_theme_stylebox_override("panel", sb)
		stamp.custom_minimum_size = Vector2(44, 44)
		if solved:
			stamp.add_child(Icons.rect("check", 26, Palette.text_on(face)))
		%Answers.add_child(stamp)


## Three stars, the middle one bigger and raised. Earned ones are the gold
## animated star, popping in one after another (D-022); the rest stay flat.
func _animate_stars(count: int) -> void:
	for i in 3:
		var px := 150.0 if i == 1 else 112.0
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(px, px + 24)
		var y := 0.0 if i == 1 else 24.0
		if i < count:
			# The animated star settles at about half its box.
			var star := AnimatedStar.make(px * 2.1, 0.2 + i * 0.35)
			star.size = Vector2(px, px) * 2.1
			star.position = Vector2(px, px) * -0.55 + Vector2(0, y)
			holder.add_child(star)
			get_tree().create_timer(0.3 + i * 0.35).timeout.connect(Sfx.play.bind("pop"))
		else:
			var star := Icons.rect("star", px, Palette.PAPER_DEEP.darkened(0.08))
			star.position = Vector2(0, y)
			star.size = Vector2(px, px)
			holder.add_child(star)
		%Stars.add_child(holder)


func _confetti() -> void:
	var p: CPUParticles2D = %Confetti
	p.position = Vector2(size.x / 2, -20)
	p.emission_rect_extents = Vector2(size.x / 2, 10)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	g.colors = PackedColorArray([Palette.YELLOW, Palette.BLUE, Palette.ORANGE, Palette.LEAF,
			Palette.CREAM])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = g
	p.restart()


func _on_continue() -> void:
	if _sum.get("level_up", false) and not %Unlock.visible:
		var to := mini(GameState.model.highest_unlocked, SkillCatalog.MAX_LEVEL)
		var info := SkillCatalog.world(to)
		%UnlockScenery.scene = info.scene
		%UnlockName.text = "Level %d  ·  %s" % [to, info.name]
		%Unlock.show()
		Sfx.play("fanfare")
		Speech.say("New world unlocked! " + info.name)
		_confetti()
		return
	_to_path()


## After a lesson: back to the path. After the pre/post-test: the home hub (D-015).
func _to_path() -> void:
	Speech.stop()
	if _sum.get("kind", "") in ["pre", "post"]:
		GameState.go_home()
		return
	get_tree().change_scene_to_file("res://scenes/path/learning_path.tscn")
