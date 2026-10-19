class_name VolumeJudges
extends RefCounted
## The judges of the volume knob's volume(slider) (task volume: volume_curve in stage 1, volume_clamp in stage 2) and
## Pip's progress(done, total) (task progress): Concept/v0.4/01 sections 5.4 and 5.8, and 02 section 5. Each takes a
## whole stage's cases and results and gives one verdict per case ({ok, reason, ...details}); TaskJudges.judge sends
## the name here.
##
## Tasks.check judges each stage with that stage's own cases only, so volume_clamp's curve sees the notches 0 to 10
## among its own cases (none in stage 2). Stage 1's cases are judged by volume_curve, which still runs on every check.

## How close to the ends the answers for notch 0 and notch 10 must be (silent is within 0.01 of 0.0, full of 1.0).
const END_TOLERANCE := 0.01
## The notches of the Options page's slider.
const LOWEST := 0
const HIGHEST := 10


## Notches 0 to 10 only: each answer is a number from 0.0 to 1.0, 0 is silent, 10 is full, and a notch is never quieter
## than the one before it. Reasons: "not-number" (got), "silent-end" (notch 0), "full-end" (notch 10), "out" (below 0 or
## above 1; notch, got), "goes-down" (notch, got, was: the quieter notch gets it). Other notches are ignored.
static func volume_curve(cases: Array, results: Array) -> Array[Dictionary]:
	var out := _all_right(cases.size())
	_judge_curve(cases, results, out)
	return out


## volume_curve on the notches 0 to 10, plus: a notch below 0 must give 0.0 ("low-end", got) and a notch above 10 must
## give 1.0 ("high-end", got), within END_TOLERANCE. Any other answer that is not a number is "not-number".
static func volume_clamp(cases: Array, results: Array) -> Array[Dictionary]:
	var out := _all_right(cases.size())
	_judge_curve(cases, results, out)
	for i in cases.size():
		var notch: Variant = _notch_of(cases[i])
		if notch != null and (int(notch) < LOWEST or int(notch) > HIGHEST):
			out[i] = _past_the_end(int(notch), TaskJudges.value_of(results, i))
	return out


## progress(done, total): the percent done, a whole number. Rounding down or to the nearest are both fine, for every
## case. Reasons: "zero" (total 0 gave something other than 0; want 0, got), "fraction" (got between 0 and 1 when the
## wanted percent is above 1, like 0.5 for half), "not-whole" (got), "wrong" (want, got).
static func progress(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		var args := _args_of(cases[i])
		var got: Variant = TaskJudges.value_of(results, i)
		if args.size() != 2:
			out.append({"ok": false, "reason": "wrong", "got": got})
		else:
			out.append(_progress_one(args, got))
	return out


# --- the curve -----------------------------------------------------------------------------------------------------


## Each notch 0 to 10 on its own, then the notches that are quieter than the one before them. A case gets one verdict:
## the first that holds, so a notch that has one already keeps it.
static func _judge_curve(cases: Array, results: Array, out: Array[Dictionary]) -> void:
	var at := _notch_indexes(cases)
	for notch in range(LOWEST, HIGHEST + 1):
		if at.has(notch):
			var index: int = at[notch]
			out[index] = _own_verdict(notch, TaskJudges.value_of(results, index))
	for notch in range(LOWEST + 1, HIGHEST + 1):
		if not (at.has(notch) and at.has(notch - 1)):
			continue
		var index: int = at[notch]
		var now: Variant = TaskJudges.value_of(results, index)
		var was: Variant = TaskJudges.value_of(results, at[notch - 1])
		if not (Tasks.is_number(now) and Tasks.is_number(was)):
			continue
		var own_ok: bool = bool((out[index] as Dictionary).get("ok", false))
		if own_ok and float(now) < float(was) - Tasks.TOLERANCE:
			out[index] = {"ok": false, "reason": "goes-down", "notch": notch, "got": now, "was": was}


## The verdict for one notch's answer on its own, in the order the player is told: not a number, the ends, out of range.
static func _own_verdict(notch: int, got: Variant) -> Dictionary:
	if not Tasks.is_number(got):
		return {"ok": false, "reason": "not-number", "notch": notch, "got": got}
	var loudness := float(got)
	if notch == LOWEST and absf(loudness) > END_TOLERANCE:
		return {"ok": false, "reason": "silent-end", "notch": notch, "got": got}
	if notch == HIGHEST and absf(loudness - 1.0) > END_TOLERANCE:
		return {"ok": false, "reason": "full-end", "notch": notch, "got": got}
	if loudness < -Tasks.TOLERANCE or loudness > 1.0 + Tasks.TOLERANCE:
		return {"ok": false, "reason": "out", "notch": notch, "got": got}
	return TaskJudges.right()


## A notch past the ends (below 0 or above 10): not a number, or not the end it should be.
static func _past_the_end(notch: int, got: Variant) -> Dictionary:
	if not Tasks.is_number(got):
		return {"ok": false, "reason": "not-number", "notch": notch, "got": got}
	var loudness := float(got)
	if notch < LOWEST and absf(loudness) > END_TOLERANCE:
		return {"ok": false, "reason": "low-end", "notch": notch, "got": got}
	if notch > HIGHEST and absf(loudness - 1.0) > END_TOLERANCE:
		return {"ok": false, "reason": "high-end", "notch": notch, "got": got}
	return TaskJudges.right()


## The index of each notch 0 to 10 among the cases.
static func _notch_indexes(cases: Array) -> Dictionary:
	var at := {}
	for i in cases.size():
		var notch: Variant = _notch_of(cases[i])
		if notch != null and int(notch) >= LOWEST and int(notch) <= HIGHEST:
			at[int(notch)] = i
	return at


## The notch a case asks about (its first argument, a whole number), or null when it has none.
static func _notch_of(case_data: Variant) -> Variant:
	var args := _args_of(case_data)
	if args.is_empty() or not Tasks.is_whole(args[0]):
		return null
	return int(args[0])


# --- progress ------------------------------------------------------------------------------------------------------


## One case: done and total from its arguments, the answer checked against the floor and the nearest whole percent.
static func _progress_one(args: Array, got: Variant) -> Dictionary:
	var done := float(args[0])
	var total := float(args[1])
	if total == 0.0:
		if Tasks.same(0, got):
			return TaskJudges.right()
		return {"ok": false, "reason": "zero", "want": 0, "got": got}
	var exact := done * 100.0 / total
	if Tasks.is_number(got) and not Tasks.is_whole(got):
		var part := float(got)
		if part > 0.0 and part < 1.0 and exact > 1.0:
			return {"ok": false, "reason": "fraction", "got": got}
		return {"ok": false, "reason": "not-whole", "got": got}
	if Tasks.same(floorf(exact), got) or Tasks.same(roundf(exact), got):
		return TaskJudges.right()
	return {"ok": false, "reason": "wrong", "want": roundf(exact), "got": got}


# --- helpers -------------------------------------------------------------------------------------------------------


static func _all_right(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for _i in count:
		out.append(TaskJudges.right())
	return out


## A case's argument list, or [] when it has none.
static func _args_of(case_data: Variant) -> Array:
	var args: Variant = (case_data as Dictionary).get("args", []) if case_data is Dictionary else []
	return args if args is Array else []
