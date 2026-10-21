extends Control
## Spin the Words, Syllable Train and Story Shuffle (D-017): five rounds with the
## same task screens as the lessons, but just for fun. No hearts, no BKT; a
## right answer glows green, an "almost" shows the answer, and the next round
## comes by itself.

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
var _holder: VBoxContainer
var _prompt: Label
var _count: Label
var _raccoon: Raccoon
var _bubble: SpeechBubble
var _task: Node


func _ready() -> void:
	if not GameState.guard_free_play():
		return
	_started = Time.get_ticks_msec()
	_game = PracticePool.game(GameState.practice_game)
	var column := Kit.page(self)
	var head := Kit.header(column, str(_game.get("name", "Practice")), _back, true)
	_count = Kit.label("", 28, Palette.INK, true)
	_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.row.add_child(_count)
	head.row.move_child(_count, 2)
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
	speak.radius = 40
	speak.lift = 5
	speak.custom_minimum_size = Vector2(80, 80)
	speak.pressed.connect(_speak)
	row.add_child(speak)
	_prompt = Kit.label("", 30, Palette.INK, true)
	_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_prompt)
	column.add_child(prompt_card)
	_holder = VBoxContainer.new()
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_holder)
	var talk := HBoxContainer.new()
	talk.add_theme_constant_override("separation", 12)
	_raccoon = Raccoon.new()
	_raccoon.custom_minimum_size = Vector2(120, 120)
	talk.add_child(_raccoon)
	_bubble = SpeechBubble.new()
	_bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_count.text = "%d / %d" % [_i + 1, _items.size()]
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
		_prompt.text = str(p.get("title", "Story"))
		Speech.say(str(p.get("text", "")), str(p.get("language", "en")))
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
	if ok:
		_right += 1
		Sfx.play("correct")
		GameState.learn_words(Collection.words_from_item(item), "game")
		_say(GameState.line("correct"), "happy")
	else:
		Sfx.play("wrong")
		_say("Almost! Here's the answer.", "encourage")
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
	Kit.reward(self, "%d of %d right!" % [_right, _items.size()], result, _back)


func _back() -> void:
	Speech.stop()
	get_tree().change_scene_to_file("res://scenes/practice/practice.tscn")
