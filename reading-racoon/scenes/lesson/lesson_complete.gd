extends Control
## Lesson-complete screen (FR-15): stars, stat cards (XP, accuracy, coins), one dot
## per answer, confetti and a celebrating raccoon. A Level Up shows the
## "New world unlocked!" card next (D-007).

const STAT_COLORS := {"xp": Color("ffc531"), "accuracy": Color("6bbf59"), "coins": Color("ff9f1c")}

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
	_stat("TOTAL XP", "⚡ %d" % _sum.xp, STAT_COLORS.xp)
	_stat("ACCURACY", "🎯 %d%%" % roundi(_sum.accuracy * 100.0), STAT_COLORS.accuracy)
	_stat("COINS", "💰 %d" % _sum.coins, STAT_COLORS.coins)


## A Duolingo-style stat card: colored header strip, white body.
func _stat(title: String, value: String, color: Color) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(4)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(196, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Color.WHITE)
	v.add_child(head)
	var body := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color.WHITE
	bsb.set_corner_radius_all(18)
	bsb.set_content_margin_all(14)
	body.add_theme_stylebox_override("panel", bsb)
	var val := Label.new()
	val.text = value
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 36)
	val.add_theme_color_override("font_color", color.darkened(0.3))
	body.add_child(val)
	v.add_child(body)
	%Stats.add_child(card)


func _build_answers() -> void:
	for r in _sum.results:
		var l := Label.new()
		l.text = "✅" if r.correct else "🟠"
		l.add_theme_font_size_override("font_size", 34)
		%Answers.add_child(l)


func _animate_stars(count: int) -> void:
	var t := create_tween()
	for i in 3:
		var star := Label.new()
		star.text = "⭐" if i < count else "☆"
		star.add_theme_font_size_override("font_size", 96)
		if i >= count:
			star.add_theme_color_override("font_color", Color("d9d2c5"))
		star.modulate.a = 0.0
		%Stars.add_child(star)
		t.tween_interval(0.25)
		t.tween_property(star, "modulate:a", 1.0, 0.15)
		if i < count:
			t.tween_callback(Sfx.play.bind("pop"))


func _confetti() -> void:
	var p: CPUParticles2D = %Confetti
	p.position = Vector2(size.x / 2, -20)
	p.emission_rect_extents = Vector2(size.x / 2, 10)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Color("ff9f1c"), Color("ffd23f"), Color("6bbf59"),
			Color("3fa7d6"), Color("e5596b")])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = g
	p.restart()


func _on_continue() -> void:
	if _sum.get("level_up", false):
		var to := mini(GameState.model.highest_unlocked, SkillCatalog.MAX_LEVEL)
		var info := SkillCatalog.world(to)
		%UnlockIcon.text = info.icon
		%UnlockName.text = "Level %d · %s" % [to, info.name]
		%Unlock.show()
		Sfx.play("fanfare")
		Speech.say("New world unlocked! " + info.name)
		_confetti()
		return
	_to_path()


func _to_path() -> void:
	Speech.stop()
	get_tree().change_scene_to_file("res://scenes/path/learning_path.tscn")
