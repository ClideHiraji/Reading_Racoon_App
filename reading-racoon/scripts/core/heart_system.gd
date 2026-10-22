class_name HeartSystem
extends RefCounted
## Hearts and the Heart Recovery ("Racoon's Rescue") trigger. FR-13, D-004
## (docs/knowledge/06-game-design.md), counting changed by D-021.
##
## Every wrong try costs a heart and every right answer gives one back, up to
## three. At zero hearts recovery starts; recovery can run at most twice per
## session, and a third trigger ends the session kindly.

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


## After the 3 recovery items. Returns true for a full (3/3) recovery.
## Either way the session continues with full hearts (D-004).
func finish_recovery(correct_count: int) -> bool:
	hearts = MAX_HEARTS
	return correct_count >= RECOVERY_ITEMS
