class_name WorldTrail
extends Control
## The winding trail of one world (D-007, D-009): PathNodes placed on an S-curve,
## joined by dotted footsteps, with faded paper cut-outs from that world's scenery
## along the edges.

signal node_pressed(n: Dictionary, node: PathNode)

const ROW_H := 190.0
const SWING := 150.0
const DECOR := {
	"river": ["waves", "cloud", "fish"],
	"grove": ["tree", "palm", "pear"],
	"village": ["hut", "tree", "hen"],
	"bay": ["boat", "waves", "fish"],
	"mountain": ["mountain", "tree", "cloud"],
}

var nodes: Array[PathNode] = []
var _layout: Array = []
var _scene := "river"
var _color := Palette.TEAL
var _focus := -1


func setup(layout: Array, world_color: Color, scene: String) -> void:
	_layout = layout
	_color = world_color
	_scene = scene
	custom_minimum_size = Vector2(0, ROW_H * layout.size() + 20)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in layout.size():
		var n: Dictionary = layout[i]
		var node := PathNode.new()
		node.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(node)
		node.setup(n.kind, n.state, world_color)
		node.pressed.connect(func(): node_pressed.emit(n, node))
		nodes.append(node)
		if _focus < 0 and n.state in ["current", "practice", "ready"]:
			_focus = i
	resized.connect(_place)


func focus_index() -> int:
	return _focus


func row_offset(i: int) -> float:
	return sin(i * 0.95 + 0.6) * SWING


func node_center(i: int) -> Vector2:
	return Vector2(size.x / 2 + row_offset(i), ROW_H * i + ROW_H / 2 + 10)


func _place() -> void:
	for i in nodes.size():
		var node := nodes[i]
		node.position = node_center(i) - node.disc_center()
	queue_redraw()


func _draw() -> void:
	var decor: Array = DECOR.get(_scene, ["cloud"])
	for i in _layout.size():
		if i == _focus:
			continue
		var off := row_offset(i)
		var x := size.x * (0.14 if off > 0 else 0.86)
		var name: String = decor[i % decor.size()]
		Icons.draw(self, name, Vector2(x, node_center(i).y + 10), 84, Palette.pale(_color, 0.8))
	for i in range(1, _layout.size()):
		var done: bool = _layout[i - 1].state in ["done", "open", "bonus_done"]
		_dots(node_center(i - 1), node_center(i), Palette.MANGO if done else Palette.PAPER_DEEP.darkened(0.08))


## Footstep dots along a gentle curve between two node centers.
func _dots(a: Vector2, b: Vector2, col: Color) -> void:
	var mid := (a + b) / 2 + Vector2((a.x - b.x) * 0.25, 0)
	var steps := 7
	for s in range(1, steps):
		var t := float(s) / steps
		var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
		draw_circle(p + Vector2(0, 3), 7, Color(Palette.SHADOW, 0.12))
		draw_circle(p, 7, col)
