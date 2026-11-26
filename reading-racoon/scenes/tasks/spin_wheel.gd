class_name SpinWheel
extends Control
## A paper word wheel for "Spin the Words": first sounds or syllables round the rim, and the
## one at the pointer (right side) joins the word ending.
## It turns like a real wheel: drag it round, or fling it and it spins on, slows down and
## clicks onto a letter. The letters turn with the wheel and stand upright at the pointer.
## Tapping a letter still turns it to the pointer.

## A letter came to rest at the pointer, or was tapped: the child's answer.
signal picked(index: int)
## The letter at the pointer while the wheel turns (-1: none), for a live preview of the word.
signal turning(index: int)

const COLORS := [Palette.YELLOW, Palette.BLUE, Palette.ORANGE, Palette.LEAF, Palette.PLUM_LIGHT, Palette.SAND]
const ANDIKA := preload("res://assets/fonts/Andika-Bold.ttf")
const DRAG_START := 12.0      # px the finger moves before a press becomes a turn
const MAX_SPIN := 18.0        # rad/s, about three turns a second
const FLING := 1.5            # rad/s: a slower let-go just settles where it is
const FRICTION := 4.5         # rad/s² of steady slowing, plus a little drag that grows with speed
const DRAG := 0.6

var labels: Array = []
var angle := 0.0:
	set(v):
		angle = v
		_at_pointer_changed()
		queue_redraw()
var locked := false
var greyed: Array = []             # segments already tried (second try)

var _tween: Tween
var _pressed := false
var _turning := false
var _press_at := Vector2.ZERO
var _last_a := 0.0
var _samples: Array = []           # [msec, angle step] of the last moves, for the fling speed
var _spin := 0.0                   # rad/s while spinning on its own
var _shown := -2


func _init() -> void:
	custom_minimum_size = Vector2(380, 380)   # big, with a spin arrow in the middle
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND   # a slice can be tapped
	set_process(false)


func setup(p_labels: Array) -> void:
	labels = p_labels
	angle = -TAU * 1.5
	_tween = create_tween()
	_tween.tween_property(self, "angle", _angle_for(0) + PI / labels.size(), 1.1) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Wheel angle that puts segment `i` at the pointer (angle 0, the right side).
func _angle_for(i: int) -> float:
	return -TAU * i / labels.size()


## The segment whose middle is nearest the pointer.
func at_pointer() -> int:
	return posmod(roundi(-angle * labels.size() / TAU), labels.size()) if not labels.is_empty() else -1


