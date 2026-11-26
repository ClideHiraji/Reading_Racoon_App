extends Control
## Spin the Words, Syllable Train and Story Shuffle: five rounds with the lesson task
## screens, just for fun. No hearts, no BKT. A right answer glows green, a wrong one
## shows the answer, and the next round comes by itself. Round dots in the header.

const ROUNDS := 5
const TASKS := {
	"tap_choice": preload("res://scenes/tasks/tap_choice_task.tscn"),
	"drag_letter": preload("res://scenes/tasks/drag_letter_task.tscn"),
	"order_tiles": preload("res://scenes/tasks/order_tiles_task.tscn"),
	"spin_words": preload("res://scenes/tasks/spin_words_task.tscn"),
}

var _game := {}
var _items: Array = []
var _i := -1
var _right := 0
var _started := 0
var _shown_passage := ""
var _holder: FitBox
var _prompt: Label
var _dots: HBoxContainer
var _results: Array = []
var _raccoon: Raccoon
var _bubble: SpeechBubble
var _task: Node


func _ready() -> void:
	if not GameState.guard_free_play():
		return
	_started = Time.get_ticks_msec()
	_game = PracticePool.game(GameState.practice_game)
	var column := Kit.page(self)
	_dots = Kit.game_header(column, str(_game.get("name", "Practice")), _back).dots
	# On a laptop Racoon stands in a column beside the prompt and the task, like in a lesson.
	var wide := Kit.landscape()
	var main: Control = column
	var side: Control = column
	if wide:
		var body := HBoxContainer.new()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 24)
		column.add_child(body)
		side = VBoxContainer.new()
		side.custom_minimum_size = Vector2(280, 0)
		side.alignment = BoxContainer.ALIGNMENT_END
		side.add_theme_constant_override("separation", 30)
		body.add_child(side)
		main = VBoxContainer.new()
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.add_theme_constant_override("separation", 18)
		body.add_child(main)
	var prompt_card := Kit.card(16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	prompt_card.add_child(row)
	var speak := ChunkyButton.new()
	speak.face_color = Palette.BLUE
	speak.icon_name = "speaker"
	speak.icon_px = 40
	speak.expand_icon = true
	speak.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speak.radius = 48
	speak.lift = 5
	speak.custom_minimum_size = Vector2(96, 96)
	speak.pressed.connect(_speak)
	row.add_child(speak)
	_prompt = Kit.label("", 30, Palette.INK, true)
	_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_prompt)
	main.add_child(prompt_card)
	_holder = FitBox.new()   # a big task shrinks to fit instead of falling off
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(_holder)
	_raccoon = Raccoon.new()
	_bubble = SpeechBubble.new()
	_bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if wide:
		_bubble.tail = "down"
		_bubble.tail_x = 100.0
		side.add_child(_bubble)
		_raccoon.custom_minimum_size = Vector2(180, 180)
		_raccoon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		side.add_child(_raccoon)
	else:
		var talk := HBoxContainer.new()
		talk.add_theme_constant_override("separation", 12)
		_raccoon.custom_minimum_size = Vector2(120, 120)
		talk.add_child(_raccoon)
		_bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		talk.add_child(_bubble)
		column.add_child(talk)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pool := PracticePool.task_items(GameState.bank, GameState.model.highest_unlocked,
			str(_game.get("task", "")), str(_game.get("variant", "")))
	_items = PracticePool.pick(pool, ROUNDS, rng)
	# Story Shuffle keeps one story's questions together, like the lessons.
	_items.sort_custom(func(a, b): return str(a.get("passage", "")) < str(b.get("passage", "")))
	await get_tree().process_frame
	_next()


func _next() -> void:
	_i += 1
	if _task:
		_task.queue_free()
		_task = null
	if _i >= _items.size():
		_finish()
		return
	Kit.show_rounds(_dots, _items.size(), _results)
	var item: Dictionary = _items[_i]
	var pid := str(item.get("passage", ""))
	if pid != "" and pid != _shown_passage:
		_shown_passage = pid
		var page := StoryPage.new()
		page.setup(GameState.bank.passage(pid))
		page.done.connect(_start)
		_task = page
		_holder.add_child(page)
		var p := GameState.bank.passage(pid)
		_prompt.text = str(p.get("title", "Story"))   # the page reads itself aloud
		return
	_start()


func _start() -> void:
	if _task:
		_task.queue_free()
	var item: Dictionary = _items[_i]
	_task = TASKS.get(item.task_type, TASKS.tap_choice).instantiate()
	_holder.add_child(_task)
	_task.setup(item)
	_task.answered.connect(_on_answered)
	_prompt.text = item.prompt
	Speech.new_question()
	_speak()


func _speak() -> void:
	if _i < _items.size():
		var item: Dictionary = _items[_i]
		Speech.say(str(item.get("tts_text", item.get("prompt", ""))), str(item.get("language", "en")))


func _on_answered(answer: String, _ms: int) -> void:
	var item: Dictionary = _items[_i]
	var right := str(item.answer)
	var ok := answer == right
	_task.show_result(answer, right)
	_results.append("right" if ok else "almost")
	Kit.show_rounds(_dots, _items.size(), _results)
	if ok:
		_right += 1
		Sfx.play("correct")
		GameState.learn_words(Collection.words_from_item(item), "game")
		_say(GameState.line("correct"), "happy")
	else:
		Sfx.play("wrong")
		_say(GameState.talk("practice_almost"), "encourage")
	await get_tree().create_timer(1.6 if ok else 2.4).timeout
	if is_inside_tree():
		_next()


func _say(text: String, mood: String) -> void:
	_raccoon.set_mood(mood)
	_bubble.say(text)


func _finish() -> void:
	_prompt.text = "All done!"
	var seconds := (Time.get_ticks_msec() - _started) / 1000.0
	var result := GameState.finish_practice(str(_game.get("id", "")), _right, _items.size(), seconds)
	Kit.reward(self, GameState.talk("reward_round", [_right, _items.size()]), result, _back)


func _back() -> void:
	Speech.stop()
	get_tree().change_scene_to_file("res://scenes/practice/practice.tscn")
