class_name WeatherJudges
extends RefCounted
## The judges of Fern's weather(day) and Hollis's where(person, hour) (tasks weather and hours): Concept/v0.4/05, sections
## 2.7 and 2.8. Each takes a whole stage's cases and results and gives one verdict per case ({ok, reason, ...details});
## TaskJudges.judge sends the name here.
##
##   WeatherJudges.weather_week(cases, results)   # every day is sun, rain or cloud, and each 7 days in a row has both
##   WeatherJudges.hours(cases, results)          # every answer is home, work or inn, and the wanted ones are right

## The length of a window of days that must hold a rain day and a sun day.
const WEEK := 7


## Every case's day must be sun, rain or cloud (Parts.WEATHERS), else "not-weather" (got). Then each run of 7 days in a
## row (days d–d+6, for every d whose seven days all have one of the three answers) needs a rain day and a sun day.
## The verdict for a window goes on its first day's case: "no-rain" or "no-sun" (name: "d–d+6", which reads the same in every language). Rain is looked for
## first, so a window with neither gives "no-rain". A window with a day that is not weather is not checked yet, so the
## "not-weather" verdict is the one the player sees first.
static func weather_week(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var answer_of := {}
	var case_of := {}
	for i in cases.size():
		var got: Variant = TaskJudges.value_of(results, i)
		var day := _day_of(cases[i], i)
		case_of[day] = i
		if got is String and String(got) in Parts.WEATHERS:
			answer_of[day] = String(got)
			out.append(TaskJudges.right())
		else:
			out.append({"ok": false, "reason": "not-weather", "got": got})
	if answer_of.is_empty():
		return out
	var days: Array = answer_of.keys()
	days.sort()
	var first: int = days[0]
	var last: int = days[days.size() - 1]
	for start in range(first, last - WEEK + 2):
		var week: Array = []
		for day in range(start, start + WEEK):
			week.append(answer_of.get(day, null))
		if week.has(null):
			continue
		var reason := ""
		if not "rain" in week:
			reason = "no-rain"
		elif not "sun" in week:
			reason = "no-sun"
		if reason != "":
			out[case_of[start]] = {
				"ok": false,
				"reason": reason,
				"name": "%d–%d" % [start, start + WEEK - 1],
			}
	return out


## Each case's answer must be a spot, "home", "work" or "inn", else "not-spot" (got). A case with `want` must give exactly
## it, else "wrong" (want, got). A case with no `want` (the hours 7 and 23) only has to be a spot.
static func hours(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		var case_data: Dictionary = cases[i] if cases[i] is Dictionary else {}
		var got: Variant = TaskJudges.value_of(results, i)
		if not (got is String and String(got) in Parts.SPOTS):
			out.append({"ok": false, "reason": "not-spot", "got": got})
		elif case_data.has("want") and not Tasks.same(case_data.want, got):
			out.append({"ok": false, "reason": "wrong", "want": case_data.want, "got": got})
		else:
			out.append(TaskJudges.right())
	return out


## The day a case asks about: its first argument when that is a whole number, else its position.
static func _day_of(case_data: Variant, position: int) -> int:
	var args: Variant = (case_data as Dictionary).get("args", []) if case_data is Dictionary else []
	if args is Array and not (args as Array).is_empty() and Tasks.is_whole((args as Array)[0]):
		return int((args as Array)[0])
	return position
