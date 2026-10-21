class_name Collection
extends RefCounted
## What the child collects outside the lessons (D-017): stickers for the Sticker
## Album, words for My Word Book, the days they played, today's three goals and
## which books and songs they finished. Pure data, saved in the profile and
## unit-tested; GameState queues the sync events. Stickers are a personal
## collection: no ranking, and nothing is ever taken away (D-007).

## How a sticker in each group is earned (shown in the album).
const GROUPS := {
	"adventure": {"name": "Adventure", "how": "Finish a lesson", "color": Palette.TEAL},
	"books": {"name": "Books", "how": "Finish a book in the Library", "color": Palette.ORANGE},
	"games": {"name": "Games", "how": "Play a Practice game", "color": Palette.LEAF},
	"watch": {"name": "Watch", "how": "Finish a song or a video", "color": Palette.BLUE},
	"days": {"name": "Days", "how": "Play on a new day", "color": Palette.YELLOW},
	"goals": {"name": "Goals", "how": "Finish all of today's goals", "color": Palette.PLUM_LIGHT},
}

## Every sticker, in the order they are earned inside their group.
const STICKERS := {
	"fish": {"name": "River fish", "group": "adventure"},
	"boat": {"name": "Little boat", "group": "adventure"},
	"waves": {"name": "River waves", "group": "adventure"},
	"tree": {"name": "Mango tree", "group": "adventure"},
	"hut": {"name": "Bahay kubo", "group": "adventure"},
	"mountain": {"name": "Mount Mayapay", "group": "adventure"},
	"trophy": {"name": "Gold trophy", "group": "adventure"},
	"book": {"name": "First book", "group": "books"},
	"stories": {"name": "Story star", "group": "books"},
	"pencil": {"name": "Pencil", "group": "books"},
	"bulb": {"name": "Bright idea", "group": "books"},
	"butterfly": {"name": "Butterfly", "group": "books"},
	"rabbit": {"name": "Rabbit", "group": "books"},
	"crown": {"name": "Book crown", "group": "books"},
	"ball": {"name": "Ball", "group": "games"},
	"bee": {"name": "Busy bee", "group": "games"},
	"frog": {"name": "Frog", "group": "games"},
	"fox": {"name": "Fox", "group": "games"},
	"snake": {"name": "Snake", "group": "games"},
	"cat": {"name": "Cat", "group": "games"},
	"bolt": {"name": "Lightning", "group": "games"},
	"speaker": {"name": "Sing!", "group": "watch"},
	"ear": {"name": "Good ears", "group": "watch"},
	"sparkles": {"name": "Sparkles", "group": "watch"},
	"elephant": {"name": "Elephant", "group": "watch"},
	"hen": {"name": "Hen", "group": "watch"},
	"goat": {"name": "Goat", "group": "watch"},
	"sun": {"name": "Sunny day", "group": "days"},
	"cloud": {"name": "Cloudy day", "group": "days"},
	"moon": {"name": "Moon", "group": "days"},
	"palm": {"name": "Palm tree", "group": "days"},
	"apple": {"name": "Apple", "group": "days"},
	"banana": {"name": "Banana", "group": "days"},
	"grapes": {"name": "Grapes", "group": "days"},
	"star": {"name": "Gold star", "group": "goals"},
	"heart": {"name": "Big heart", "group": "goals"},
	"gift": {"name": "Gift", "group": "goals"},
	"cake": {"name": "Cake", "group": "goals"},
	"chest": {"name": "Treasure", "group": "goals"},
	"raccoon": {"name": "Racoon", "group": "goals"},
}

## Today's goals: one story, one game, and one lesson or song.
const GOALS := [
	{"id": "story", "text": "Read a story", "icon": "book", "section": "library"},
	{"id": "game", "text": "Play a game", "icon": "bulb", "section": "practice"},
	{"id": "lesson", "text": "Finish a lesson or a song", "icon": "star", "section": "adventure"},
]

## Sticker id -> date earned.
var stickers := {}
## Word -> {picture, lang, from, date}.
var words := {}
## Dates played, oldest first.
var days: Array = []
## Today's goal progress: {date, done: [goal ids]}.
var goals := {"date": "", "done": []}
## Group -> the last date a once-a-day sticker was given.
var daily := {}
## Book or song id -> date first finished.
var finished := {}


# --- Stickers ---------------------------------------------------------------------------

static func sticker(id: String) -> Dictionary:
	return STICKERS.get(id, {})


static func in_group(group: String) -> Array:
	return STICKERS.keys().filter(func(id): return STICKERS[id].group == group)


static func color_of(id: String) -> Color:
	return GROUPS.get(str(sticker(id).get("group", "")), {}).get("color", Palette.YELLOW)


func has_sticker(id: String) -> bool:
	return stickers.has(id)


func count(group: String = "") -> int:
	if group == "":
		return stickers.size()
	return in_group(group).filter(func(id): return stickers.has(id)).size()


