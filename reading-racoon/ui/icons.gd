class_name Icons
extends RefCounted
## Vector icons and pictures. No emoji (D-009).
## - Glyphs: white SVG silhouettes in res://assets/icons (game-icons.net, CC BY 3.0, see
##   CREDITS.md), tinted in Godot for buttons, badges, tabs and the path.
## - Pictures: full-colour drawings in res://assets/pictures (D-027), drawn in their own colours
##   for the words, stickers, Home tiles and practice games. Made by tools/icon-art.

const DIR := "res://assets/icons/%s.svg"
const PICTURE_DIR := "res://assets/pictures/%s.svg"

## Paper color for each task picture, so a cat sits on pale orange and a frog on pale green
## (and the silhouette's tint where there is no full-colour picture).
const PICTURE_COLORS := {
	"cat": Palette.MANGO_DEEP, "hat": Palette.BAY, "dog": Palette.NIPA, "sun": Palette.MANGO,
	"bee": Palette.MANGO, "tree": Palette.LEAF, "car": Palette.CORAL, "star": Palette.MANGO,
	"moon": Palette.MANGO_DEEP, "fish": Palette.TEAL, "box": Palette.NIPA, "fox": Palette.CORAL,
	"frog": Palette.LEAF, "cake": Palette.CORAL, "bus": Palette.MANGO_DEEP,
	"banana": Palette.MANGO, "rabbit": Palette.INK_SOFT, "butterfly": Palette.PLUM,
	"snake": Palette.LEAF_DEEP, "ball": Palette.BAY, "mouse": Palette.INK_SOFT,
	"house": Palette.CORAL_DEEP, "goat": Palette.NIPA_DEEP, "boat": Palette.BAY,
	"bear": Palette.NIPA_DEEP, "pear": Palette.LEAF, "hen": Palette.CORAL,
	"book": Palette.BAY, "pencil": Palette.MANGO_DEEP, "bag": Palette.TEAL,
	"scissors": Palette.PLUM, "apple": Palette.CORAL_DEEP, "grapes": Palette.PLUM,
	"elephant": Palette.BAY, "ant": Palette.CORAL, "hand": Palette.NIPA,
	"lock": Palette.MANGO_DEEP, "night": Palette.PLUM, "waves": Palette.TEAL, "mountain": Palette.PLUM,
	"stories": Palette.BAY, "cloud": Palette.BAY,
	"raccoon": Palette.INK_SOFT, "hut": Palette.NIPA, "heart": Palette.CORAL,
}

static var _cache := {}
static var _pictures := {}


static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = load(DIR % name) if has_glyph(name) else null
	return _cache[name]


## True when `name` can be shown: as a full-colour picture or as a one-colour glyph.
static func exists(name: String) -> bool:
	return has_glyph(name) or has_picture(name)


## True when `name` has a one-colour glyph the game can tint (buttons, badges, tabs, the path).
static func has_glyph(name: String) -> bool:
	return name != "" and ResourceLoader.exists(DIR % name)


static func picture_color(name: String) -> Color:
	return PICTURE_COLORS.get(name, Palette.INK)


## True when `name` has a full-colour picture (D-027).
static func has_picture(name: String) -> bool:
	return name != "" and ResourceLoader.exists(PICTURE_DIR % name)


## The full-colour picture (D-027), or null when there is none.
static func picture_tex(name: String) -> Texture2D:
	if not _pictures.has(name):
		_pictures[name] = load(PICTURE_DIR % name) if has_picture(name) else null
	return _pictures[name]


## A picture as a TextureRect in its own colours, never tinted (D-027). Without a full-colour
## picture it's the silhouette, tinted `fallback` (or the picture's paper color when that's clear).
static func picture_rect(name: String, px: float, fallback := Color(0, 0, 0, 0)) -> TextureRect:
	var full := picture_tex(name)
	if full == null:
		return _rect(tex(name), px, fallback if fallback.a > 0.0 else picture_color(name))
	return _rect(full, px, Color.WHITE)


## A tinted icon as a TextureRect that keeps its aspect and ignores the mouse.
static func rect(name: String, px: float, color: Color = Color.WHITE) -> TextureRect:
	return _rect(tex(name), px, color)


static func _rect(t: Texture2D, px: float, color: Color) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
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
