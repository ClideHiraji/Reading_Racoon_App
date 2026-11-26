extends Node
## Reads prompts and stories aloud with the device's text-to-speech (autoload
## "Speech"). Audio-first design for learners who can't read instructions yet
## (D-007, FR-20). Picks a voice per item language: English, Filipino for levels
## 3-4 (MATATAG bridge), and Bisaya (Cebuano, else a Filipino voice) for the
## Library's local books. Recorded narration replaces this later.
## Needs audio/general/text_to_speech=true.
##
## Recorded voices (D-035): the buddy's own lines and the menus, read by Gemini's Zeno (Roco) and Cleo (Rina),
## one MP3 per sentence in assets/voice/, named clip_key(buddy, language, sentence). A line plays recorded when
## every sentence of it has a clip; otherwise the system voice reads it, as before (lessons, books and videos,
## and lines not recorded yet).
##
## Windows (the school laptops): cutting a line off mid-sentence freezes the whole game for about
## 210 ms there (the system voice blocks while it stops; NFR-01). So on Windows a line is spoken a
## sentence at a time, and a new line, or stop(), drops the sentences not yet started and lets the
## one being spoken finish. Android and iPhone stop at once without a freeze, so they cut off as
## before.
##
## Leaving a screen stops the voice at once, on every device (the user's choice, 2026-11-17): what
## Racoon was saying belonged to that screen. So does a new question (new_question(); the user's
## choice, 2026-11-18, D-032): a line about the last question never runs on into the next one.
##
## On Windows such a cut stops the system voice on a worker thread (D-032): the call costs the game
## 0.1 ms instead of a 210 ms freeze. The next line starts when the stop is done, about 0.4 s later.
## (Starting any line from quiet still costs Windows' voice one slow frame, about 0.14 s, on the game's
## thread; Godot does that part, and recorded narration will remove it.)

## Read-along (D-017): the word being spoken now, as its index in the text's words.
signal word_reached(index: int)
## The read-along text has been read to the end (or was stopped).
signal finished

## Language prefixes to try for each content language.
const LANGS := {"en": ["en"], "fil": ["fil", "tl"], "bis": ["ceb", "fil", "tl"]}

## The voice's loudness, 0-100 (the tests turn it down).
var volume := 80
## Set by GameState from the student's buddy (D-033): Roco 1.1, Rina 1.4 (1 is the voice's own).
var pitch := 1.1
## Rina: use a female system voice for the language when the device has one.
var girl_voice := false

## Voice names that are female on Windows, Android and iOS (the system doesn't say a voice's sex).
const FEMALE_HINTS := ["zira", "hazel", "susan", "eva", "linda", "heera", "catherine", "aria", "jenny", "female",
	"woman", "samantha", "karen", "moira", "tessa", "fiona", "veena", "blessica", "rosa", "-fis-", "-fie-"]

var _voices := {}
var _voice_lists := {}
var _tracked_id := -1
var _tracked_starts := PackedInt32Array()
var _next_id := 100
# Windows: sentences waiting their turn, and the one being spoken.
var _gentle := false
var _queue: Array = []          # [{text, voice, id, offset, tracked}]
var _current := {}
var _current_since := 0
var _split := RegEx.new()
var _spoken_in: Node = null   # the screen the voice is speaking for
var _stopper: Thread = null   # Windows: the system voice being stopped, off the game's thread
## Whose recorded voice plays: set with the pitch by GameState.use_buddy_voice() (D-035).
var buddy := "roco"
const VOICE_DIR := "res://assets/voice/"
const CLIP_GAP := 0.15        # seconds between two recorded sentences of a line
var _clip_player: AudioStreamPlayer
var _clips: Array = []        # the recorded sentences still to play, in order
var _clip_run := 0            # bumps on every new line or cut, so a late timer can't play an old one
var _word := RegEx.new()


func _ready() -> void:
	for lang in LANGS:
		for code in LANGS[lang]:
			var v := DisplayServer.tts_get_voices_for_language(code)
			if v.size() > 0:
				_voices[lang] = v[0]
				_voice_lists[lang] = v
				break
	if not _voices.is_empty():
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_BOUNDARY, _on_boundary)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_ended)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_ended)
	_gentle = OS.get_name() == "Windows" and not _voices.is_empty()
	_split.compile("[^.!?]+[.!?]*\\s*")
	_word.compile("\\w")
	_clip_player = AudioStreamPlayer.new()
	_clip_player.name = "RecordedVoice"
	add_child(_clip_player)
	_clip_player.finished.connect(_clip_done)
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


func available(language: String = "en") -> bool:
	return _voices.has(base_lang(language))


## The buddy's talk language (D-033): what an unnamed language means.
func _talk_lang() -> String:
	var gs := get_node_or_null("/root/GameState")
	return gs.talk_language() if gs else "en"


