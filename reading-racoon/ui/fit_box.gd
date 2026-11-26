class_name FitBox
extends Container
## Holds a lesson task at full size, or shrunk just enough to fit when the task needs more
## room than the box has (like on a shorter laptop screen). It never scales up and asks for no
## room itself, so a big task can't push the rest of the screen off the edge.
##
## A task with wrapped words gets shorter when it's wider, so shrinking it can make it fit at
## a bigger size, which makes it tall again: the two sizes swapped forever in one frame and
## crashed the game on laptops. So once a task grows back and has to shrink again, that size
## becomes its limit while the box keeps its size.

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
