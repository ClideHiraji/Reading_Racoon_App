class_name HubSections
extends RefCounted
## Every place the home hub can open (D-015, wireframe "Home hub" and "Play picker").
## kind decides which time rule applies (AccessPolicy):
## - adventure: lessons and tests, the school schedule (decide)
## - free: Practice, Library, Watch & Listen, the daily free-play timer (free_play)
## - collection: Closet, Stickers, Word Book, Today, open whenever the hub is (hub)
## scene "" = not built yet: the hub opens the "Racoon is still building it" page.
## All sections are built now (D-017); keep the page for new ones.

const ALL := {
	"adventure": {"name": "Adventure", "icon": "waves", "color": Palette.YELLOW, "kind": "adventure",
		"scene": "res://scenes/path/learning_path.tscn"},
	"practice": {"name": "Practice", "icon": "bulb", "color": Palette.LEAF, "kind": "free",
		"scene": "res://scenes/practice/practice.tscn"},
	"library": {"name": "Library", "icon": "book", "color": Palette.ORANGE, "kind": "free",
		"scene": "res://scenes/library/library.tscn"},
	"watch": {"name": "Watch & Listen", "icon": "speaker", "color": Palette.BLUE, "kind": "free",
		"scene": "res://scenes/watch/watch.tscn"},
	"closet": {"name": "Racoon's Closet", "icon": "hat", "color": Palette.BLUE, "kind": "collection",
		"scene": "res://scenes/shop/shop.tscn"},
	"stickers": {"name": "Sticker Album", "icon": "star", "color": Palette.YELLOW, "kind": "collection",
		"scene": "res://scenes/collection/stickers.tscn"},
	"words": {"name": "My Word Book", "icon": "pencil", "color": Palette.ORANGE, "kind": "collection",
		"scene": "res://scenes/collection/words.tscn"},
	"today": {"name": "Today", "icon": "sun", "color": Palette.ORANGE, "kind": "collection",
		"scene": "res://scenes/collection/today.tscn"},
}


static func get_info(id: String) -> Dictionary:
	return ALL.get(id, {})


static func is_built(id: String) -> bool:
	return str(get_info(id).get("scene", "")) != ""