## The voice for a language: for Rina a female one where the device has one, for Roco one that isn't.
func _voice_for(lang: String) -> String:
	var list: Array = _voice_lists.get(lang, [])
	for v in list:
		var female := false
		for hint in FEMALE_HINTS:
			if str(v).to_lower().contains(hint):
				female = true
		if female == girl_voice:
			return str(v)
	return str(_voices.get(lang, ""))


## Says `text`. No language: the buddy's talk language (his or her lines and the menus, D-033);
## lesson content always names its own.
func say(text: String, language: String = "") -> void:
	var lang := base_lang(language if language != "" else _talk_lang())
	if text.is_empty():
		return
	var clips := recorded(text, lang)
	if not clips.is_empty():
		_left_screen()
		_spoken_in = get_tree().current_scene
		if _voices.size() > 0 and speaking():
			cut()   # the system voice was still talking
		_play_clips(clips)
		return
	if not _voices.has(lang):
		return
	_stop_clips()
	_left_screen()
	_spoken_in = get_tree().current_scene
	if _gentle:
		_replace_queue(text, _voice_for(lang), false, true)
		return
	# Slightly slower than default for 6-year-olds, and brighter: the buddy's pitch.
	DisplayServer.tts_speak(text, _voice_for(lang), volume, pitch, 0.85, 0, true)


## Reads `text` and reports each word as it is spoken (word_reached), then
## `finished`. False when there's no voice for the language: the caller then
## paces the words itself.
func say_tracked(text: String, language: String = "en") -> bool:
	var lang := base_lang(language)
	if not _voices.has(lang) or text.is_empty():
		return false
	_left_screen()
	_spoken_in = get_tree().current_scene
	_stop_clips()
	_next_id += 1
	_tracked_id = _next_id
	_tracked_starts = word_starts(text)
	if _gentle:
		_replace_queue(text, _voice_for(lang), true, false)
		return true
	DisplayServer.tts_speak(text, _voice_for(lang), volume, pitch, 0.85, _tracked_id, true)
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
	if _clip_player and (_clip_player.playing or not _clips.is_empty()):
		return true
	if _voices.is_empty():
		return false
	if _gentle and (not _current.is_empty() or not _queue.is_empty()):
		return true
	if _stopper != null:
		return false   # the old line is being stopped; nothing new is waiting
	return DisplayServer.tts_is_speaking()


func stop() -> void:
	_stop_clips()
	if _voices.is_empty():
		return
	if _gentle:
		_drop_waiting(true)
		return
	DisplayServer.tts_stop()


## A new question is about to show (in a lesson, Practice, a book's or a video's questions): whatever
## Racoon is still saying stops at once, on every device (D-032).
func new_question() -> void:
	if speaking():
		cut()


## Stops everything at once, on every device: the line being spoken and any waiting. A read-along
## cut off this way reports `finished`.
func cut() -> void:
	_stop_clips()
	if _voices.is_empty():
		return
	var was_tracked: bool = _tracked_id != -1 or (not _current.is_empty() and bool(_current.tracked))
	for q in _queue:
		was_tracked = was_tracked or q.tracked
	var had_line := not _current.is_empty()
	_queue.clear()
	_current = {}
	_tracked_id = -1
	if had_line or DisplayServer.tts_is_speaking():
		_stop_voice()
	if was_tracked:
		finished.emit.call_deferred()


## Stops the system voice. On Windows that call blocks for about 0.2 s, so it runs on a worker thread
## and the queue waits for it (_pump); elsewhere it's quick.
func _stop_voice() -> void:
	if not _gentle:
		DisplayServer.tts_stop()
		return
	if _stopper != null:
		return   # already stopping, and nothing has been spoken since
	_stopper = Thread.new()
	_stopper.start(func() -> void: DisplayServer.tts_stop())


## The stop on the worker thread is done: the next line can start.
func _stopped() -> void:
	_stopper.wait_to_finish()
	_stopper = null
	_pump()


## Closing the game while the voice is being stopped: the stop needs the window's messages handled to
## finish, so keep handling them until it's done (at most 2 s). Just waiting for the thread would hang.
func _exit_tree() -> void:
	if _stopper == null:
		return
	var until := Time.get_ticks_msec() + 2000
	while _stopper.is_alive() and Time.get_ticks_msec() < until:
		DisplayServer.process_events()
		OS.delay_msec(5)
	if not _stopper.is_alive():
		_stopper.wait_to_finish()
	_stopper = null


## The child left the screen the voice was speaking for: stop at once.
func _left_screen() -> void:
	if _spoken_in == null:
		return
	if is_instance_valid(_spoken_in) and _spoken_in == get_tree().current_scene:
		return
	_spoken_in = null
	if speaking():
		cut()


