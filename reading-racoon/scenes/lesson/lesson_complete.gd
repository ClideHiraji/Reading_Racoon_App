extends Control
## Lesson-complete screen (FR-15): stars, paper stat cards (XP, accuracy, coins),
## one stamp per answer, paper confetti and a celebrating raccoon in a sunburst.
## A Level Up shows the "New world unlocked!" card next (D-007, D-009).


var _sum := {}


func _ready() -> void:
	_sum = GameState.last_summary
	%ContinueButton.pressed.connect(_on_continue)
	%GoButton.pressed.connect(_to_path)
	%Unlock.hide()
	if _sum.is_empty():
		_to_path.call_deferred()
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


func _build_stats() -> void:
	_stat("XP", "bolt", "+%d" % _sum.xp, Palette.MANGO)
	_stat("CORRECT", "check", "%d%%" % roundi(_sum.accuracy * 100.0), Palette.LEAF)
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
	card.custom_minimum_size = Vector2(198, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.theme_type_variation = &"TitleLabel"
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Color.WHITE)
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
	row.add_child(Icons.rect(icon, 40, Palette.deep(color)))
	var val := Label.new()
	val.text = value
	val.theme_type_variation = &"TitleLabel"
	val.add_theme_font_size_override("font_size", 38)
	val.add_theme_color_override("font_color", Palette.deep(color))
	row.add_child(val)
	body.add_child(row)
	v.add_child(body)
	%Stats.add_child(card)


## One round stamp per answer: green with a check, or a hollow mango ring.
func _build_answers() -> void:
	for r in _sum.results:
		var stamp := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(22)
		sb.set_content_margin_all(8)
		if r.correct:
			sb.bg_color = Palette.LEAF
		else:
			sb.bg_color = Palette.CARD
			sb.border_color = Palette.MANGO_DEEP
			sb.set_border_width_all(4)
		stamp.add_theme_stylebox_override("panel", sb)
		stamp.custom_minimum_size = Vector2(44, 44)
		if r.correct:
			stamp.add_child(Icons.rect("check", 26, Color.WHITE))
		%Answers.add_child(stamp)


## Three stars, the middle one bigger and raised, popping in one by one.
func _animate_stars(count: int) -> void:
	var t := create_tween()
	for i in 3:
		var px := 150.0 if i == 1 else 112.0
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(px, px + 24)
		var star := Icons.rect("star", px, Palette.MANGO if i < count else Palette.PAPER_DEEP.darkened(0.08))
		star.position = Vector2(0, 0 if i == 1 else 24)
		star.size = Vector2(px, px)
		star.pivot_offset = Vector2(px, px) / 2
		star.scale = Vector2.ZERO
		holder.add_child(star)
		%Stars.add_child(holder)
		t.tween_interval(0.18)
		t.tween_property(star, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT)
		if i < count:
			t.tween_callback(Sfx.play.bind("pop"))


func _confetti() -> void:
	var p: CPUParticles2D = %Confetti
	p.position = Vector2(size.x / 2, -20)
	p.emission_rect_extents = Vector2(size.x / 2, 10)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	g.colors = PackedColorArray([Palette.MANGO, Palette.TEAL, Palette.CORAL, Palette.LEAF,
			Palette.PLUM])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = g
	p.restart()


func _on_continue() -> void:
	if _sum.get("level_up", false):
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


func _to_path() -> void:
	Speech.stop()
	get_tree().change_scene_to_file("res://scenes/path/learning_path.tscn")
