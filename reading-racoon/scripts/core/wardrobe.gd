class_name Wardrobe
extends RefCounted
## The raccoon's Closet: items bought with coins or earned, one worn per slot.
## Rewards stay personal (no leaderboards).
## Local items: salakot, sampaguita lei, waling-waling orchid, balangay pin, parol.
## Racoon starts wearing nothing; the River scarf and the open book are free.
## The book goes in the "In his paws" slot.
##
## Every item has a tier: copper, silver, violet, gold or diamond. The tier sets how it's
## drawn and moves (copper is plain, diamond shimmers), its Closet card and its price.
## Some items are earned instead of bought. Nothing is random: prices and goals are shown up front.

## "top" = tops and dresses. "pet" floats beside his head; pets are drawn in code (Pet).
const SLOTS := ["hat", "neck", "eyes", "top", "paws", "pet"]
const SLOT_NAMES := {"hat": "Hats", "neck": "Scarves", "eyes": "Glasses", "top": "Clothes",
		"paws": "In his paws", "pet": "Pets"}
## Rina's Closet says "In her paws". Use slot_name(), not SLOT_NAMES.
const SLOT_NAMES_RINA := {"paws": "In her paws"}

## Each tier: its name, its rank (1-5, shown as stars so it doesn't rely on colour),
## its colours, and what it means for the child.
const TIER_ORDER := ["copper", "silver", "violet", "gold", "diamond"]
const TIERS := {
	"copper": {"name": "Copper", "rank": 1, "color": Color("c47a45"), "light": Color("f8e2cf"),
			"deep": Color("8a4f2b"), "means": "Free, or earned with your first steps"},
	"silver": {"name": "Silver", "rank": 2, "color": Color("a3b1be"), "light": Color("eef2f6"),
			"deep": Color("5f6c78"), "means": "A few coins, or earned"},
	"violet": {"name": "Violet", "rank": 3, "color": Color("9a6fc0"), "light": Color("f0e6fa"),
			"deep": Color("5f3f80"), "means": "Saved up for, or won by playing"},
	"gold": {"name": "Gold", "rank": 4, "color": Color("f2b705"), "light": Color("fff3c4"),
			"deep": Color("9c6700"), "means": "Lots of coins: a big treat"},
	"diamond": {"name": "Diamond", "rank": 5, "color": Color("4fc3e6"), "light": Color("e2f7ff"),
			"deep": Color("23729c"), "means": "The rarest: the most coins, or a very big goal"},
}

## Every item is one line in content/closet.json. Its art is
## tools/racoon-art/closet/<folder>/<id>.svg; motion-demo/build_racoon.py builds both into the game.
const CATALOG := "res://content/closet.json"

## id -> {name, slot, tier, price}, plus {earn: [what, how many]} for an earned item (see earn_text()),
## {scarf: true} for a scarf, {recolor: {...}} for a colour of another item.
static var ITEMS: Dictionary = _load_items()


## A slot's name for the buddy whose Closet it is ("roco" or "rina").
## The tab reads it aloud and shows it as a tooltip.
static func slot_name(slot: String, who: String) -> String:
	if who == "rina" and SLOT_NAMES_RINA.has(slot):
		return str(SLOT_NAMES_RINA[slot])
	return str(SLOT_NAMES.get(slot, slot))


static func _load_items() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("items")) != TYPE_DICTIONARY:
		push_error("Wardrobe: can't read %s" % CATALOG)
		return {}
	var items: Dictionary = data.items
	for id in items:
		var it: Dictionary = items[id]
		it.price = int(it.get("price", 0))
		if it.has("earn"):
			it.earn = [str(it.earn[0]), int(it.earn[1])]
	return items


var owned: Array = free_items()
var equipped := {}


## Items every child owns from the start (free, not earned).
static func free_items() -> Array:
	var out := []
	for id in ITEMS:
		if int(ITEMS[id].price) == 0 and not ITEMS[id].has("earn"):
			out.append(id)
	return out


