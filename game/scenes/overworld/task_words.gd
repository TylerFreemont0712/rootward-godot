class_name TaskWords
extends RefCounted
## What Hotaru says about a task's check (Concept/v0.4/02, section 4), in the game's own words for the generic reasons.
## Tasks.advice decides (a reason and the case it is about, and the task's own words when it has some); this says the
## rest, short and kind, since a child reads it. Every string is a literal Text.t, and the details are filled in
## afterwards with Tasks.fill ({say}, {got}, {want}, {line}, {kind}, {message}, {index}, {name}, {arg0}).
##
##   TaskWords.advice(task, 0, Tasks.advice(task, 0, checked, "python"), "python")


## What to say for `advised` ({reason, case, text}, from Tasks.advice) at `stage`: the task's own words when it wrote
## some, else the game's for the reason.
static func advice(task: Dictionary, stage: int, advised: Dictionary, language: String) -> String:
	var details: Dictionary = (advised.get("case", {}) as Dictionary).duplicate()
	# A case's description is words, so it is the player's language too; the values ({got}, {want}) are code.
	if details.has("say"):
		details["say"] = Text.t(String(details.say))
	# The task's own words: translated first, then filled (the translation is keyed by the words with their slots).
	var template := String(advised.get("template", ""))
	if template != "":
		var own_details := details.duplicate()
		return Tasks.fill(Text.t(template), own_details, language)
	var own := String(advised.get("text", ""))
	if own != "":
		return own
	# The name is the function as the player writes it, with what it gets: shortcut(key).
	details["name"] = Tasks.signature(task, int(details.get("stage", stage)), language)
	var reason := String(advised.get("reason", ""))
	return Tasks.fill(_words(reason, details), details, language)


## The words for a reason, with its {placeholders} still in them.
static func _words(reason: String, details: Dictionary) -> String:
	match reason:
		"passed":
			return Text.t("Every case works! Press Done and the game will use your code.")
		"no-function":
			return Text.t("I can't find your function {name}. Is its name spelled the same as in the goal?")
		"broken":
			if int(details.get("line", 0)) > 0:
				return Text.t("Your code can't run yet. Line {line} is where it got stuck: look there first.")
			return Text.t("Your code can't run yet. Look for a missing bracket, quote or colon.")
		"timeout":
			return Text.t("Your code is going round and round! Does the loop ever end?")
		"failed":
			return Text.t("Hmm, the check didn't run. Let's try again.")
		"error":
			if int(details.get("line", 0)) > 0:
				return Text.t("Trying {say}, your code tripped on line {line}. The red line shows where.")
			return Text.t("Trying {say}, your code tripped. Read the error beside it.")
		"nothing":
			return Text.t("For {say}, your function gave back nothing. Is there a return, and does it run?")
		"wrong-type":
			return Text.t("For {say}, your function gave back {got}, but the answer should be a different kind of thing, like {want}.")
		"wrong-length":
			return Text.t("For {say}, the list has the wrong number of things. It gave back {got}, and it should be {want}.")
		"wrong-item":
			return Text.t("For {say}, almost! The item at place {index} is {got}, and it should be {want}. Counting starts at 0.")
		"not-any":
			return Text.t("For {say}, {got} isn't one of the answers I was hoping for. Try another way.")
		"wrong":
			return Text.t("For {say}, your function gave back {got}, but it should give back {want}.")
		"edge":
			return Text.t("It works for the usual ones, but {say} is a tricky one! What happens right at the edge?")
	return Text.t("Not quite yet. Look at the case that missed, {say}, and try again.")


## The line under the Try it button while the sandbox runs.
static func trying() -> String:
	return Text.t("Hotaru is trying it…")


## The status line after a check: how many cases worked out of how many.
static func tally(worked: int, total: int) -> String:
	if total > 0 and worked == total:
		return Text.t("It works!")
	return Text.f("%d of %d cases work.", [worked, total])


## One muted line before the first check.
static func waiting() -> String:
	return Text.t("Press Try it. I'll call your function on each of these and show what it gives back.")


## The small heading over the cases of the stages before this one.
static func still_works(all_ok: bool) -> String:
	return Text.t("Still works:") if all_ok else Text.t("These worked before. Do they still?")
