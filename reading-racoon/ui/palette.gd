class_name Palette
extends RefCounted
## "Butuan storybook" colors (D-009): warm paper, river teal, mango, leaf, nipa
## thatch, sunset coral, bay blue and mountain plum. Use these, never raw colors.

const PAPER := Color("f7eedd")
const PAPER_DEEP := Color("ecdcbf")
const CARD := Color("fffaf0")
const INK := Color("3a2a1f")
const INK_SOFT := Color("7d6857")
const SHADOW := Color(0.23, 0.15, 0.08, 0.22)

const TEAL := Color("2a9d8f")
const TEAL_DEEP := Color("1d7166")
const MANGO := Color("f2b134")
const MANGO_DEEP := Color("cf8611")
const LEAF := Color("6aab4c")
const LEAF_DEEP := Color("487f33")
const NIPA := Color("b9875b")
const NIPA_DEEP := Color("845837")
const CORAL := Color("e66f55")
const CORAL_DEEP := Color("bf4f39")
const BAY := Color("3f80aa")
const BAY_DEEP := Color("2a5d80")
const PLUM := Color("8e6aa0")
const PLUM_DEEP := Color("684c7a")
const SKY := Color("d6ece7")
const SAND := Color("ecd3a3")

## Feedback: green for right, warm mango (never red) for "almost" (D-007).
const RIGHT := LEAF
const ALMOST := MANGO_DEEP


static func deep(c: Color) -> Color:
	return c.darkened(0.28)


static func pale(c: Color, amount: float = 0.72) -> Color:
	return c.lerp(PAPER, amount)
