class_name Palette
extends RefCounted
## Colors (D-016): the thesis palette of light blue, cream, sunny yellow and
## orange for everything the child taps and reads on, with leaf green for "right"
## and nature. The five Butuan worlds keep their own accents (river teal, mango
## leaf, nipa thatch, bay blue, mountain plum; SkillCatalog.WORLDS) for scenery
## and world badges. Use these, never raw colors.

# --- Core palette (D-016) ---
const BLUE := Color("74a6cb")
const CREAM := Color("fefde0")
const YELLOW := Color("ffc918")
const ORANGE := Color("e9801f")

const PAPER := CREAM
const PAPER_DEEP := Color("f1e6b4")
const CARD := Color("fffef4")
const INK := Color("3a2a1f")
const INK_SOFT := Color("7d6857")
const SHADOW := Color(0.23, 0.15, 0.08, 0.22)

## Older names, now mapped onto the core palette.
const MANGO := YELLOW
const MANGO_DEEP := Color("cc8a00")
const CORAL := ORANGE
const CORAL_DEEP := Color("bd6212")
const BAY := BLUE
const BAY_DEEP := Color("4a7ea6")
const SKY := Color("d4e6f2")

# --- Nature and world accents (kept) ---
const TEAL := Color("2a9d8f")
const TEAL_DEEP := Color("1d7166")
const LEAF := Color("6aab4c")
const LEAF_DEEP := Color("487f33")
const NIPA := Color("b9875b")
const NIPA_DEEP := Color("845837")
const PLUM := Color("8e6aa0")
const PLUM_DEEP := Color("684c7a")
## A light plum that still takes dark text: the Big Test and night overlays.
const PLUM_LIGHT := Color("b9a2c8")
const SAND := Color("ecd3a3")

## Feedback: green for right, warm orange (never red) for "almost" (D-007).
const RIGHT := LEAF
const ALMOST := ORANGE


static func deep(c: Color) -> Color:
	return c.darkened(0.28)


static func pale(c: Color, amount: float = 0.72) -> Color:
	return c.lerp(PAPER, amount)


## Text and icon color for something drawn on `bg` (D-016): the dark ink
## whenever it is readable (WCAG 4.5:1), else whichever of ink or cream reads better.
static func text_on(bg: Color) -> Color:
	var on_ink := contrast(bg, INK)
	if on_ink >= 4.5:
		return INK
	return INK if on_ink >= contrast(bg, CARD) else CARD


## `c` darkened just enough to read as text on `bg` (WCAG 4.5:1), keeping its hue:
## colored numbers and titles stay colored but never faint (D-016).
static func readable(c: Color, bg: Color = CARD) -> Color:
	var out := c
	for i in 20:
		if contrast(out, bg) >= 4.5:
			break
		out = out.darkened(0.08)
	return out


## WCAG contrast ratio between two colors (1 to 21).
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var lin := c.srgb_to_linear()
	return 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b
