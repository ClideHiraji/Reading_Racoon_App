class_name SpeechBubble
extends PanelContainer
## The raccoon's speech bubble: a paper card with a little tail pointing at the
## speaker (D-009). Lines pop in; keep them short (companion guardrails,
## docs/knowledge/06-game-design.md).

## Where the tail points from: "left" (speaker on the left), "down", or "up".
@export_enum("left", "down", "up") var tail := "left"

var _label: Label


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(Palette.SHADOW, 0.18)
	sb.shadow_offset = Vector2(0, 5)
	sb.shadow_size = 1
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 28)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(220, 0)
	add_child(_label)
	modulate.a = 0.0


func _draw() -> void:
	var pts: PackedVector2Array
	match tail:
		"down":
			pts = PackedVector2Array([Vector2(36, size.y - 2), Vector2(64, size.y - 2), Vector2(30, size.y + 22)])
		"up":
			pts = PackedVector2Array([Vector2(36, 2), Vector2(64, 2), Vector2(34, -20)])
		_:
			pts = PackedVector2Array([Vector2(2, size.y * 0.5 - 14), Vector2(2, size.y * 0.5 + 12),
					Vector2(-20, size.y * 0.5 + 8)])
	draw_colored_polygon(pts, Palette.CARD)


func say(text: String) -> void:
	if text.is_empty():
		hide_bubble()
		return
	_label.text = text
	queue_redraw()
	pivot_offset = Vector2(0, size.y)
	scale = Vector2(0.85, 0.85)
	var t := create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 1.0, 0.12)
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func hide_bubble() -> void:
	create_tween().tween_property(self, "modulate:a", 0.0, 0.12)
