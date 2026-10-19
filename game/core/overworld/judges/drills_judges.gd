class_name DrillsJudges
extends RefCounted
## The judges of Brisk's drills (task drills, Concept/v0.4/05, section 2.3). The player's drills_double(), drills_total()
## and drills_first() each give a list of drills, [input, expected]. A stage's one case names its function ("double",
## "total" or "first"), and this judge holds Brisk's right function and his buggy one. A drill's expected must be what the
## right function gives for its input. A drill catches the bug when Brisk's buggy function gives something else for that
## input, or crashes. Takes a whole stage's cases and results and gives one verdict per case ({ok, reason, ...details});
## TaskJudges.judge sends the name here.

## A list of drills holds from MIN_DRILLS to MAX_DRILLS drills.
const MIN_DRILLS := 1
const MAX_DRILLS := 10
## The functions a case may name.
const FUNCTIONS: Array[String] = ["double", "total", "first"]


static func drills(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		var case_data: Dictionary = cases[i] if cases[i] is Dictionary else {}
		out.append(judge_one(String(case_data.get("function", "")), TaskJudges.value_of(results, i)))
	return out


## One stage's answer, judged. Reasons, in the order checked: "not-list" (got), "count" (got: how many drills),
## "not-drill" (index, got: a drill that is not a list of two, or whose input the function does not take), "wrong-expect"
## (index, args: the drill's input, want: the right answer, got: the expected the player wrote), and "no-catch" (none of
## the drills gives Brisk's buggy answer something different). `which` is "double", "total" or "first".
static func judge_one(which: String, answer: Variant) -> Dictionary:
	if not which in FUNCTIONS:
		return {"ok": false, "reason": "unknown-function", "name": which}
	if not answer is Array:
		return {"ok": false, "reason": "not-list", "name": which, "got": answer}
	var list: Array = answer
	if list.size() < MIN_DRILLS or list.size() > MAX_DRILLS:
		return {"ok": false, "reason": "count", "name": which, "got": list.size()}
	for index in list.size():
		if not _is_drill(which, list[index]):
			return {"ok": false, "reason": "not-drill", "name": which, "index": index, "got": list[index]}
	for index in list.size():
		var drill: Array = list[index]
		var right := _brisk(which, drill[0], false)
		if not Tasks.same(drill[1], right["value"]):
			return {
				"ok": false,
				"reason": "wrong-expect",
				"name": which,
				"index": index,
				"args": [drill[0]],
				"want": right["value"],
				"got": drill[1],
			}
	for index in list.size():
		var drill: Array = list[index]
		var bugged := _brisk(which, drill[0], true)
		if bool(bugged["crashed"]) or not Tasks.same(drill[1], bugged["value"]):
			return TaskJudges.right()
	return {"ok": false, "reason": "no-catch", "name": which}


## A drill is a list of two: an input the function takes, then an expected answer. Whether the answer is right is judged
## after this.
static func _is_drill(which: String, drill: Variant) -> bool:
	if not drill is Array or (drill as Array).size() != 2:
		return false
	var given: Variant = (drill as Array)[0]
	match which:
		"double":
			return Tasks.is_whole(given)
		"total":
			if not given is Array:
				return false
			for item: Variant in given:
				if not Tasks.is_number(item):
					return false
			return true
		"first":
			return given is Array
	return false


## What Brisk's function gives for `given`: the right one, or his buggy one (`buggy`). His buggy first crashes on an empty
## list, which is {crashed: true}: no expected answer equals that, because it is not an answer at all.
static func _brisk(which: String, given: Variant, buggy: bool) -> Dictionary:
	match which:
		"double":
			var number := float(given)
			var doubled := number + 2.0 if buggy else number * 2.0
			return {"crashed": false, "value": doubled}
		"total":
			var numbers: Array = given
			# His buggy total forgets the last number of the list.
			var used := maxi(numbers.size() - 1, 0) if buggy else numbers.size()
			var sum := 0.0
			for index in used:
				sum += float(numbers[index])
			return {"crashed": false, "value": sum}
		"first":
			var items: Array = given
			if items.is_empty():
				return {"crashed": buggy, "value": null}
			return {"crashed": false, "value": items[0]}
	return {"crashed": true, "value": null}
