class_name TaskJudges
extends RefCounted
## What decides whether a task's answers are right (Concept/v0.4/02, section 5). A judge sees a whole stage at once:
## its cases (content) and the run's results, one per case ({ok: true, value} or {ok: false, kind, message, line}),
## and gives one verdict per case, {ok, reason, ...details}. A case whose call failed is judged "error" by Tasks
## before the judge's verdict is used, so a judge may read `results[i].value` as the answer.
##
##   TaskJudges.judge("equals", cases, results)   # [{ok: true, reason: "right"}, {ok: false, reason: "wrong", ...}]
##
## The generic judges live here (equals, shortcut); each task's own live beside it in judges/<task>_judges.gd, and
## `judge` sends a name to its file. A judge the dispatch does not know fails every case with "unknown-judge".

const RIGHT := "right"
## Every judge `judge` knows, for the content check.
const NAMES: Array[String] = [
	Tasks.EQUALS, "shortcut", "menu_items", "options_rows", "volume_curve", "volume_clamp", "progress", "bag_add",
	"bag_remove", "next_track", "clock_text", "map_colours", "place_of", "credits",
	# Chapter 3 (Concept/v0.4/05).
	"glow_pattern", "drills", "forge_pure", "weather_week", "hours", "tidy_sorted",
]


static func judge(name: String, cases: Array, results: Array) -> Array[Dictionary]:
	match name:
		"", Tasks.EQUALS:
			return equals(cases, results)
		"shortcut":
			return shortcut(cases, results)
		"menu_items":
			return MenuJudges.menu_items(cases, results)
		"options_rows":
			return MenuJudges.options_rows(cases, results)
		"volume_curve":
			return VolumeJudges.volume_curve(cases, results)
		"volume_clamp":
			return VolumeJudges.volume_clamp(cases, results)
		"progress":
			return VolumeJudges.progress(cases, results)
		"bag_add":
			return BagJudges.bag_add(cases, results)
		"bag_remove":
			return BagJudges.bag_remove(cases, results)
		"next_track":
			return MusicJudges.next_track(cases, results)
		"clock_text":
			return MusicJudges.clock_text(cases, results)
		"map_colours":
			return MapJudges.map_colours(cases, results)
		"place_of":
			return MapJudges.place_of(cases, results)
		"credits":
			return MapJudges.credits(cases, results)
		"glow_pattern":
			return GlowJudges.glow_pattern(cases, results)
		"drills":
			return DrillsJudges.drills(cases, results)
		"forge_pure":
			return ForgeJudges.forge_pure(cases, results)
		"weather_week":
			return WeatherJudges.weather_week(cases, results)
		"hours":
			return WeatherJudges.hours(cases, results)
		"tidy_sorted":
			return TidyJudges.tidy_sorted(cases, results)
	var out: Array[Dictionary] = []
	for _i in cases.size():
		out.append({"ok": false, "reason": "unknown-judge", "name": name})
	return out


## The answer of result `i` (null when the call failed or is missing).
static func value_of(results: Array, i: int) -> Variant:
	if i >= results.size() or not results[i] is Dictionary:
		return null
	return (results[i] as Dictionary).get("value")


static func right() -> Dictionary:
	return {"ok": true, "reason": RIGHT}


## Every case failed with `reason`: what a judge not written yet gives (the content test then fails loudly).
static func not_written(cases: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for _i in cases.size():
		out.append({"ok": false, "reason": "not-written"})
	return out


# --- equals ----------------------------------------------------------------------------------------------------------


## Each case on its own: `any` (a list of answers that are all fine), else `want` compared with Tasks.same, else any
## answer will do. Reasons: "not-any" (got), "nothing" (want, got null), "wrong-type" (want, got), "wrong-length" (want,
## got: two lists of different lengths), "wrong-item" (index, want, got: the first item that differs), "wrong".
static func equals(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		out.append(equals_one(cases[i] if cases[i] is Dictionary else {}, value_of(results, i)))
	return out


static func equals_one(case_data: Dictionary, got: Variant) -> Dictionary:
	if case_data.has("any"):
		for fine: Variant in case_data.any:
			if Tasks.same(fine, got):
				return right()
		return {"ok": false, "reason": "not-any", "got": got, "want": (case_data.any as Array)[0] if not (case_data.any as Array).is_empty() else null}
	if not case_data.has("want"):
		return right()
	var want: Variant = case_data.want
	if Tasks.same(want, got):
		return right()
	if got == null and want != null:
		return {"ok": false, "reason": "nothing", "want": want, "got": got}
	if Tasks.kind_of(want) != Tasks.kind_of(got):
		return {"ok": false, "reason": "wrong-type", "want": want, "got": got}
	if want is Array and got is Array:
		var a: Array = want
		var b: Array = got
		if a.size() != b.size():
			return {"ok": false, "reason": "wrong-length", "want": want, "got": got, "want_size": a.size(), "got_size": b.size()}
		for index in a.size():
			if not Tasks.same(a[index], b[index]):
				return {"ok": false, "reason": "wrong-item", "index": index, "want": a[index], "got": b[index]}
	return {"ok": false, "reason": "wrong", "want": want, "got": got}


# --- shortcut ------------------------------------------------------------------------------------------------------


## shortcut(key): a case with `want` must give exactly it ("wrong", or "nothing"); any answer must be nothing ("" or
## None) or a panel the game knows (Parts.PANELS), else "unknown-panel" (name).
static func shortcut(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		var case_data: Dictionary = cases[i] if cases[i] is Dictionary else {}
		var got: Variant = value_of(results, i)
		var nothing: bool = got == null or (got is String and got == "")
		if not nothing and not (got is String and String(got) in Parts.PANELS):
			out.append({"ok": false, "reason": "unknown-panel", "name": str(got), "got": got})
			continue
		if case_data.has("want") and not Tasks.same(case_data.want, got):
			out.append({"ok": false, "reason": "nothing" if nothing else "wrong", "want": case_data.want, "got": got})
			continue
		out.append(right())
	return out
