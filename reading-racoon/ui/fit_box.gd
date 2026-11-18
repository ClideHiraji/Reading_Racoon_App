class_name FitBox
extends Container
## Holds a lesson task at full size, or scaled down just enough to fit when the
## task needs more room than the box has, as on the shorter laptop screen
## (D-023). It never scales up, and it asks for no room itself, so a big task
## can't push the rest of the screen off the edge.


func _get_minimum_size() -> Vector2:
	return Vector2.ZERO


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	for c in get_children():
		if not (c is Control) or not c.visible or c.top_level:
			continue
		var need: Vector2 = c.get_combined_minimum_size()
		var s := 1.0
		if need.x > 0.0 and need.y > 0.0 and size.x > 0.0 and size.y > 0.0:
			s = minf(1.0, minf(size.x / need.x, size.y / need.y))
		c.scale = Vector2(s, s)
		c.position = Vector2.ZERO
		c.size = size / s