## Gives the next sticker of a group; "" when the whole group is collected.
func earn(group: String, date: String) -> String:
	for id in in_group(group):
		if not stickers.has(id):
			stickers[id] = date
			return id
	return ""


## At most one sticker of this group a day (games, adventure), so the album
## lasts all term.
func earn_once_a_day(group: String, date: String) -> String:
	if daily.get(group, "") == date:
		return ""
	var id := earn(group, date)
	if id != "":
		daily[group] = date
	return id


# --- Words ------------------------------------------------------------------------------

## Adds a word the child met; false if it's already there or isn't a single word.
func add_word(word: String, picture: String, lang: String, from: String, date: String) -> bool:
	var w := clean_word(word)
	if w == "" or words.has(w):
		return false
	words[w] = {"picture": picture, "lang": lang, "from": from, "date": date}
	return true


## "Isda." -> "isda"; "" for anything that isn't one short word of letters.
static func clean_word(word: String) -> String:
	var w := word.strip_edges().to_lower().trim_suffix(".").trim_suffix("!").trim_suffix("?")
	if w.length() < 2 or w.length() > 14:
		return ""
	for i in w.length():
		var c := w.unicode_at(i)
		var letter := (c >= 97 and c <= 122) or c == 0xF1   # a-z, ñ
		if not letter:
			return ""
	return w


## Words, A-Z, optionally only one language ("en", "fil", "bis").
func word_list(lang: String = "") -> Array:
	var out := []
	for w in words:
		if lang == "" or words[w].lang == lang:
			out.append(w)
	out.sort()
	return out


## The words practiced in an Adventure item: what the child built or picked.
## [{word, picture, lang}], only words that come with a picture.
static func words_from_item(item: Dictionary) -> Array:
	var lang := lang_of(str(item.get("language", "en")))
	var out := []
	var picture := str(item.get("picture", ""))
	match str(item.get("task_type", "")):
		"tap_choice":
			for c in item.get("choices", []):
				if str(c.id) == str(item.get("answer", "")) and c.has("picture"):
					out.append({"word": str(c.get("label", c.id)), "picture": str(c.picture), "lang": lang})
			if item.has("word") and picture != "":
				out.append({"word": str(item.word), "picture": picture, "lang": lang})
		"drag_letter":
			if picture != "":
				var pattern: Array = item.get("pattern", [])
				var word := "".join(PackedStringArray(pattern.map(
						func(p): return str(item.answer) if p == "_" else str(p))))
				out.append({"word": word, "picture": picture, "lang": lang})
		"spin_words":
			if picture != "":
				out.append({"word": str(item.answer) + str(item.get("rime", "")), "picture": picture, "lang": lang})
		"order_tiles":
			if item.get("variant", "") == "syllables" and picture != "":
				out.append({"word": "".join(PackedStringArray(item.get("tiles", []))), "picture": picture,
						"lang": lang})
	return out.filter(func(w): return clean_word(w.word) != "")


## "fil-placeholder" -> "fil", "bis-..." / "ceb" -> "bis", else "en".
static func lang_of(language: String) -> String:
	if language.begins_with("fil") or language.begins_with("tl"):
		return "fil"
	if language.begins_with("bis") or language.begins_with("ceb"):
		return "bis"
	return "en"


# --- Days and today's goals ---------------------------------------------------------------

## True the first time the child plays on `date`.
func mark_day(date: String) -> bool:
	if days.has(date):
		return false
	days.append(date)
	return true


func goals_done(date: String) -> Array:
	return goals.done if goals.date == date else []


func goals_left(date: String) -> int:
	return GOALS.size() - goals_done(date).size()


## Marks a goal done today. Returns {new: this goal just got done, all: every goal
## just got done}.
func complete_goal(goal: String, date: String) -> Dictionary:
	if goals.date != date:
		goals = {"date": date, "done": []}
	if goal in goals.done or not GOALS.any(func(g): return g.id == goal):
		return {"new": false, "all": false}
	goals.done.append(goal)
	return {"new": true, "all": goals.done.size() == GOALS.size()}


# --- Books and songs ----------------------------------------------------------------------

## True the first time a book or song is finished.
func finish(id: String, date: String) -> bool:
	if finished.has(id):
		return false
	finished[id] = date
	return true


func is_finished(id: String) -> bool:
	return finished.has(id)


# --- Saving -----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"stickers": stickers, "words": words, "days": days, "goals": goals, "daily": daily,
			"finished": finished}


func from_dict(d: Dictionary) -> void:
	stickers = d.get("stickers", {})
	words = d.get("words", {})
	days = d.get("days", [])
	var g: Dictionary = d.get("goals", {})
	goals = {"date": str(g.get("date", "")), "done": g.get("done", [])}
	daily = d.get("daily", {})
	finished = d.get("finished", {})
