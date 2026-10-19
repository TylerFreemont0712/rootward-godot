class_name MusicJudges
extends RefCounted
## The judges of the music box's next_track(index, count) and the clock's clock_text(minute) (tasks music and clock):
## Concept/v0.4/01 section 5 and 02 section 5. Each takes a whole stage's cases and results and gives one verdict per
## case ({ok, reason, ...details}); TaskJudges.judge sends the name here.
##
##   MusicJudges.next_track(cases, results)   # reasons: not-whole, no-wrap, wrong
##   MusicJudges.clock_text(cases, results)   # reasons: not-text, no-zero, wrong


## next_track(index, count): the answer must be a whole number ("not-whole", got). A wrong track on the last one (index
## == count - 1) is "no-wrap": the last track should go round to the first. Any other wrong track is "wrong" (want, got).
static func next_track(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		out.append(next_one(cases[i] if cases[i] is Dictionary else {}, TaskJudges.value_of(results, i)))
	return out


static func next_one(case_data: Dictionary, got: Variant) -> Dictionary:
	if not case_data.has("want"):
		return TaskJudges.right()
	var want: Variant = case_data.want
	if not Tasks.is_whole(got):
		return {"ok": false, "reason": "not-whole", "want": want, "got": got}
	if Tasks.same(want, got):
		return TaskJudges.right()
	var args: Array = case_data.get("args", [])
	var index := int(args[0]) if args.size() > 0 else 0
	var count := int(args[1]) if args.size() > 1 else 0
	var reason := "no-wrap" if index == count - 1 else "wrong"
	return {"ok": false, "reason": reason, "want": want, "got": got, "index": index, "count": count}


## clock_text(minute): the time as text with two digits for the minutes, "18:40". A one-digit hour may keep a leading
## zero ("01:05"). Reasons: "not-text" (got), "no-zero" (the time is right but its minutes have one digit: "1:5" for
## "1:05"), "wrong" (want, got).
static func clock_text(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		out.append(clock_one(cases[i] if cases[i] is Dictionary else {}, TaskJudges.value_of(results, i)))
	return out


static func clock_one(case_data: Dictionary, got: Variant) -> Dictionary:
	if not got is String:
		return {"ok": false, "reason": "not-text", "want": case_data.get("want", ""), "got": got}
	if not case_data.has("want"):
		return TaskJudges.right()
	var want := String(case_data.want)
	var text := String(got)
	if text == want or (_one_digit_hour(want) and text == "0" + want):
		return TaskJudges.right()
	if _same_time_without_zero(want, text):
		return {"ok": false, "reason": "no-zero", "want": want, "got": got}
	return {"ok": false, "reason": "wrong", "want": want, "got": got}


static func _one_digit_hour(time: String) -> bool:
	return time.split(":")[0].length() == 1


## The same hour and minutes, with the minutes written with one digit ("1:5" for "1:05"): only the zero is missing.
static func _same_time_without_zero(want: String, text: String) -> bool:
	var got_parts := text.split(":")
	var want_parts := want.split(":")
	if got_parts.size() != 2 or want_parts.size() != 2 or got_parts[1].length() != 1:
		return false
	return (
		got_parts[0].is_valid_int()
		and got_parts[1].is_valid_int()
		and int(got_parts[0]) == int(want_parts[0])
		and int(got_parts[1]) == int(want_parts[1])
	)
