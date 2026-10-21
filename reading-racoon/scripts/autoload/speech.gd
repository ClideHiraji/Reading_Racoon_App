extends Node
## Reads prompts and stories aloud with the device's text-to-speech (autoload
## "Speech"). Audio-first design for learners who can't read instructions yet
## (D-007, FR-20). Picks a voice per item language: English, Filipino for levels
## 3-4 (MATATAG bridge), and Bisaya (Cebuano, else a Filipino voice) for the
## Library's local books. Recorded narration replaces this later.
## Needs audio/general/text_to_speech=true.

## Read-along (D-017): the word being spoken now, as its index in the text's words.
signal word_reached(index: int)
## The read-along text has been read to the end (or was stopped).
signal finished

## Language prefixes to try for each content language.
const LANGS := {"en": ["en"], "fil": ["fil", "tl"], "bis": ["ceb", "fil", "tl"]}

var _voices := {}
var _tracked_id := -1
var _tracked_starts := PackedInt32Array()
var _next_id := 100


func _ready() -> void:
	for lang in LANGS:
		for code in LANGS[lang]:
			var v := DisplayServer.tts_get_voices_for_language(code)
			if v.size() > 0:
				_voices[lang] = v[0]
				break
	if not _voices.is_empty():
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_BOUNDARY, _on_boundary)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_ended)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_ended)


## "en-placeholder" -> "en", "fil-placeholder" -> "fil", "bis-placeholder" -> "bis".
static func base_lang(language: String) -> String:
	if language.begins_with("fil") or language.begins_with("tl"):
		return "fil"
	if language.begins_with("bis") or language.begins_with("ceb"):
		return "bis"
	return "en"


func available(language: String = "en") -> bool:
	return _voices.has(base_lang(language))


func say(text: String, language: String = "en") -> void:
	var lang := base_lang(language)
	if not _voices.has(lang) or text.is_empty():
		return
	# Slightly slower and brighter than default for 6-year-olds.
	DisplayServer.tts_speak(text, _voices[lang], 80, 1.1, 0.85, 0, true)


## Reads `text` and reports each word as it is spoken (word_reached), then
## `finished`. False when there's no voice for the language: the caller then
## paces the words itself.
func say_tracked(text: String, language: String = "en") -> bool:
	var lang := base_lang(language)
	if not _voices.has(lang) or text.is_empty():
		return false
	_next_id += 1
	_tracked_id = _next_id
	_tracked_starts = word_starts(text)
	DisplayServer.tts_speak(text, _voices[lang], 80, 1.1, 0.85, _tracked_id, true)
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


func stop() -> void:
	if not _voices.is_empty():
		DisplayServer.tts_stop()


func _on_boundary(pos: int, id: int) -> void:
	if id != _tracked_id:
		return
	var idx := 0
	for i in _tracked_starts.size():
		if _tracked_starts[i] <= pos:
			idx = i
	word_reached.emit.call_deferred(idx)


func _on_ended(id: int) -> void:
	if id == _tracked_id:
		_tracked_id = -1
		finished.emit.call_deferred()
