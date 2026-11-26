extends BoxContainer
## Rhyme Pop as a lesson task: the answers ride on balloons, like Practice's Rhyme Pop.
## The balloons only bob in place, so speed never matters; a tap answers.
## Content: a tap_choice item with "variant": "rhyme_pop".

signal answered(answer: String, ms: int)

const COLORS := [Palette.BLUE, Palette.ORANGE, Palette.YELLOW, Palette.LEAF]
const LANE := 200.0               # one balloon (170 px) and its gap

var _cards := {}                  # answer id -> Balloon (the lesson points at the right one)
var _started := 0
var _locked := false


func setup(item: Dictionary) -> void:
	_started = Time.get_ticks_msec()
	vertical = not Kit.landscape()   # on a laptop the word stands beside the balloons
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 48 if Kit.landscape() else 24)
	var stage := CenterContainer.new()
	add_child(stage)
	var card := PictureCard.new()
	card.setup(item.get("picture", ""), str(item.get("word", "")), 170.0)
	stage.add_child(card)
	var sky := Control.new()
	var n: int = item.choices.size()
	sky.custom_minimum_size = Vector2(LANE * n, 300)
	sky.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sky.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(sky)
	for i in n:
		var c: Dictionary = item.choices[i]
		var b := Balloon.new()
		b.word = str(c.get("label", c.id))
		b.picture = str(c.get("picture", "")) if Icons.exists(str(c.get("picture", ""))) else ""
		b.color = COLORS[i % COLORS.size()]
		b.tooltip_text = b.word
		b.position = Vector2(LANE * i + (LANE - 170.0) / 2, 24)
		sky.add_child(b)
		# A gentle bob, each balloon out of step with the next.
		var t := b.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "position:y", 4.0, 1.2 + i * 0.25)
		t.tween_property(b, "position:y", 44.0, 1.2 + i * 0.25)
		b.pressed.connect(_on_pop.bind(str(c.id)))
		_cards[str(c.id)] = b


func _on_pop(id: String) -> void:
	if _locked:
		return
	_locked = true
	answered.emit(id, Time.get_ticks_msec() - _started)


## Second try: the balloon already tried goes soft and can't be popped again.
func try_again(chosen: String) -> void:
	if _cards.has(chosen):
		var b: Balloon = _cards[chosen]
		b.disabled = true
		create_tween().tween_property(b, "modulate:a", 0.4, 0.2)
	_started = Time.get_ticks_msec()
	_locked = false


## The right balloon turns green and pops up big; a wrong pick turns orange.
func show_result(chosen: String, answer: String) -> void:
	for id in _cards:
		var b: Balloon = _cards[id]
		b.disabled = true
		if id == answer:
			b.color = Palette.RIGHT
			b.pivot_offset = b.size / 2
			var t := create_tween()
			t.tween_property(b, "scale", Vector2(1.15, 1.15), 0.12)
			t.tween_property(b, "scale", Vector2.ONE, 0.18)
		elif id == chosen:
			b.color = Palette.ALMOST
		else:
			b.modulate.a = 0.45
