class_name HintText
extends RefCounted
## What Racoon says after a wrong first try (a hint that points the way, not the
## answer) and the explanation shown with the answer after a wrong second try
## (D-021, FR-14). An item's own "hint" / "explain" in the content JSON wins
## (story questions have them); otherwise they are built from the item's data by
## its pattern, in the item's language. Placeholder wording for teacher review,
## like the items themselves (issue 15).

const VOWELS := "aeiou"
## A word for each letter sound, for "b says /b/, like ball" (English items).
const EXAMPLES := {
	"a": "apple", "b": "ball", "c": "cat", "d": "dog", "e": "egg", "f": "fish", "g": "goat",
	"h": "hat", "i": "insect", "j": "jam", "k": "kite", "l": "lion", "m": "moon", "n": "nest",
	"o": "octopus", "p": "pig", "r": "rabbit", "s": "sun", "t": "tree", "u": "umbrella",
	"v": "van", "w": "web", "y": "yo-yo", "z": "zebra",
}


static func hint(item: Dictionary) -> String:
	if str(item.get("hint", "")) != "":
		return item.hint
	var fil := _fil(item)
	var answer := answer_label(item)
	match str(item.get("task_type", "")):
		"order_tiles":
			match str(item.get("variant", "")):
				"syllables":
					var word := "".join(_keys(item))
					return ("Sabihin nang dahan-dahan: %s. Aling bahagi ang nauuna?" if fil
							else "Say %s slowly. Which part do you hear first?") % word
				"sequence":
					return ("Ano ang unang nangyari sa kuwento? Doon ka magsimula." if fil
							else "What happened first in the story? Start there.")
			return ("Nagsisimula ang pangungusap sa malaking titik at nagtatapos sa tuldok." if fil
					else "A sentence starts with a capital letter and ends with a period.")
		"drag_letter":
			var word := _drag_word(item)
			var where := _gap_place(item, fil)
			return ("Sabihin nang dahan-dahan: %s. Ano ang tunog sa %s?" if fil
					else "Say %s slowly. Listen for the %s sound.") % [word, where]
		"spin_words":
			var word := answer + str(item.get("rime", ""))
			return ("Sabihin nang dahan-dahan: %s. Ano ang unang tunog?" if fil
					else "Say %s slowly. What sound do you hear first?") % word
	var prompt := str(item.get("prompt", ""))
	var tts := str(item.get("tts_text", ""))
	if item.has("sentence"):
		return ("Basahin muli ang pangungusap. Aling salita ang bagay?" if fil
				else "Read the sentence again. Which word makes sense?")
	if prompt.contains("rhymes with"):
		var word := str(item.get("word", ""))
		return "Say %s slowly. Listen to the end: %s. Which word ends the same way?" % [
				word, rime(word)]
	if prompt.contains("starts with /"):
		var like := _after(tts, "like ").trim_suffix("?")
		return "Say each word slowly. Listen to its first sound. Which one starts like %s?" % (
				like if like != "" else _between(prompt, "/", "/"))
	if prompt.contains("letter says"):
		var sound := _after(tts, "says ").trim_suffix("?")
		return "Make the sound with me: %s. Which letter makes that sound?" % sound
	if prompt.begins_with("Tap the letter"):
		return "Look closely at each letter. Find %s, the first letter of %s." % [
				answer, EXAMPLES.get(answer, answer)]
	if prompt.contains("starts with which letter"):
		var word := prompt.get_slice(" ", 0).to_lower()
		return "Say %s slowly. What is the very first sound?" % word
	if prompt.begins_with("Which word says"):
		return "Look at the first and the last letter. %s starts with %s and ends with %s." % [
				cap(answer), answer.left(1), answer.right(1)]
	if prompt.begins_with("Tap the word") or prompt.begins_with("Pindutin ang salitang"):
		return ("Ang salitang %s ay nagsisimula sa %s. Hanapin ito." if fil
				else "The word %s starts with %s. Look for it.") % [answer, answer.left(1)]
	if item.has("word") and item.get("competency", "") == "RL1VWK-I-2a":
		var spelled := "-".join(Array(str(item.word).split("")))
		return ("Basahin nang dahan-dahan: %s. Aling larawan ito?" if fil
				else "Read the word slowly: %s. Which picture is it?") % spelled
	if item.get("competency", "") == "RL1VWK-I-1":
		var name := _last_word(prompt)
		return ("Sabihin ang pangalan ng bawat larawan. Alin ang %s?" if fil
				else "Say the name of each picture. Which one is the %s?") % name
	if item.has("passage"):
		return ("Pakinggan muli ang kuwento. Pindutin ang aklat sa itaas." if fil
				else "Listen to the story again. Tap the book at the top.")
	return "Tingnan muli nang mabuti. Kaya mo 'yan!" if fil else "Look again carefully. You can do it!"


