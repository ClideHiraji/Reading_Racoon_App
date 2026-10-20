extends Node
## Reads prompts aloud with the device's text-to-speech (autoload "Speech").
## Audio-first design for learners who can't read instructions yet (D-007, FR-20).
## Recorded narration replaces this later. Needs audio/general/text_to_speech=true.

var _voice := ""


func _ready() -> void:
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if voices.size() > 0:
		_voice = voices[0]


func available() -> bool:
	return _voice != ""


func say(text: String) -> void:
	if not available() or text.is_empty():
		return
	# Slightly slower and brighter than default for 6-year-olds.
	DisplayServer.tts_speak(text, _voice, 80, 1.1, 0.85, 0, true)


func stop() -> void:
	if available():
		DisplayServer.tts_stop()
