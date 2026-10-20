class_name Icons
extends RefCounted
## Vector icons and task pictures: white SVG silhouettes in res://assets/icons
## (game-icons.net, CC BY 3.0, see CREDITS.md), tinted in Godot. No emoji (D-009).

const DIR := "res://assets/icons/%s.svg"

## Paper color for each task picture, so a cat is orange and a frog is green.
const PICTURE_COLORS := {
	"cat": Palette.MANGO_DEEP, "hat": Palette.INK, "dog": Palette.NIPA, "sun": Palette.MANGO,
	"bee": Palette.MANGO, "tree": Palette.LEAF, "car": Palette.CORAL, "star": Palette.MANGO,
	"moon": Palette.MANGO_DEEP, "fish": Palette.TEAL, "box": Palette.NIPA, "fox": Palette.CORAL,
	"frog": Palette.LEAF, "cake": Palette.CORAL, "bus": Palette.MANGO_DEEP,
	"banana": Palette.MANGO, "rabbit": Palette.INK_SOFT, "butterfly": Palette.PLUM,
	"snake": Palette.LEAF_DEEP, "ball": Palette.INK, "mouse": Palette.INK_SOFT,
	"house": Palette.CORAL_DEEP, "goat": Palette.NIPA_DEEP, "boat": Palette.BAY,
	"bear": Palette.NIPA_DEEP, "pear": Palette.LEAF, "hen": Palette.CORAL,
	"book": Palette.BAY, "pencil": Palette.MANGO_DEEP, "bag": Palette.TEAL,
	"scissors": Palette.PLUM, "apple": Palette.CORAL_DEEP, "grapes": Palette.PLUM,
	"elephant": Palette.INK_SOFT, "ant": Palette.INK, "hand": Palette.NIPA,
	"lock": Palette.MANGO_DEEP, "night": Palette.PLUM, "waves": Palette.TEAL, "mountain": Palette.PLUM,
	"stories": Palette.BAY, "cloud": Palette.INK_SOFT,
}

static var _cache := {}


static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = load(DIR % name) if ResourceLoader.exists(DIR % name) else null
	return _cache[name]


static func exists(name: String) -> bool:
	return ResourceLoader.exists(DIR % name)


static func picture_color(name: String) -> Color:
	return PICTURE_COLORS.get(name, Palette.INK)


## A tinted icon as a TextureRect that keeps its aspect and ignores the mouse.
static func rect(name: String, px: float, color: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.self_modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return r


## Draws a tinted icon centered at `center` inside a custom _draw().
static func draw(ci: CanvasItem, name: String, center: Vector2, px: float, color: Color) -> void:
	var t := tex(name)
	if t:
		ci.draw_texture_rect(t, Rect2(center - Vector2(px, px) / 2, Vector2(px, px)), false, color)
