class_name LetterTile
extends ChunkyButton
## A letter tile that can be dragged into a DropSlot (or tapped).

var letter := ""


func _get_drag_data(_at: Vector2) -> Variant:
	if disabled:
		return null
	var preview := duplicate() as Button
	preview.size = size
	preview.modulate.a = 0.85
	var holder := Control.new()
	holder.add_child(preview)
	preview.position = -size / 2
	set_drag_preview(holder)
	return {"letter": letter}
