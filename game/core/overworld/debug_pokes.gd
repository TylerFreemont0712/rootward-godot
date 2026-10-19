class_name DebugPokes
extends RefCounted
## The developer debug panel's pokes (Lanternroot, ADR-0061): change the town's flags to try a quest step without
## playing up to it. Pure: each poke takes the quests and the flags and returns new flags; nothing passed in is changed.
## Quests.holds decides what holds, so a poke always agrees with what the quest log shows.
##
##   DebugPokes.complete_step(quests, "hello", 1, flags)   # step 1 of "hello", and the steps before it, done
##   DebugPokes.reopen_step(quests, "hello", 1, flags)     # step 1 of "hello" not done again (later steps with it)
##   DebugPokes.jump_to(quests, "lamps", flags)            # every quest before "lamps" done, "lamps" not started
##   DebugPokes.flag_changes(before, after)                # {set: [...], cleared: [...]}, for the log
##   DebugPokes.step_changes(quests, before, after)        # the steps a change of flags made done or undone
##
## Making a condition hold: {flag} sets the flag, {not} erases the flag, {all} makes each part hold, and {count} adds
## `<prefix>debug-N` flags. Making it fail: {flag} erases, {not} sets the flag, {all} fails its first part that holds,
## and {count} takes flags away from its prefix (the debug ones first).


## The flags with a step's condition holding, and every step before it too, so the steps count in order. A step the
## quest does not have changes nothing.
static func complete_step(quests: Dictionary, quest_id: String, step: int, flags: Dictionary) -> Dictionary:
	var out := flags.duplicate()
	var steps := _steps(quests, quest_id)
	if step < 0 or step >= steps.size():
		return out
	for i: int in range(step + 1):
		out = _make_hold(_done(steps[i]), out)
	return out


## The flags with a step's condition no longer holding, so that step and every later one count as not done.
## A step the quest does not have changes nothing.
static func reopen_step(quests: Dictionary, quest_id: String, step: int, flags: Dictionary) -> Dictionary:
	var out := flags.duplicate()
	var steps := _steps(quests, quest_id)
	if step < 0 or step >= steps.size():
		return out
	return _make_fail(_done(steps[step]), out)


## The flags as if every quest before `quest_id` (in quest order) were done, and `quest_id` itself not started: its
## first step is made not done. Quests after it are left alone. An unknown quest changes nothing.
static func jump_to(quests: Dictionary, quest_id: String, flags: Dictionary) -> Dictionary:
	var out := flags.duplicate()
	if not quests.has(quest_id):
		return out
	for id: String in Quests.ordered(quests):
		if id == quest_id:
			break
		for step: Dictionary in _steps(quests, id):
			out = _make_hold(_done(step), out)
	var first := _steps(quests, quest_id)
	if not first.is_empty():
		out = _make_fail(_done(first[0]), out)
	return out


## The flags with `flag` set to true.
static func set_flag(flags: Dictionary, flag: String) -> Dictionary:
	var out := flags.duplicate()
	out[flag] = true
	return out


## The flags with `flag` taken away, so it reads as not set.
static func clear_flag(flags: Dictionary, flag: String) -> Dictionary:
	var out := flags.duplicate()
	out.erase(flag)
	return out


## What a change of flags set and cleared: {set: [names], cleared: [names]}, both sorted. A flag counts as set when it
## is true; a flag that is false or missing counts as not set.
static func flag_changes(before: Dictionary, after: Dictionary) -> Dictionary:
	var names: Array[String] = []
	for flag: String in before:
		names.append(flag)
	for flag: String in after:
		if not before.has(flag):
			names.append(flag)
	var now_set: Array[String] = []
	var cleared: Array[String] = []
	for flag: String in names:
		var was := bool(before.get(flag, false))
		var now := bool(after.get(flag, false))
		if now and not was:
			now_set.append(flag)
		elif was and not now:
			cleared.append(flag)
	now_set.sort()
	cleared.sort()
	return {"set": now_set, "cleared": cleared}


