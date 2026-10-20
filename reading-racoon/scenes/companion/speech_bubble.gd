class_name SpeechBubble
extends PanelContainer
## The raccoon's speech bubble. Lines pop in; keep them short (companion guardrails,
## docs/knowledge/06-game-design.md).

var _label: Label


func _ready() -> void:
	theme_type_variation = &"BubblePanel"
	_label = Label.new()
	_label.theme_type_variation = &"BubbleLabel"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(220, 0)
	add_child(_label)
	modulate.a = 0.0


func say(text: String) -> void:
	if text.is_empty():
		hide_bubble()
		return
	_label.text = text
	pivot_offset = Vector2(0, size.y)
	scale = Vector2(0.85, 0.85)
	var t := create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 1.0, 0.12)
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func hide_bubble() -> void:
	create_tween().tween_property(self, "modulate:a", 0.0, 0.12)
