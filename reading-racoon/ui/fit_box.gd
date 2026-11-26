class_name FitBox
extends Container
## Holds a lesson task at full size, or scaled down just enough to fit when the
## task needs more room than the box has, as on the shorter laptop screen
## (D-023). It never scales up, and it asks for no room itself, so a big task
## can't push the rest of the screen off the edge.
##
## A task with wrapped words is shorter when it is wider, so a smaller scale can let a bigger one
## fit, which makes it narrow and tall again: the two scales took turns forever in one frame and
## crashed the game on laptops (NFR-01). So when a child grows back and then has to shrink again,
## that size becomes its ceiling while the box keeps its size.

const EPS := 0.001   # scales are stored as float32: compare with room to spare


func _get_minimum_size() -> Vector2:
	return Vector2.ZERO


## The scale for a child that needs `need` in a box of size `box`, given its `current` scale and
## its fitting history (`state`, updated here): at most 1, small enough to fit, and not up to a
## size it already grew to once without it holding.
static func next_scale(current: float, need: Vector2, box: Vector2, state: Dictionary) -> float:
	if need.x <= 0.0 or need.y <= 0.0 or box.x <= 0.0 or box.y <= 0.0:
		return current
	var want := minf(1.0, minf(box.x / need.x, box.y / need.y))
	var grew: bool = state.get("grew", false)
	state.grew = false
	if want > current + EPS:
		if want >= float(state.get("ceiling", INF)) - EPS:
			return current   # tried before: it made the task tall again
		state.grew = true
		return want
	if want < current - EPS:
		if grew:
			state.ceiling = current
		return want
	return current


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		for c in get_children():
			c.remove_meta(&"fit_state")   # a new box size: fit again from full size
		return
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	for c in get_children():
		if not (c is Control) or not c.visible or c.top_level:
			continue
		if not c.has_meta(&"fit_state"):
			c.set_meta(&"fit_state", {})
		var s := next_scale(c.scale.x, c.get_combined_minimum_size(), size, c.get_meta(&"fit_state"))
		c.scale = Vector2(s, s)
		c.position = Vector2.ZERO
		c.size = size / s
