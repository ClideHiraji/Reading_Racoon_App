class_name PracticePool
extends RefCounted
## Practice games: just for fun, no hearts, no tests, no BKT changes.
## They reuse content from the worlds the child has unlocked.
## The teacher sees them as "practice" events.
## Each game is also a lesson task, so the child meets it there first:
## Rhyme Pop in World 1, Word Catch in World 2.

const GAMES := [
	{"id": "rhyme_pop", "name": "Rhyme Pop", "line": "Pop the balloons that rhyme", "skill": "Sounds",
		"icon": "bee", "scene": "res://scenes/practice/rhyme_pop.tscn"},
	{"id": "spin_words", "name": "Spin the Words", "line": "Spin to make new words", "skill": "Letters",
		"icon": "repeat", "scene": "res://scenes/practice/practice_round.tscn",
		"task": "spin_words", "variant": ""},
	{"id": "syllable_train", "name": "Syllable Train", "line": "Hook the parts to make a word",
		"skill": "Sounds", "icon": "bus", "scene": "res://scenes/practice/practice_round.tscn",
		"task": "order_tiles", "variant": "syllables"},
	{"id": "story_shuffle", "name": "Story Shuffle", "line": "Put the story in order", "skill": "Stories",
		"icon": "stories", "scene": "res://scenes/practice/practice_round.tscn",
		"task": "order_tiles", "variant": "sequence"},
	{"id": "word_catch", "name": "Word Catch", "line": "Catch the word you hear", "skill": "Words",
		"icon": "hand", "scene": "res://scenes/practice/word_catch.tscn", "min_level": 2},
]
const SKILLS := ["Sounds", "Letters", "Words", "Stories"]


static func game(id: String) -> Dictionary:
	for g in GAMES:
		if g.id == id:
			return g
	return {}


## Items from unlocked levels (normal and easy).
static func items(bank: QuestionBank, max_level: int) -> Array:
	return bank.items.filter(func(it): return int(it.level) <= max_level)


## Words with a picture, one per word: [{word, picture, lang}].
static func picture_words(bank: QuestionBank, max_level: int) -> Array:
	var seen := {}
	var out := []
	for it in items(bank, max_level):
		for w in Collection.words_from_item(it):
			var key := Collection.clean_word(w.word)
			if not seen.has(key) and Icons.exists(w.picture):
				seen[key] = true
				out.append({"word": key, "picture": w.picture, "lang": w.lang})
	return out


## Rhyme rounds from the "rhymes with" items: [{word, picture, rhyme, others, say}].
## rhyme and others are {word, picture}; `say` is the item's recorded question.
static func rhymes(bank: QuestionBank, max_level: int) -> Array:
	var out := []
	for it in items(bank, max_level):
		if not str(it.get("prompt", "")).contains("rhymes with") or not it.has("word"):
			continue
		var right := {}
		var others := []
		for c in it.get("choices", []):
			var w := {"word": str(c.get("label", c.id)), "picture": str(c.get("picture", ""))}
			if str(c.id) == str(it.answer):
				right = w
			else:
				others.append(w)
		if not right.is_empty():
			out.append({"word": str(it.word), "picture": str(it.get("picture", "")), "rhyme": right,
					"others": others, "say": str(it.get("tts_text", it.prompt))})
	return out


## Items for games that reuse lesson tasks (word wheel, syllables, story order).
static func task_items(bank: QuestionBank, max_level: int, task: String, variant: String) -> Array:
	return items(bank, max_level).filter(func(it):
		return it.task_type == task and str(it.get("variant", "")) == variant)


## Open when the unlocked worlds have enough content for a round and the game's level is reached.
static func unlocked(id: String, bank: QuestionBank, max_level: int) -> bool:
	var g := game(id)
	if g.is_empty() or max_level < int(g.get("min_level", 1)):
		return false
	match id:
		"rhyme_pop":
			return rhymes(bank, max_level).size() >= 2
		"word_catch":
			return picture_words(bank, max_level).size() >= 4
	return task_items(bank, max_level, g.task, g.variant).size() >= 2


## What a locked game card says.
static func lock_text(id: String, bank: QuestionBank, max_level: int) -> String:
	var g := game(id)
	var need := int(g.get("min_level", 1))
	if max_level < need:
		return "Finish Level %d" % (need - 1)
	for level in range(max_level + 1, SkillCatalog.MAX_LEVEL + 1):
		if unlocked(id, bank, level):
			return "Reach Level %d" % level
	return "Coming soon"


## `n` random items, no repeats.
static func pick(list: Array, n: int, rng: RandomNumberGenerator) -> Array:
	var pool := list.duplicate()
	var out := []
	while out.size() < n and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


## Coins for a finished game: one per right answer, 2 to 5.
static func coins_for(correct: int) -> int:
	return clampi(correct, 2, 5)
