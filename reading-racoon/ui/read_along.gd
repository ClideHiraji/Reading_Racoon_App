class_name ReadAlong
extends HFlowContainer
## The words of a book page or song line that light up as Racoon reads them
## (D-017, FR-20). Tap a word to hear it again. With no voice for the language
## the words light up at a steady pace, so the page still works.

signal done
signal word_tapped(word: String)

const ANDIKA := preload("res://assets/fonts/Andika-Bold.ttf")
## Seconds per word when there's no voice.
const STEP := 0.55

var language := "en"
var font_size := 44

var _words := PackedStringArray()
var _labels: Array = []
var _playing := false
var _voiced := false
var _lit := -1
var _timer: Timer
var _speech: Node


func _ready() -> void:
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 8)
	alignment = FlowContainer.ALIGNMENT_CENTER
	_timer = Timer.new()
	_timer.wait_time = STEP
	_timer.timeout.connect(_step)
	add_child(_timer)
	# Looked up in the tree (not the autoload name) so tests can load this class early.
	_speech = get_node("/root/Speech")
	_speech.word_reached.connect(_on_word_reached)
	_speech.finished.connect(_on_speech_finished)


func set_text(text: String) -> void:
	stop()
	for l in _labels:
		l.queue_free()
	_labels.clear()
	_words = text.split(" ", false)
	for i in _words.size():
		var l := Label.new()
		l.text = _words[i]
		l.add_theme_font_override("font", ANDIKA)
		l.add_theme_font_size_override("font_size", font_size)
		l.add_theme_color_override("font_color", Palette.INK)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(_on_word_input.bind(i))
		add_child(l)
		_labels.append(l)
	_light(-1)


func playing() -> bool:
	return _playing


## Reads the text, lighting each word, then emits `done`.
func play() -> void:
	if _words.is_empty():
		done.emit()
		return
	_playing = true
	_light(0)
	_voiced = _speech.say_tracked(" ".join(_words), language)
	if not _voiced:
		_timer.start()


func stop() -> void:
	if _playing and _voiced:
		_speech.stop()
	_playing = false
	if _timer:
		_timer.stop()
	_light(-1)


func _step() -> void:
	if _lit + 1 >= _words.size():
		_finish()
	else:
		_light(_lit + 1)


func _on_word_reached(index: int) -> void:
	if _playing and _voiced:
		_light(index)


func _on_speech_finished() -> void:
	if _playing and _voiced:
		_finish()


func _finish() -> void:
	_playing = false
	_timer.stop()
	_light(-1)
	done.emit()


func _light(index: int) -> void:
	_lit = index
	for i in _labels.size():
		var on := i == index
		var sb := StyleBoxFlat.new()
		sb.bg_color = Palette.YELLOW if on else Color(0, 0, 0, 0)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		_labels[i].add_theme_stylebox_override("normal", sb)


func _on_word_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		stop()
		var word := Collection.clean_word(_words[i])
		_light(i)
		_speech.say(_words[i].trim_suffix(",").trim_suffix("."), language)
		word_tapped.emit(word)
