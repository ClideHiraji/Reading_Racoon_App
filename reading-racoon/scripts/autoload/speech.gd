extends Node
## Reads prompts and stories aloud with the device's text-to-speech (autoload
## "Speech"). Audio-first design for learners who can't read instructions yet
## (D-007, FR-20). Picks a voice per item language: English, or Filipino for
## levels 3-4 (MATATAG bridge). Recorded narration replaces this later.
## Needs audio/general/text_to_speech=true.

## Language prefixes to try for each content language.
const LANGS := {"en": ["en"], "fil": ["fil", "tl"]}

var _voices := {}


func _ready() -> void:
	for lang in LANGS:
		for code in LANGS[lang]:
			var v := DisplayServer.tts_get_voices_for_language(code)
			if v.size() > 0:
				_voices[lang] = v[0]
				break


## "en-placeholder" -> "en", "fil-placeholder" -> "fil".
static func base_lang(language: String) -> String:
	return "fil" if language.begins_with("fil") or language.begins_with("tl") else "en"


func available(language: String = "en") -> bool:
	return _voices.has(base_lang(language))


func say(text: String, language: String = "en") -> void:
	var lang := base_lang(language)
	if not _voices.has(lang) or text.is_empty():
		return
	# Slightly slower and brighter than default for 6-year-olds.
	DisplayServer.tts_speak(text, _voices[lang], 80, 1.1, 0.85, 0, true)


func stop() -> void:
	if not _voices.is_empty():
		DisplayServer.tts_stop()