func _on_boundary(pos: int, id: int) -> void:
	var offset := 0
	if _gentle:
		if _current.is_empty() or id != _current.id or not _current.tracked:
			return
		offset = _current.offset
	elif id != _tracked_id:
		return
	var idx := 0
	for i in _tracked_starts.size():
		if _tracked_starts[i] <= pos + offset:
			idx = i
	word_reached.emit.call_deferred(idx)


func _on_ended(id: int) -> void:
	if _gentle:
		if not _current.is_empty() and id == _current.id:
			_sentence_done()
		return
	if id == _tracked_id:
		_tracked_id = -1
		finished.emit.call_deferred()


# --- Recorded voices (D-035) ------------------------------------------------------------------------

## A recorded sentence's file name: the same key the voice lab's manifest.py gives it.
static func clip_key(who: String, lang: String, sentence: String) -> String:
	return ("%s|%s|%s" % [who, lang, sentence]).sha1_text().left(16)


## The recorded clips for every sentence of `text` in the buddy's voice, or [] if any sentence has none
## (then the system voice reads the whole line, so one line never mixes two voices).
func recorded(text: String, lang: String) -> Array:
	var out := []
	for m in _split.search_all(text):
		var s := m.get_string().strip_edges()
		if s.is_empty() or _word.search(s) == null:
			continue
		var path := VOICE_DIR + clip_key(buddy, lang, s) + ".mp3"
		if not ResourceLoader.exists(path):
			return []
		out.append(path)
	return out


func _play_clips(paths: Array) -> void:
	_stop_clips()
	for p in paths:
		_clips.append(load(p))
	_next_clip()


func _next_clip() -> void:
	if _clips.is_empty():
		return
	_clip_player.stream = _clips.pop_front()
	_clip_player.volume_db = linear_to_db(maxf(volume, 1) / 100.0)
	_clip_player.play()


## A sentence ended: a short breath, then the next one (unless the line was cut meanwhile).
func _clip_done() -> void:
	if _clips.is_empty():
		return
	var run := _clip_run
	get_tree().create_timer(CLIP_GAP).timeout.connect(func() -> void:
		if run == _clip_run:
			_next_clip())


func _stop_clips() -> void:
	_clip_run += 1
	_clips.clear()
	if _clip_player and _clip_player.playing:
		_clip_player.stop()


# --- Windows: a sentence at a time ---------------------------------------------------------------

## A new line: the sentences of the old one that haven't started are dropped, the one being spoken
## finishes, then the new line's sentences follow.
func _replace_queue(text: String, voice: String, tracked: bool, cut_reports_finished: bool) -> void:
	_drop_waiting(cut_reports_finished)
	for m in _split.search_all(text):
		var s := m.get_string()
		if s.strip_edges().is_empty():
			continue
		_next_id += 1
		_queue.append({"text": s, "voice": voice, "id": _next_id, "offset": m.get_start(), "tracked": tracked})
	_pump()


## Drops the sentences not yet spoken. A read-along line cut off this way reports `finished` (as a
## stopped one always did), unless a new read-along line is taking its place.
func _drop_waiting(report_finished: bool) -> void:
	var had_tracked := false
	for q in _queue:
		had_tracked = had_tracked or q.tracked
	_queue.clear()
	if report_finished and (had_tracked or (not _current.is_empty() and _current.tracked)):
		_tracked_id = -1
		finished.emit.call_deferred()
	if not _current.is_empty():
		_current.tracked = false   # it finishes, but no longer lights words


## Hands the next sentence to the system voice, if it's free (never interrupting, so it never blocks).
func _pump() -> void:
	if not _current.is_empty() or _queue.is_empty() or _stopper != null:
		return
	_current = _queue.pop_front()
	_current_since = Time.get_ticks_msec()
	DisplayServer.tts_speak(_current.text, _current.voice, volume, pitch, 0.85, _current.id, false)


func _sentence_done() -> void:
	var was_tracked: bool = _current.get("tracked", false)
	_current = {}
	if was_tracked and _queue.filter(func(q): return q.tracked).is_empty():
		_tracked_id = -1
		finished.emit.call_deferred()
	_pump.call_deferred()


## If the voice never reports a sentence as ended, move on once it has gone quiet.
func _process(_delta: float) -> void:
	if _stopper != null and not _stopper.is_alive():
		_stopped()
	if _spoken_in != null and (not is_instance_valid(_spoken_in) or _spoken_in != get_tree().current_scene):
		_left_screen()
	if not _gentle or _current.is_empty():
		return
	if Time.get_ticks_msec() - _current_since > 400 and not DisplayServer.tts_is_speaking():
		_sentence_done()
