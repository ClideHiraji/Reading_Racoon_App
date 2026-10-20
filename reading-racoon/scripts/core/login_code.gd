class_name LoginCode
extends RefCounted
## Student login codes as the backend issues them (backend/app/Support/LoginCode.php):
## 8 characters from an alphabet without 0/O/1/I/L, shown as "K7PM-3QXA".
## Case, spaces and dashes don't matter (FR-01, D-010).

const ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const LENGTH := 8


## "k7pm 3qxa" -> "K7PM3QXA" (drops anything that can't be in a code).
static func normalize(text: String) -> String:
	var out := ""
	for ch in text.to_upper():
		if ALPHABET.contains(ch):
			out += ch
	return out


static func is_valid(text: String) -> bool:
	var n := normalize(text)
	return n.length() == LENGTH and n.length() == text.to_upper().replace("-", "").replace(" ", "").length()


## "K7PM3QXA" -> "K7PM-3QXA"
static func format(text: String) -> String:
	var n := normalize(text)
	return n if n.length() <= 4 else n.substr(0, 4) + "-" + n.substr(4)
