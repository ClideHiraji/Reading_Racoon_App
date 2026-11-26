extends Node
## Reads prompts, stories and Racoon's lines aloud (autoload "Speech"): audio-first design for learners who
## can't read instructions yet (D-007, FR-20).
##
## Recorded voices only (D-035, D-041): the student's buddy, Roco (Gemini's Zeno) or Rina (Cleo), in the
## line's language. One MP3 per sentence in assets/voice/, named clip_key(buddy, language, sentence). A line
## plays when every sentence of it is recorded in that voice and language. Otherwise it stays silent (its
## words still show), so no other voice ever speaks: no other buddy, no other language and no device
## text-to-speech (the user's choice, 2026-11-26: the device voice was often a woman's for Roco, and it
## talked over the recordings).
##
## A new line replaces the one playing. Leaving a screen stops the voice at once (the user's choice,
## 2026-11-17), and so does a new question (new_question(); D-032).

## Read-along (D-017): the word being spoken now, as its index in the text's words.
signal word_reached(index: int)
## The read-along text has been read to the end (or was stopped).
signal finished

const VOICE_DIR := "res://assets/voice/"
const CLIP_GAP := 0.15        # seconds between two recorded sentences of a line

## The voice's loudness, 0-100 (Settings; the tests turn it down).
var volume := 80
## Whose recorded voice plays: set by GameState.use_buddy_voice() (D-033, D-035).
var buddy := "roco"

var _player: AudioStreamPlayer
var _clips: Array = []        # the sentences still to play: [{stream, from, to}]
var _now := {}                # the sentence playing
var _run := 0                 # bumps on every new line or cut, so a late timer can't play an old one
var _tracked := false         # the line is a read-along (say_tracked)
var _starts := PackedInt32Array()
var _lit := -1
var _split := RegEx.new()
var _word := RegEx.new()
var _spoken_in: Node = null   # the screen the voice is speaking for


func _ready() -> void:
	_split.compile("[^.!?]+[.!?]*\\s*")
	_word.compile("\\w")
	_player = AudioStreamPlayer.new()
	_player.name = "RecordedVoice"
	add_child(_player)
	_player.finished.connect(_clip_done)
	# GameState loads first: take its student's buddy voice now (D-033)
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("use_buddy_voice"):
		gs.use_buddy_voice()


## "en-placeholder" -> "en", "fil-placeholder" -> "fil", "bis-placeholder" -> "bis".
static func base_lang(language: String) -> String:
	if language.begins_with("fil") or language.begins_with("tl"):
		return "fil"
	if language.begins_with("bis") or language.begins_with("ceb"):
		return "bis"
	return "en"


## The buddy's talk language (D-033): what an unnamed language means.
func _talk_lang() -> String:
	var gs := get_node_or_null("/root/GameState")
	return gs.talk_language() if gs else "en"


## True when `text` would be heard: every sentence of it is recorded in the buddy's voice.
func has_line(text: String, language: String = "") -> bool:
	return not recorded(text, base_lang(language if language != "" else _talk_lang())).is_empty()


## Says `text`. No language: the buddy's talk language (his or her lines and the menus, D-033);
## lesson content always names its own.
func say(text: String, language: String = "") -> void:
	if text.is_empty():
		return
	_begin(true)
	_play(_clips_for(text, base_lang(language if language != "" else _talk_lang())))


## Reads `text` and reports each word as it is spoken (word_reached), then `finished`. False when the
## text isn't recorded: the caller then paces the words itself, silently.
func say_tracked(text: String, language: String = "en") -> bool:
	if text.is_empty():
		return false
	var clips := _clips_for(text, base_lang(language))
	_begin(false)
	if clips.is_empty():
		return false
	_tracked = true
	_starts = word_starts(text)
	_lit = -1
	_play(clips)
	return true


