class_name MapJudges
extends RefCounted
## The judges of the map's map_colour(ground) and place_of(x, y, places), and the credits' credits(maker, parts) (tasks
## map and credits): Concept/v0.4/01 section 5 and 02 section 5. Each takes a whole stage's cases and results and gives
## one verdict per case ({ok, reason, ...details}); TaskJudges.judge sends the name here.
##
##   MapJudges.map_colours(cases, results)   # colours by ground: the same colour as grass is a verdict, not a crash
##   MapJudges.place_of(cases, results)      # "" (or nothing) is a cell in no place
##   MapJudges.credits(cases, results)       # the lines the credits roll, with the maker and the parts on them


## The colours of the map (map_colour): each ground's answer must be a colour name (Parts.colour_of, so "Blue" and
## "blue" are the same). Water, path and cobble must not be grass's colour, and a building must be neither grass's nor
## the path's. Each paved path material is checked against grass. Each verdict goes on the case that shows the clash:
## "not-colour" (name, got), "same-water",
## "same-path" and "same-building" (name, got). Every other ground is the player's taste.
static func map_colours(cases: Array, results: Array) -> Array[Dictionary]:
	var colours := {}
	for i in cases.size():
		colours[_ground_of(cases[i])] = Parts.colour_of(TaskJudges.value_of(results, i))
	var paths: Array[Variant] = []
	for kind: String in ["path", "brick_path", "stone_path", "wood_path", "cobble"]:
		if colours.has(kind):
			paths.append(colours[kind])
	var out: Array[Dictionary] = []
	for i in cases.size():
		var ground := _ground_of(cases[i])
		var answer: Variant = TaskJudges.value_of(results, i)
		var colour: Variant = colours[ground]
		var grass: Variant = colours.get("grass")
		if colour == null:
			out.append({"ok": false, "reason": "not-colour", "name": ground, "got": answer})
		elif ground == "water" and colour == grass:
			out.append({"ok": false, "reason": "same-water", "name": ground, "got": answer})
		elif ground in ["path", "brick_path", "stone_path", "wood_path", "cobble"] and colour == grass:
			out.append({"ok": false, "reason": "same-path", "name": ground, "got": answer})
		elif ground == "building" and (colour == grass or colour in paths):
			out.append({"ok": false, "reason": "same-building", "name": ground, "got": answer})
		else:
			out.append(TaskJudges.right())
	return out


## The cell's place (place_of), each case with a `want`: a name must be exactly it, and "" (or nothing) is a cell in no
## place. Reasons: "not-text" (got, when the answer is neither text nor nothing), "wrong" (want, got).
static func place_of(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		var case_data: Dictionary = cases[i] if cases[i] is Dictionary else {}
		var got: Variant = TaskJudges.value_of(results, i)
		if not case_data.has("want"):
			out.append(TaskJudges.right())
			continue
		var want: Variant = case_data.want
		if got != null and not (got is String):
			out.append({"ok": false, "reason": "not-text", "want": want, "got": got})
		elif want == "" and (got == null or got == ""):
			out.append(TaskJudges.right())
		elif got is String and got == want:
			out.append(TaskJudges.right())
		else:
			out.append({"ok": false, "reason": "wrong", "want": want, "got": got})
	return out


## The credits (credits(maker, parts)): the answer is a list of text lines, each case's maker and parts are its args.
## Checked in this order: "not-list" (got), "not-text" (index, got), "no-maker" (name: the maker's name), "missing-part"
## (name: the part), "too-long" (more than 40 lines, or a line over 60 characters). Names are matched without case.
static func credits(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		var args := _args_of(cases[i])
		var maker := String(args[0]) if args.size() > 0 else ""
		var parts: Array = args[1] if args.size() > 1 and args[1] is Array else []
		out.append(_credits_one(maker, parts, TaskJudges.value_of(results, i)))
	return out


static func _credits_one(maker: String, parts: Array, got: Variant) -> Dictionary:
	if not (got is Array):
		return {"ok": false, "reason": "not-list", "got": got}
	var lines: Array = got
	for index in lines.size():
		if not (lines[index] is String):
			return {"ok": false, "reason": "not-text", "index": index, "got": lines[index]}
	if not _has_line(lines, maker):
		return {"ok": false, "reason": "no-maker", "name": maker, "got": got}
	for part: Variant in parts:
		if not _has_line(lines, String(part)):
			return {"ok": false, "reason": "missing-part", "name": String(part), "got": got}
	if lines.size() > 40:
		return {"ok": false, "reason": "too-long", "got": got}
	for line: Variant in lines:
		if String(line).length() > 60:
			return {"ok": false, "reason": "too-long", "got": got}
	return TaskJudges.right()


## Whether some line holds `text` (without case, so "mina" is in "Made by Mina").
static func _has_line(lines: Array, text: String) -> bool:
	for line: Variant in lines:
		if String(line).to_lower().contains(text.to_lower()):
			return true
	return false


## The ground a case is about: its first argument.
static func _ground_of(case_data: Variant) -> String:
	var args := _args_of(case_data)
	return String(args[0]) if not args.is_empty() else ""


static func _args_of(case_data: Variant) -> Array:
	var args: Variant = (case_data as Dictionary).get("args", []) if case_data is Dictionary else []
	return args if args is Array else []
