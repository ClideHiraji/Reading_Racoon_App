class_name Smooth
## Filled shapes with soft edges. Godot fills polygons and circles with hard, stair-step
## edges that show on low-res screens. Each solid fill here also gets a thin smooth outline
## in its own colour, so its edge looks smooth (the shape grows by less than a pixel).
## See-through fills (shadows, glows) are left alone: an outline would double their colour.

## The outline's width in the shape's own units; pass 1 / scale when drawing
## under a scaled transform, so it stays about one pixel wide.
const EDGE := 1.0

## Off draws plain fills, as before (to compare the two).
static var enabled := true


## draw_colored_polygon with a smooth edge.
static func polygon(ci: CanvasItem, pts: PackedVector2Array, color: Color, edge: float = EDGE) -> void:
	ci.draw_colored_polygon(pts, color)
	if not enabled or color.a < 0.99 or pts.size() < 3:
		return
	var ring := pts.duplicate()
	ring.append(pts[0])
	ci.draw_polyline(ring, color, edge, true)


## draw_circle with a smooth edge.
static func circle(ci: CanvasItem, at: Vector2, r: float, color: Color, edge: float = EDGE) -> void:
	ci.draw_circle(at, r, color)
	if not enabled or color.a < 0.99:
		return
	ci.draw_arc(at, r, 0.0, TAU, clampi(int(r * 0.6) + 12, 16, 64), color, edge, true)
