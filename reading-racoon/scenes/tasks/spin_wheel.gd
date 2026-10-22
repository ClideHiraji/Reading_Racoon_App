class_name SpinWheel
extends Control
## A paper word wheel for "Spin the Words" (teacher Delgado's idea, 01-project-overview):
## first sounds or syllables around the rim; the one at the pointer (right side)
## joins the word ending. Tap a letter to turn it to the pointer.

signal picked(index: int)

const COLORS := [Palette.YELLOW, Palette.BLUE, Palette.ORANGE, Palette.LEAF, Palette.PLUM_LIGHT, Palette.SAND]
const ANDIKA := preload("res://assets/fonts/Andika-Bold.ttf")

var labels: Array = []
var angle := 0.0:
	set(v):
		angle = v
		queue_redraw()
var locked := false
var greyed: Array = []             # segments tried already (second try, D-021)


func _init() -> void:
	custom_minimum_size = Vector2(380, 380)   # D-022: bigger, with a spin arrow in the middle
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p_labels: Array) -> void:
	labels = p_labels
	angle = -TAU * 1.5
	create_tween().tween_property(self, "angle", _angle_for(0) + PI / labels.size(), 1.1) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Wheel angle that puts segment `i` at the pointer (angle 0, the right side).
func _angle_for(i: int) -> float:
	return -TAU * i / labels.size()


func turn_to(i: int) -> void:
	var target := _angle_for(i)
	# Turn the short way round.
	while target - angle > PI:
		target -= TAU
	while angle - target > PI:
		target += TAU
	create_tween().tween_property(self, "angle", target, 0.45).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if locked or labels.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var d: Vector2 = event.position - size / 2
		if d.length() > _radius() or d.length() < _radius() * 0.22:
			return
		var a := fposmod(d.angle() - angle + PI / labels.size(), TAU)
		var i := int(a / (TAU / labels.size())) % labels.size()
		accept_event()
		if not greyed.has(i):
			picked.emit(i)


func grey_out(i: int) -> void:
	greyed.append(i)
	queue_redraw()


func _radius() -> float:
	return minf(size.x, size.y) / 2 - 12


func _draw() -> void:
	if labels.is_empty():
		return
	var c := size / 2
	var r := _radius()
	var n := labels.size()
	draw_circle(c + Vector2(0, 9), r, Palette.SHADOW)
	for i in n:
		var a0 := angle + TAU * i / n - PI / n
		var pts := PackedVector2Array([c])
		for k in 13:
			var a := a0 + TAU / n * k / 12.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		var face: Color = Palette.PAPER_DEEP if greyed.has(i) else COLORS[i % COLORS.size()]
		draw_colored_polygon(pts, face)
		var mid := angle + TAU * i / n
		var p := c + Vector2(cos(mid), sin(mid)) * r * 0.64
		var fs := 58 if str(labels[i]).length() <= 1 else 46
		var tw := ANDIKA.get_string_size(str(labels[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var ink := Color(Palette.INK_SOFT, 0.5) if greyed.has(i) else Palette.text_on(face)
		draw_string(ANDIKA, p + Vector2(-tw.x / 2, fs * 0.33), str(labels[i]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	# Stitched rim and center pin.
	for i in 36:
		var a := TAU * i / 36.0
		draw_arc(c, r - 8, a, a + TAU / 72.0, 3, Color(1, 1, 1, 0.5), 3.0, true)
	draw_circle(c + Vector2(0, 4), r * 0.22, Palette.SHADOW)
	draw_circle(c, r * 0.22, Palette.CARD)
	# A curved arrow says "spin me" (D-022).
	var spin := Icons.tex("repeat")
	if spin:
		var px := r * 0.3
		draw_texture_rect(spin, Rect2(c - Vector2(px, px) / 2, Vector2(px, px)), false, Palette.INK)
