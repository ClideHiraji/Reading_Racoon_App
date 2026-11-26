class_name HeartSystem
extends RefCounted
## Hearts and "Racoon's Rescue".
## A wrong try costs a heart, a right answer gives one back (max 3).
## At zero hearts the rescue starts. It can run twice per session;
## a third time ends the session kindly.

const MAX_HEARTS := 3
const MAX_RECOVERIES := 2
const RECOVERY_ITEMS := 3

enum Result { OK, RECOVERY, END_SESSION }

var hearts := MAX_HEARTS
var recoveries := 0


func on_answer(correct: bool) -> Result:
	if correct:
		hearts = mini(hearts + 1, MAX_HEARTS)
		return Result.OK
	hearts -= 1
	if hearts > 0:
		return Result.OK
	if recoveries >= MAX_RECOVERIES:
		return Result.END_SESSION
	recoveries += 1
	return Result.RECOVERY


## Called after the 3 rescue items. Returns true if all 3 were right.
## Either way the session goes on with full hearts.
func finish_recovery(correct_count: int) -> bool:
	hearts = MAX_HEARTS
	return correct_count >= RECOVERY_ITEMS