static func explain(item: Dictionary) -> String:
	if str(item.get("explain", "")) != "":
		return item.explain
	var fil := _fil(item)
	var answer := answer_label(item)
	match str(item.get("task_type", "")):
		"order_tiles":
			var parts := _ordered_texts(item)
			match str(item.get("variant", "")):
				"syllables":
					return ("%s. Iyan ang %s!" if fil else "%s makes %s.") % [
							cap("-".join(parts)), "".join(parts)]
				"sequence":
					var words := ["Una", "Sunod", "Pagkatapos", "Huli"] if fil \
							else ["First", "Next", "Then", "Last"]
					var out := []
					for i in parts.size():
						var w: String = words[0] if i == 0 else (words[3] if i == parts.size() - 1
								else words[mini(i, 2)])
						out.append("%s: %s" % [w, parts[i]])
					return " ".join(out)
			return ("Ang tamang ayos: %s" if fil else "It says: %s") % " ".join(parts)
		"drag_letter":
			var word := _drag_word(item)
			return ("Ang %s ay %s." if fil else "%s spells %s.") % [
					cap("-".join(Array(word.split("")))), word]
		"spin_words":
			var rime_part := str(item.get("rime", ""))
			return ("Ang %s at %s ay %s." if fil else "%s and %s make %s.") % [
					cap(answer) if not fil else answer, rime_part, answer + rime_part]
	var prompt := str(item.get("prompt", ""))
	var tts := str(item.get("tts_text", ""))
	if item.has("sentence"):
		var full := str(item.sentence).replace("___", answer)
		return ("Ang buo: %s" if fil else "It says: %s") % full
	if prompt.contains("rhymes with"):
		var word := str(item.get("word", ""))
		return "%s and %s rhyme. They both end with %s." % [cap(word), answer, rime(word)]
	if prompt.contains("starts with /"):
		return "%s starts with the sound %s." % [cap(answer), _between(prompt, "/", "/")]
	if prompt.contains("letter says"):
		return "This is the letter %s. It says %s, like %s." % [answer,
				_after(tts, "says ").trim_suffix("?"), EXAMPLES.get(answer, answer)]
	if prompt.begins_with("Tap the letter"):
		return "This is the letter %s, the first letter of %s." % [answer, EXAMPLES.get(answer, answer)]
	if prompt.contains("starts with which letter"):
		return "%s starts with the letter %s." % [prompt.get_slice(" ", 0), answer]
	if prompt.begins_with("Which word says") or prompt.begins_with("Tap the word") \
			or prompt.begins_with("Pindutin ang salitang"):
		return ("Ito ang salitang %s: %s." if fil else "This word says %s: %s.") % [answer,
				"-".join(Array(answer.split("")))]
	if item.has("word") and item.get("competency", "") == "RL1VWK-I-2a":
		return ("Ang salita ay %s." if fil else "The word says %s.") % item.word
	if item.get("competency", "") == "RL1VWK-I-1":
		var name := _last_word(prompt)
		if fil:
			return "Ito ang %s." % name
		return "This is %s %s." % ["an" if VOWELS.contains(name.left(1)) else "a", name]
	return ("Ang sagot ay %s." if fil else "The answer is %s.") % answer


## The answer as the child sees it: a choice's label, else its picture name.
static func answer_label(item: Dictionary) -> String:
	for c in item.get("choices", []):
		if str(c.id) == str(item.answer):
			return str(c.get("label", c.get("picture", c.id)))
	return str(item.get("answer", ""))


## The end of a word from its first vowel: "cat" -> "at", "cake" -> "ake".
static func rime(word: String) -> String:
	for i in word.length():
		if VOWELS.contains(word[i].to_lower()):
			return word.substr(i)
	return word


## First letter upper case only ("her brother Carlo" stays as it is after it).
static func cap(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


static func _fil(item: Dictionary) -> bool:
	return str(item.get("language", "")).begins_with("fil")


static func _keys(item: Dictionary) -> Array:
	return Array(str(item.answer).split("|"))


## The tiles' texts in the right order.
static func _ordered_texts(item: Dictionary) -> Array:
	var texts := {}
	for t in item.get("tiles", []):
		texts[QuestionBank.tile_key(t)] = str(t.text) if t is Dictionary else str(t)
	return _keys(item).map(func(k): return texts.get(k, k))


static func _drag_word(item: Dictionary) -> String:
	var word := ""
	for ch in item.get("pattern", []):
		word += answer_label(item) if ch == "_" else str(ch)
	return word


static func _gap_place(item: Dictionary, fil: bool) -> String:
	var pattern: Array = item.get("pattern", [])
	var i := pattern.find("_")
	if i == 0:
		return "una" if fil else "first"
	if i == pattern.size() - 1:
		return "huli" if fil else "last"
	return "gitna" if fil else "middle"


static func _after(text: String, marker: String) -> String:
	var i := text.find(marker)
	if i < 0:
		return ""
	return text.substr(i + marker.length()).get_slice(",", 0).get_slice(".", 0).strip_edges()


static func _between(text: String, a: String, b: String) -> String:
	var i := text.find(a)
	var j := text.find(b, i + 1)
	return text.substr(i + 1, j - i - 1) if i >= 0 and j > i else ""


static func _last_word(text: String) -> String:
	var words := text.strip_edges().trim_suffix(".").trim_suffix("?").split(" ")
	return words[words.size() - 1] if words.size() > 0 else ""
