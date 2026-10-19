class_name LessonWords
extends RefCounted
## The words of Lanternroot's lessons 2 and 3 (ADR-0061): the titles, Hotaru's hints and advice, and each case's
## verdict. Lessons decides (reason and advice codes); this file only says them, short and kind, since a child reads
## them. Every string is a literal Text.t or Text.f call, so the locale check can find it.


static func title(id: String) -> String:
	return Text.t("Light the lane") if id == Lessons.LAMPS else Text.t("Remember me")


## Hotaru's first words when a lesson opens: what to make, for a Builder (blocks) or a Scribe (typing).
static func intro(id: String, scribe: bool) -> String:
	if id == Lessons.LAMPS:
		if scribe:
			return Text.t("Write light_all. It gets a list of lamps. Light every one, however many there are!")
		return Text.t("Build light_all from the blocks. Every lamp should end up lit, however many there are!")
	if scribe:
		return Text.t("Write save. It gets you, the player. Give back what the town should remember about you.")
	return Text.t("Tick what the town should remember about you. Your save gives those back.")


## What Hotaru says once the lesson's check has run: `advice` is Lessons.advice's code.
static func advice(id: String, code: String, language: String) -> String:
	var python := language != Lessons.JAVASCRIPT
	match code:
		"passed":
			if id == Lessons.LAMPS:
				return Text.t("Every lamp, in every lane! Press Done and watch the real lane wake up.")
			return Text.t("You did it! Now the town can remember you. Press Done, then save from the menu (Esc).")
		"forgot-map":
			return Text.t("It kept x and y, but not which map! Home has an x 2, y 3, and so does the town.")
		"forgot":
			return Text.t("Your save forgot something. The town needs x, y and map to find you.")
		"wrong":
			return Text.t("A value got mixed up. Check that each name keeps its own value.")
		"no-return":
			return Text.t("save has to give something back. That's what return does!")
		"not-dict":
			if python:
				return Text.t("save should give back a dictionary: names, each with a value.")
			return Text.t("save should give back an object: names, each with a value.")
		"empty":
			return Text.t("An empty save! Tomorrow the town wouldn't know you at all.")
		"first-only":
			return Text.t("Only the first lamp woke up! A loop can visit every lamp, one by one.")
		"all-dark":
			return Text.t("The lamps are all still dark. What should happen to each one?")
		"some-dark":
			return Text.t("Some lamps are still dark. Does every lamp get lit?")
		"empty-lane":
			return Text.t("An empty lane has no first lamp to light! A loop just does nothing there.")
		"lost":
			return Text.t("Lamps went missing! Light them, but don't take any away.")
		"changed":
			return Text.t("The lamps got shuffled. Light each one where it stands.")
		"not-true":
			if python:
				return Text.t("So close! lit has to be True, exactly.")
			return Text.t("So close! lit has to be true, exactly.")
		"not-list":
			return Text.t("light_all should light the lamps it gets, not make something new.")
		"error":
			return Text.t("Your code tripped. The red line shows where.")
		"broken":
			return Text.t("Your code can't run yet. The red line shows where to look.")
		"missing":
			return Text.t("Keep the first line as it was. The town calls that function by its name.")
		"timeout":
			return Text.t("Your code is going round and round! Does the loop ever end?")
	return Text.t("Hmm, the check didn't run. Let's try again.")


## The name of a case: where the player stood, or how many lamps the lane had.
static func case_label(id: String, given: Variant) -> String:
	if id == Lessons.LAMPS:
		var count := (given as Array).size() if given is Array else 0
		if count == 0:
			return Text.t("No lamps")
		if count == 1:
			return Text.t("One lamp")
		return Text.f("%d lamps", [count])
	var player: Dictionary = given if given is Dictionary else {}
	var at := [int(player.get("x", 0)), int(player.get("y", 0))]
	if String(player.get("map", "")) == "home":
		return Text.f("At home, x %d y %d", at)
	return Text.f("In town, x %d y %d", at)