static func tier_of(id: String) -> Dictionary:
	return TIERS.get(str(ITEMS.get(id, {}).get("tier", "copper")), TIERS.copper)


## True for an item drawn in code instead of on a Closet sheet (the pets).
static func is_code_drawn(id: String) -> bool:
	return ITEMS.has(id) and str(ITEMS[id].get("drawn", "")) == "code"


static func is_earned_item(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].has("earn")


## A scarf is drawn round his neck as a band and a knot.
static func is_scarf(id: String) -> bool:
	return bool(ITEMS.get(id, {}).get("scarf", false))


## A diamond scarf with long ends that blow behind him: its WindScarf style, or "".
static func wind_of(id: String) -> String:
	return str(ITEMS.get(id, {}).get("wind", ""))


## How to earn an item, read to the child: "Finish a lesson", "Read 5 books".
static func earn_text(id: String) -> String:
	if not is_earned_item(id):
		return ""
	var what: String = ITEMS[id].earn[0]
	var n: int = ITEMS[id].earn[1]
	match what:
		"lessons":
			return "Finish a lesson" if n == 1 else "Finish %d lessons" % n
		"books":
			return "Read a book" if n == 1 else "Read %d books" % n
		"days":
			return "Play on %d days" % n
		"goal_days":
			return "Finish all of today's goals" if n == 1 else "Finish today's goals on %d days" % n
		"games":
			return "Play %d Practice games" % n
		"worlds":
			if n == 1:
				return "Finish World 1"
			return "Finish all %d worlds" % n if n >= 5 else "Finish %d worlds" % n
		"stickers":
			return "Collect all %d stickers" % n
	return ""


## Items in a slot, by tier (copper first), then price.
func items_in(slot: String) -> Array:
	var out := []
	for id in ITEMS:
		if ITEMS[id].slot == slot:
			out.append(id)
	out.sort_custom(func(a, b):
		var ra: int = tier_of(a).rank
		var rb: int = tier_of(b).rank
		return ra < rb if ra != rb else int(ITEMS[a].price) < int(ITEMS[b].price))
	return out


func owns(id: String) -> bool:
	return owned.has(id)


func is_worn(id: String) -> bool:
	return ITEMS.has(id) and equipped.get(ITEMS[id].slot, "") == id


## Buys and wears an item. Returns "bought", "owned", "poor", "earn" (earned, not sold)
## or "unknown". `wallet` is GameState's wallet ({"coins": n, ...}).
func buy(id: String, wallet: Dictionary) -> String:
	if not ITEMS.has(id):
		return "unknown"
	if owns(id):
		return "owned"
	if is_earned_item(id):
		return "earn"
	var price: int = ITEMS[id].price
	if int(wallet.get("coins", 0)) < price:
		return "poor"
	wallet.coins = int(wallet.coins) - price
	owned.append(id)
	wear(id)
	return "bought"


## Earned items whose goal `progress` ({what: count}) is reached and not owned yet.
## They're added to `owned` and returned so the game can show them.
func grant_earned(progress: Dictionary) -> Array:
	var got := []
	for id in ITEMS:
		if is_earned_item(id) and not owns(id) \
				and int(progress.get(ITEMS[id].earn[0], 0)) >= int(ITEMS[id].earn[1]):
			owned.append(id)
			got.append(id)
	return got


## Wears an owned item, replacing whatever was in that slot.
func wear(id: String) -> bool:
	if not owns(id):
		return false
	equipped[ITEMS[id].slot] = id
	return true


func take_off(slot: String) -> void:
	equipped.erase(slot)


func to_dict() -> Dictionary:
	return {"owned": owned.duplicate(), "equipped": equipped.duplicate()}


func from_dict(data: Dictionary) -> void:
	owned = free_items()
	for id in data.get("owned", []):
		if ITEMS.has(id) and not owned.has(id):
			owned.append(id)
	equipped = {}
	var eq: Dictionary = data.get("equipped", {})
	for slot in eq:
		if owns(str(eq[slot])):
			equipped[slot] = str(eq[slot])