## The steps whose done-ness a change of flags changed, in quest order. Each is {quest, title, step, text, done}, where
## done is what the step is now. Steps are counted with Quests.steps_done, so a step below the count is done.
static func step_changes(quests: Dictionary, before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in Quests.ordered(quests):
		var quest: Dictionary = quests[id]
		var was := Quests.steps_done(quest, before)
		var now := Quests.steps_done(quest, after)
		var steps: Array = quest.get("steps", [])
		for i: int in range(mini(was, now), maxi(was, now)):
			var step: Dictionary = steps[i]
			out.append(
				{
					"quest": id,
					"title": String(quest.get("title", "")),
					"step": i,
					"text": String(step.get("text", "")),
					"done": now > was,
				}
			)
	return out


## The steps of a quest as dictionaries, in order. A quest that is not there has none.
static func _steps(quests: Dictionary, quest_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var quest: Dictionary = quests.get(quest_id, {})
	for step: Dictionary in quest.get("steps", []):
		out.append(step)
	return out


## A step's done condition; a step without one is always done, so poking it changes nothing.
static func _done(step: Dictionary) -> Dictionary:
	return step.get("done", {})


## The flags with a condition holding. A condition that holds already is left alone.
static func _make_hold(condition: Dictionary, flags: Dictionary) -> Dictionary:
	var out := flags.duplicate()
	if Quests.holds(condition, out):
		return out
	if condition.has("count"):
		out = _count_up(String(condition.count), int(condition.get("at_least", 1)), out)
	if condition.has("flag"):
		out[String(condition.flag)] = true
	if condition.has("not"):
		var negated: Variant = condition.not
		if negated is Dictionary:
			out = _make_fail(negated as Dictionary, out)
		else:
			out.erase(String(negated))
	for part: Dictionary in condition.get("all", []):
		out = _make_hold(part, out)
	return out


## The flags with a condition failing. A condition that fails already is left alone. The first part that does the
## failing is changed and the rest are not: one part that does not hold is enough to fail an {all}.
static func _make_fail(condition: Dictionary, flags: Dictionary) -> Dictionary:
	var out := flags.duplicate()
	if not Quests.holds(condition, out):
		return out
	if condition.has("count"):
		out = _count_down(String(condition.count), int(condition.get("at_least", 1)), out)
		if not Quests.holds(condition, out):
			return out
	if condition.has("flag"):
		out.erase(String(condition.flag))
		return out
	if condition.has("not"):
		var negated: Variant = condition.not
		if negated is Dictionary:
			out = _make_hold(negated as Dictionary, out)
		else:
			out[String(negated)] = true
		return out
	for part: Dictionary in condition.get("all", []):
		if Quests.holds(part, out):
			return _make_fail(part, out)
	return out


## Adds `<prefix>debug-N` flags, under names the flags do not have yet, until the prefix counts `target`.
static func _count_up(prefix: String, target: int, flags: Dictionary) -> Dictionary:
	var out := flags.duplicate()
	var number := 1
	while Quests.counted(prefix, out) < target:
		var added := "%sdebug-%d" % [prefix, number]
		if not out.has(added):
			out[added] = true
		number += 1
	return out


## Takes the prefix's set flags away until it counts below `target`: the debug flags first, then the others, last name
## first.
static func _count_down(prefix: String, target: int, flags: Dictionary) -> Dictionary:
	var out := flags.duplicate()
	var debug: Array[String] = []
	var others: Array[String] = []
	for flag: String in out:
		if flag.begins_with(prefix) and bool(out[flag]):
			if flag.begins_with(prefix + "debug-"):
				debug.append(flag)
			else:
				others.append(flag)
	debug.sort()
	others.sort()
	debug.reverse()
	others.reverse()
	var taken: Array[String] = []
	taken.append_array(debug)
	taken.append_array(others)
	for flag: String in taken:
		if Quests.counted(prefix, out) < target:
			break
		out.erase(flag)
	return out
