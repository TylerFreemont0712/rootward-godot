class_name ForgeJudges
extends RefCounted
## The judge of Brannoc's forge(materials) (task forge, Concept/v0.4/05, section 2.5): forge_pure. It takes a whole
## stage's cases and results and gives one verdict per case ({ok, reason, ...details}); TaskJudges.judge sends the name
## here. The stage sets "args_after", so each result also carries the arguments as the function left them.


## The answer first, as equals judges it ("nothing", "wrong-type", "wrong"). Then the list it was given must be as it was
## ("changed-input": the list as it was given is {arg0} in the advice, and got is the answer). A case whose answer is
## wrong is told about the answer, not the list. "not-checked" when the run did not say what the arguments were left as:
## the stage asks for it, so that is a fault of the harness, not of the player's code.
static func forge_pure(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		var case_data: Dictionary = cases[i] if cases[i] is Dictionary else {}
		var got: Variant = TaskJudges.value_of(results, i)
		var verdict := TaskJudges.equals_one(case_data, got)
		if bool(verdict.get("ok", false)):
			verdict = _left_as_given(case_data, results, i, got)
		out.append(verdict)
	return out


## The list the function was given is still the one the case gave it: its first argument, as it was before the call and
## as the function left it, must be the same. An empty argument list has nothing to compare, so it is the same too.
static func _left_as_given(case_data: Dictionary, results: Array, index: int, got: Variant) -> Dictionary:
	var after: Variant = _args_after(results, index)
	if not after is Array:
		return {"ok": false, "reason": "not-checked", "got": got}
	var before := _args_of(case_data)
	var was: Variant = before[0] if not before.is_empty() else null
	var now: Variant = (after as Array)[0] if not (after as Array).is_empty() else null
	if not Tasks.same(was, now):
		return {"ok": false, "reason": "changed-input", "got": got, "want": case_data.get("want"), "args": before}
	return TaskJudges.right()


## The arguments of result `index` as the function left them (null when the run did not say).
static func _args_after(results: Array, index: int) -> Variant:
	if index >= results.size() or not results[index] is Dictionary:
		return null
	return (results[index] as Dictionary).get("args_after")


## The arguments a case calls the function with (an empty list when it has none).
static func _args_of(case_data: Dictionary) -> Array:
	return case_data.get("args", []) if case_data.get("args") is Array else []