func turn_to(i: int) -> void:
	var target := _angle_for(i)
	# Turn the short way round.
	while target - angle > PI:
		target -= TAU
	while angle - target > PI:
		target += TAU
	_stop_tween()
	_tween = create_tween()
	_tween.tween_property(self, "angle", target, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if locked or labels.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			var d: Vector2 = event.position - size / 2
			if d.length() > _radius() or d.length() < _radius() * 0.22:
				return
			_pressed = true
			_turning = false
			_press_at = event.position
			_last_a = d.angle()
			_samples.clear()
			if _spin != 0.0:   # caught while spinning: it stops in the hand
				_spin = 0.0
				set_process(false)
				_turning = true
			return
		if not _pressed:
			return
		_pressed = false
		if _turning:
			_let_go()
		else:
			_tap(event.position)
	elif event is InputEventMouseMotion and _pressed:
		accept_event()
		if not _turning and event.position.distance_to(_press_at) < DRAG_START:
			return
		if not _turning:
			_turning = true
			_stop_tween()
		var a: float = (event.position - size / 2).angle()
		var step := wrapf(a - _last_a, -PI, PI)
		_last_a = a
		angle += step
		var now := Time.get_ticks_msec()
		_samples.append([now, step])
		while _samples.size() > 1 and now - int(_samples[0][0]) > 100:
			_samples.pop_front()


## The old way: a tapped letter turns to the pointer (the task answers with it).
func _tap(at: Vector2) -> void:
	var d: Vector2 = at - size / 2
	var a := fposmod(d.angle() - angle + PI / labels.size(), TAU)
	var i := int(a / (TAU / labels.size())) % labels.size()
	if not greyed.has(i):
		picked.emit(i)


## Let go after turning: spin on at the finger's speed, or settle where it is.
func _let_go() -> void:
	_turning = false
	var speed := 0.0
	if not _samples.is_empty() and Time.get_ticks_msec() - int(_samples[-1][0]) < 80:
		var turned := 0.0
		for s in _samples:
			turned += float(s[1])
		var ms := maxf(float(int(_samples[-1][0]) - int(_samples[0][0])), 16.0)
		speed = clampf(turned / (ms / 1000.0), -MAX_SPIN, MAX_SPIN)
	if absf(speed) < FLING:
		_settle()
		return
	_spin = speed
	set_process(true)


func _process(delta: float) -> void:
	if _spin == 0.0:   # Godot turns _process on at ready; only a fling needs it
		set_process(false)
		return
	angle += _spin * delta
	var slow := (FRICTION + DRAG * absf(_spin)) * delta
	if absf(_spin) <= slow + 1.0:
		_spin = 0.0
		set_process(false)
		_settle()
		return
	_spin -= signf(_spin) * slow


## Clicks into the nearest letter, like a wheel's pointer catching a peg, then answers with it.
func _settle() -> void:
	var i := at_pointer()
	var target := _angle_for(i)
	while target - angle > PI:
		target -= TAU
	while angle - target > PI:
		target += TAU
	_stop_tween()
	_tween = create_tween()
	_tween.tween_property(self, "angle", target, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func():
		if greyed.has(i):
			turning.emit(-1)   # a letter tried already: spin again
		elif not locked:
			picked.emit(i))


func _stop_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


## A letter passing the pointer ticks, as the peg of a real wheel does, and shows in the word.
func _at_pointer_changed() -> void:
	if labels.is_empty() or not is_inside_tree():
		return
	var i := at_pointer()
	if i == _shown:
		return
	var first := _shown == -2
	_shown = i
	if first:
		return
	if _turning or _spin != 0.0:
		var sfx := get_node_or_null("/root/Sfx")   # looked up, not named: tests load this class early
		if sfx:
			sfx.play("tap")
		turning.emit(i)


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
	Smooth.circle(self, c + Vector2(0, 9), r, Palette.SHADOW)
	for i in n:
		var a0 := angle + TAU * i / n - PI / n
		var pts := PackedVector2Array([c])
		for k in 13:
			var a := a0 + TAU / n * k / 12.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		var face: Color = Palette.PAPER_DEEP if greyed.has(i) else COLORS[i % COLORS.size()]
		draw_colored_polygon(pts, face)
		# Smooth only the outer rim: the wedges' shared edges stay crisp, so no
		# blended seam shows between two colours.
		if Smooth.enabled:
			draw_arc(c, r, a0, a0 + TAU / n, 13, face, Smooth.EDGE, true)
		# The letter turns with its wedge: upright when it reaches the pointer on the right.
		var mid := angle + TAU * i / n
		var fs := 58 if str(labels[i]).length() <= 1 else 46
		var tw := ANDIKA.get_string_size(str(labels[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var ink := Color(Palette.INK_SOFT, 0.5) if greyed.has(i) else Palette.text_on(face)
		draw_set_transform(c + Vector2(cos(mid), sin(mid)) * r * 0.64, mid)
		draw_string(ANDIKA, Vector2(-tw.x / 2, fs * 0.33), str(labels[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		draw_set_transform(Vector2.ZERO)
	# Stitched rim (it turns too) and the center pin (it doesn't).
	for i in 36:
		var a := angle + TAU * i / 36.0
		draw_arc(c, r - 8, a, a + TAU / 72.0, 3, Color(1, 1, 1, 0.5), 3.0, true)
	Smooth.circle(self, c + Vector2(0, 4), r * 0.22, Palette.SHADOW)
	Smooth.circle(self, c, r * 0.22, Palette.CARD)
	# A curved arrow says "spin me".
	var spin := Icons.tex("repeat")
	if spin:
		var px := r * 0.3
		draw_texture_rect(spin, Rect2(c - Vector2(px, px) / 2, Vector2(px, px)), false, Palette.INK)
