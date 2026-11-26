class_name HubSections
extends RefCounted
## Every place the home hub can open.
## `kind` picks the time rule in AccessPolicy:
## - adventure: lessons and tests, school schedule
## - free: Practice, Library, Watch & Listen, daily free-play timer
## - collection: Closet, Stickers, Word Book, Today, open whenever the hub is
## scene "" = not built yet, so the hub shows the "still building it" page.

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
	var info: Dictionary = ALL.get(id, {})
	if id == "closet":
		# The Closet uses the buddy's name: "Roco's Closet", "Closet ni Rina".
		var tree := Engine.get_main_loop() as SceneTree
		var gs: Node = tree.root.get_node_or_null("GameState") if tree else null
		if gs:
			info = info.duplicate()
			info.name = gs.talk("closet_title")
	return info


static func is_built(id: String) -> bool:
	return str(get_info(id).get("scene", "")) != ""
