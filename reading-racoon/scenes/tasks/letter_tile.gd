@tool
class_name LetterTile
extends ChunkyButton
## A tile you drag into a DropSlot, or tap: letters in Drag the Letter, and syllables,
## words or story events in the put-in-order tasks.
## While you drag it, the tile itself follows the finger at its own size; its tray spot stays empty.
## Let go near a slot and it drops there; anywhere else it flies back to its spot.

## How far outside a slot a drop still lands in it, in the slot's own units.
const REACH := 70.0

var letter := ""
var _dragging := false
var _grab := Vector2.ZERO
var _at := Vector2.ZERO   # where the finger is, from the drag preview Godot moves


func _get_drag_data(at: Vector2) -> Variant:
	if disabled:
		return null
	_dragging = true
	_grab = at
	var s := get_global_transform().get_scale()   # the lesson may shrink the task to fit (FitBox)
	var preview := _copy()
	preview.scale = s
	var holder := Control.new()
	holder.add_child(preview)
	preview.position = -at * s   # held where the finger grabbed it
	_at = get_global_transform() * at
	# Follow the finger, not the system cursor: on a laptop they can differ (tests, pen, touch).
	holder.item_rect_changed.connect(_follow.bind(holder))
	set_drag_preview(holder)
	modulate.a = 0.0   # the tile is in the finger now, not in the tray
	return {"letter": letter}


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not _dragging:
		return
	_dragging = false
	if get_viewport().gui_is_drag_successful():
		return   # dropped on a slot: the task shows it there
	var slot := _slot_near(_at)
	if slot:
		slot.dropped.emit(letter)
		return
	_fly_back()


func _follow(holder: Control) -> void:
	_at = holder.global_position


## The slot the finger let go over or near (within REACH), the nearest one, or null.
func _slot_near(at: Vector2) -> DropSlot:
	var best: DropSlot = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(DropSlot.GROUP):
		var slot := n as DropSlot
		if not slot.is_visible_in_tree() or not slot.accepting:
			continue
		var local: Vector2 = slot.get_global_transform().affine_inverse() * at
		var r := Rect2(Vector2.ZERO, slot.size)
		var d := Vector2(maxf(maxf(r.position.x - local.x, local.x - r.end.x), 0.0),
				maxf(maxf(r.position.y - local.y, local.y - r.end.y), 0.0)).length()
		if d <= REACH and d < best_d:
			best = slot
			best_d = d
	return best


## Too far from any slot: a copy flies from the finger back to the tile's spot, then the tile shows again.
func _fly_back() -> void:
	var flyer := _copy()
	var s := get_global_transform().get_scale()
	flyer.scale = s
	flyer.top_level = true
	get_viewport().add_child(flyer)
	flyer.global_position = _at - _grab * s
	var t := flyer.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(flyer, "global_position", global_position, 0.25)
	t.tween_callback(flyer.queue_free)
	# The tile's own tween: if the task frees the tile first, the tween goes with it.
	create_tween().tween_property(self, "modulate:a", 1.0, 0.0).set_delay(0.25)


## A look-alike of the tile that takes no input (the drag preview and the flyer).
func _copy() -> Control:
	var c := duplicate(DUPLICATE_SCRIPTS) as Control
	c.size = size
	c.modulate.a = 1.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
