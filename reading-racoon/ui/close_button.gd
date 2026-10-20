class_name CloseButton
extends BaseButton
## A drawn close mark in a soft paper circle (no emoji or font glyph, D-009).


func _init() -> void:
	custom_minimum_size = Vector2(72, 72)


func _ready() -> void:
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	var c := size / 2
	var pressed := get_draw_mode() == DRAW_PRESSED
	draw_circle(c, 30, Color(Palette.PAPER_DEEP, 0.9 if pressed else 0.6))
	var d := 11.0
	for s in [1.0, -1.0]:
		draw_line(c + Vector2(-d, -d * s), c + Vector2(d, d * s), Palette.INK_SOFT, 6.0, true)
		draw_circle(c + Vector2(-d, -d * s), 3, Palette.INK_SOFT)
		draw_circle(c + Vector2(d, d * s), 3, Palette.INK_SOFT)