## Where each word starts in `text` (words are split by spaces).
static func word_starts(text: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	var in_word := false
	for i in text.length():
		var space := text[i] == " " or text[i] == "\n"
		if not space and not in_word:
			out.append(i)
		in_word = not space
	return out


## Racoon is still talking (the lesson waits before moving on, D-021).
func speaking() -> bool:
	return _player != null and (_player.playing or not _clips.is_empty())


func stop() -> void:
	_stop_line(true)


## A new question is about to show (in a lesson, Practice, a book's or a video's questions): whatever
## Racoon is still saying stops at once (D-032).
func new_question() -> void:
	if speaking():
		cut()


## Stops the line at once. A read-along cut off this way reports `finished`.
func cut() -> void:
	_stop_line(true)


# --- Recorded voices (D-035) ------------------------------------------------------------------------

## A recorded sentence's file name: the same key the voice lab's manifest.py gives it.
static func clip_key(who: String, lang: String, sentence: String) -> String:
	return ("%s|%s|%s" % [who, lang, sentence]).sha1_text().left(16)


## The recorded clips for every sentence of `text` in the buddy's voice, or [] if any sentence has none
## (then the whole line stays silent, so one line never mixes a voice with silence).
func recorded(text: String, lang: String) -> Array:
	return _clips_for(text, lang).map(func(c): return c.path)


func _clips_for(text: String, lang: String) -> Array:
	var out := []
	for m in _split.search_all(text):
		var s := m.get_string().strip_edges()
		if s.is_empty() or _word.search(s) == null:
			continue
		var path := VOICE_DIR + clip_key(buddy, lang, s) + ".mp3"
		if not ResourceLoader.exists(path):
			return []
		out.append({"path": path, "from": m.get_start(), "to": m.get_start() + s.length()})
	return out


## A new line starts: the screen it belongs to, and the old line stopped.
func _begin(report_finished: bool) -> void:
	_left_screen()
	_stop_line(report_finished)
	_spoken_in = get_tree().current_scene


func _play(clips: Array) -> void:
	for c in clips:
		_clips.append({"stream": load(c.path), "from": c.from, "to": c.to})
	_next_clip()


func _next_clip() -> void:
	if _clips.is_empty():
		return
	_now = _clips.pop_front()
	_player.stream = _now.stream
	_player.volume_db = -80.0 if volume <= 0 else linear_to_db(volume / 100.0)
	_player.play()


## A sentence ended: a short breath, then the next one (unless the line was cut meanwhile).
func _clip_done() -> void:
	if _clips.is_empty():
		_now = {}
		if _tracked:
			_tracked = false
			finished.emit()
		return
	var run := _run
	get_tree().create_timer(CLIP_GAP).timeout.connect(func() -> void:
		if run == _run:
			_next_clip())


func _stop_line(report_finished: bool) -> void:
	_run += 1
	_clips.clear()
	_now = {}
	if _player and _player.playing:
		_player.stop()
	if _tracked:
		_tracked = false
		if report_finished:
			finished.emit.call_deferred()


## The child left the screen the voice was speaking for: stop at once.
func _left_screen() -> void:
	if _spoken_in == null:
		return
	if is_instance_valid(_spoken_in) and _spoken_in == get_tree().current_scene:
		return
	_spoken_in = null
	if speaking():
		cut()


## Read-along: lights the word under the voice, spreading each sentence's words over its clip by their
## place in the sentence (the recordings carry no word timings).
func _process(_delta: float) -> void:
	if _spoken_in != null and (not is_instance_valid(_spoken_in) or _spoken_in != get_tree().current_scene):
		_left_screen()
	if not _tracked or _now.is_empty() or not _player.playing:
		return
	var f := clampf(_player.get_playback_position() / maxf(_now.stream.get_length(), 0.01), 0.0, 1.0)
	var pos := int(_now.from + (_now.to - _now.from) * f)
	var idx := 0
	for i in _starts.size():
		if _starts[i] <= pos:
			idx = i
	if idx != _lit:
		_lit = idx
		word_reached.emit(idx)
