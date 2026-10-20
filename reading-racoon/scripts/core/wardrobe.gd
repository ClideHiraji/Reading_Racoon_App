class_name Wardrobe
extends RefCounted
## The raccoon shop (FR-07): items bought with coins, one worn per slot.
## Rewards stay personal (no leaderboards, 06-game-design.md reward cautions).
## Local touches: a salakot hat and a sampaguita lei.

const SLOTS := ["hat", "neck", "eyes", "badge"]
const SLOT_NAMES := {"hat": "Hats", "neck": "Scarves", "eyes": "Glasses", "badge": "Pins"}

## id -> {name, slot, price}. Drawing lives in scenes/companion/raccoon.gd.
const ITEMS := {
	"cap": {"name": "River cap", "slot": "hat", "price": 30},
	"party_hat": {"name": "Party hat", "slot": "hat", "price": 40},
	"flower_crown": {"name": "Flower crown", "slot": "hat", "price": 50},
	"salakot": {"name": "Salakot", "slot": "hat", "price": 60},
	"gold_crown": {"name": "Gold crown", "slot": "hat", "price": 120},
	"scarf_teal": {"name": "River scarf", "slot": "neck", "price": 0},
	"scarf_coral": {"name": "Sunset scarf", "slot": "neck", "price": 25},
	"scarf_mango": {"name": "Mango scarf", "slot": "neck", "price": 25},
	"bow_tie": {"name": "Bow tie", "slot": "neck", "price": 35},
	"lei": {"name": "Sampaguita lei", "slot": "neck", "price": 45},
	"round_glasses": {"name": "Reading glasses", "slot": "eyes", "price": 40},
	"sunglasses": {"name": "Sunglasses", "slot": "eyes", "price": 50},
	"star_glasses": {"name": "Star glasses", "slot": "eyes", "price": 60},
	"pin_star": {"name": "Star pin", "slot": "badge", "price": 20},
	"pin_heart": {"name": "Heart pin", "slot": "badge", "price": 20},
	"pin_book": {"name": "Book pin", "slot": "badge", "price": 30},
}

var owned: Array = ["scarf_teal"]
var equipped := {"neck": "scarf_teal"}


func items_in(slot: String) -> Array:
	var out := []
	for id in ITEMS:
		if ITEMS[id].slot == slot:
			out.append(id)
	out.sort_custom(func(a, b): return ITEMS[a].price < ITEMS[b].price)
	return out


func owns(id: String) -> bool:
	return owned.has(id)


func is_worn(id: String) -> bool:
	return ITEMS.has(id) and equipped.get(ITEMS[id].slot, "") == id


## Buys and wears an item. Returns "bought", "owned", "poor" or "unknown".
## `wallet` is the GameState wallet dictionary ({"coins": n, ...}); coins are spent here.
func buy(id: String, wallet: Dictionary) -> String:
	if not ITEMS.has(id):
		return "unknown"
	if owns(id):
		return "owned"
	var price: int = ITEMS[id].price
	if int(wallet.get("coins", 0)) < price:
		return "poor"
	wallet.coins = int(wallet.coins) - price
	owned.append(id)
	wear(id)
	return "bought"


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
	owned = ["scarf_teal"]
	for id in data.get("owned", []):
		if ITEMS.has(id) and not owned.has(id):
			owned.append(id)
	equipped = {}
	var eq: Dictionary = data.get("equipped", {"neck": "scarf_teal"})
	for slot in eq:
		if owns(str(eq[slot])):
			equipped[slot] = str(eq[slot])
