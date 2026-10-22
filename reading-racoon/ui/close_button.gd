class_name CloseButton
extends BaseButton
## A drawn close mark in a soft paper circle (no emoji or font glyph, D-009).
## The tap area is 96 px (NFR-02, D-022); the circle drawn inside is smaller.


func _init() -> void:
	custom_minimum_size = Vector2(96, 96)


func _ready() -> void:
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	var c := size / 2
	var is_down := get_draw_mode() == DRAW_PRESSED
	draw_circle(c, 36, Color(Palette.PAPER_DEEP, 0.95 if is_down else 0.7))
	var d := 13.0
	for s in [1.0, -1.0]:
		draw_line(c + Vector2(-d, -d * s), c + Vector2(d, d * s), Palette.INK_SOFT, 7.0, true)
		draw_circle(c + Vector2(-d, -d * s), 3.5, Palette.INK_SOFT)
		draw_circle(c + Vector2(d, d * s), 3.5, Palette.INK_SOFT)