## One case's verdict, from Lessons.judge_save or judge_lane.
static func verdict(judged: Dictionary, language: String) -> String:
	var python := language != Lessons.JAVASCRIPT
	var got := String(judged.get("got", ""))
	match String(judged.get("reason", "")):
		"kept":
			return Text.f("Kept %s. The town can find you!", [", ".join(judged.get("kept", []))])
		"lit":
			var total := int(judged.get("total", 0))
			if total == 0:
				return Text.t("Nothing to light, and nothing broke.")
			return Text.t("Lit!") if total == 1 else Text.f("All %d lit!", [total])
		"error":
			return error(judged)
		"nothing":
			return Text.t("Gave back nothing. Is there a return?")
		"not-dict":
			return (
				Text.f("Gave back %s, not a dictionary.", [got])
				if python
				else Text.f("Gave back %s, not an object.", [got])
			)
		"kept-nothing":
			return Text.t("Gave back an empty save.")
		"forgot":
			return Text.f("Forgot %s.", [", ".join(judged.get("missing", []))])
		"wrong":
			return Text.f("Kept %s as %s, but it was %s.", [judged.field, got, judged.want])
		"not-list":
			return Text.f("Gave back %s, not the lamps.", [got])
		"count":
			return Text.f("%d lamps went in, %d came out.", [int(judged.want), int(judged.got)])
		"changed":
			return Text.t("The lamps changed places.")
		"not-true":
			return Text.f("lit is %s, not True.", [got]) if python else Text.f("lit is %s, not true.", [got])
		"dark":
			return Text.f("%d of %d still dark.", [int(judged.dark), int(judged.total)])
	return Text.t("Something went wrong.")


## An error with its line, as the run said it ("Line 2: IndexError: list index out of range").
static func error(found: Dictionary) -> String:
	var said := String(found.get("message", ""))
	var kind := String(found.get("kind", ""))
	if kind != "" and kind != "missing":
		said = "%s: %s" % [kind, said]
	var line := int(found.get("line", 0))
	return Text.f("Line %d: %s", [line, said]) if line > 0 else said


## A run that never reached the cases, for the status line.
static func problem(found: Dictionary, signature: String) -> String:
	match String(found.get("reason", "")):
		"broken":
			if String(found.get("kind", "")) == "missing":
				return Text.f("The town looks for %s and can't find it.", [signature])
			return Text.f("Can't run yet. %s", [error(found)])
		"timeout":
			return Text.t("It took too long. Is there a loop that never ends?")
	return Text.f("The check couldn't run: %s", [String(found.get("message", ""))])


## The status line after a check: everything passed, or how many cases worked.
static func tally(passed: int, total: int) -> String:
	if passed == total:
		return Text.t("Passed! Every case worked.")
	return Text.f("%d of %d worked.", [passed, total])


## Before the first check: what Try it will do.
static func waiting(id: String) -> String:
	if id == Lessons.LAMPS:
		return Text.t("Try it on three lanes: no lamps, one lamp, five lamps.")
	return Text.t("Try it on three players: one at home, two in town.")


## What a field of the player is, beside its tick box.
static func field(name: String) -> String:
	match name:
		"x":
			return Text.t("across")
		"y":
			return Text.t("down")
		"map":
			return Text.t("which place")
		"facing":
			return Text.t("which way you face")
		"name":
			return Text.t("your name")
	return name


## The lamp blocks, as they read.
static func lamp_block(id: String, language: String) -> String:
	match id:
		"first":
			return Text.t("Light the first lamp")
		"loop":
			return Text.t("For each lamp in the lane:")
		"inside":
			return Text.t("Set its lit to True") if language != Lessons.JAVASCRIPT else Text.t("Set its lit to true")
	return id


## What the menu's Save says when it worked: the fields the player's save kept.
static func saved(kept: Dictionary) -> String:
	return Text.f("Saved! Your save kept %s.", [", ".join(Lessons.kept_fields(kept))])


## Hotaru, kindly, when Continue could not use what the save kept (Lessons.restore's note).
static func restore_note(note: String) -> String:
	match note:
		"no-memory":
			return Text.t("Good morning! We never pressed Save, so the town forgot where we were. We woke up at home.")
		"forgot-map":
			return Text.t(
				"Good morning! Your save didn't keep the map, so the town couldn't find us. We woke up at home."
			)
		"unknown-map":
			return Text.t("Good morning! Your save named a place the town doesn't know, so we woke up at home.")
		"forgot-place":
			return Text.t("Good morning! Your save didn't keep x and y, so we woke up at home.")
		"outside":
			return Text.t("Good morning! Your save put us off the edge of the map, so we woke up at home.")
		"blocked":
			return Text.t("Good morning! Your save put us inside something solid, so we woke up at home.")
	return ""
