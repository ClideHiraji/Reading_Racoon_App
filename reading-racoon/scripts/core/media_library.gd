class_name MediaLibrary
extends RefCounted
## Books for the Library and songs, read-alongs and videos for Watch & Listen
## (D-017). Children never browse the open internet (RA 10173): everything here
## is bundled with the app or picked by the teacher or admin. Teacher-picked
## items arrive as the same JSON shape in user://content/ (and videos as Ogg
## Theora files the app can play); they show as "From your teacher".

const BOOKS_FILE := "res://content/library.json"
const WATCH_FILE := "res://content/watch.json"
const DOWNLOADED := "user://content/"
const LANGUAGES := {"en": "English", "fil": "Filipino", "bis": "Bisaya"}
const KINDS := {"song": "Songs & chants", "read_along": "Read-alongs", "video": "Videos"}

var books: Array = []
var watch: Array = []


func load_all() -> void:
	books = _read(BOOKS_FILE, "books")
	watch = _read(WATCH_FILE, "items")
	for b in _read(DOWNLOADED + "library.json", "books"):
		b["teacher"] = true
		books.append(b)
	for w in _read(DOWNLOADED + "watch.json", "items"):
		w["teacher"] = true
		watch.append(w)


func _read(path: String, key: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data.get(key, []) if typeof(data) == TYPE_DICTIONARY else []


func book(id: String) -> Dictionary:
	for b in books:
		if b.id == id:
			return b
	return {}


func media(id: String) -> Dictionary:
	for m in watch:
		if m.id == id:
			return m
	return {}


## Books in one language ("" = all), easiest first.
func books_in(lang: String) -> Array:
	var out := books.filter(func(b): return lang == "" or Collection.lang_of(b.language) == lang)
	out.sort_custom(func(a, b): return _rank(a) < _rank(b))
	return out


func watch_in(kind: String) -> Array:
	return watch.filter(func(m): return kind == "" or m.kind == kind)


## The lines Watch & Listen plays: a song's lines, or a read-along's book pages.
func lines_of(item: Dictionary) -> Array:
	if item.get("kind", "") == "read_along":
		var b := book(str(item.get("book", "")))
		return b.get("pages", [])
	return item.get("lines", [])


## Videos play only once their file is on the tablet (downloaded on Wi-Fi).
static func video_ready(item: Dictionary) -> bool:
	return item.get("kind", "") != "video" or FileAccess.file_exists(str(item.get("file", "")))


## A downloaded page picture (teacher books, D-020) as a texture, or null when the
## page has none or it isn't on the tablet yet (the page then shows its paper scene).
static func page_texture(page: Dictionary) -> Texture2D:
	var path := str(page.get("image", ""))
	if not ContentPlan.safe_local(path) or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img and not img.is_empty() else null


static func _rank(b: Dictionary) -> int:
	return {"easy": 0, "medium": 1, "hard": 2}.get(str(b.get("level", "easy")), 0)
