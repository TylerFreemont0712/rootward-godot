class_name CosmeticRules
extends RefCounted
## The player's look on their moves and spells (ADR-0037), resolved against the catalogue (content/cosmetics.jsonc):
## a loadout is {slot: option id}, saved as plain strings, and anything unknown or missing reads as the slot's
## default (its first option), so an old save, a removed option or a hand-edited file never breaks a fight.
##
##   var loadout := CosmeticRules.sanitize(saved, catalog)
##   var circle := CosmeticRules.option(catalog, "circle", loadout.circle)        # {id, name, note, style}
##   var clip := CosmeticRules.clip(catalog, loadout, "cast_heavy", hero_clips)  # the clip, or the skin's own

const SLOTS: Array[String] = ["idle", "cast_light", "cast_heavy", "circle", "bolt", "impact"]
## The slots that are moves (a clip of the shared move library), and the clip a skin plays when it cannot play the
## chosen one: a drawn skin or a model with its own clips answers with its own.
const NATIVE := {"idle": "idle-breathe", "cast_light": "cast-light", "cast_heavy": "cast-heavy"}
const CIRCLE_STYLES: Array[String] = [
	"codex", "rootglass", "clockwork", "constellation", "script-loom", "ring-bloom", "orrery"
]
## The styles with a renderer of their own, standing on the circle's centre (ADR-0043, and the orrery).
const CENTRED_STYLES: Array[String] = ["script-loom", "ring-bloom", "orrery"]
const BOLT_PATHS: Array[String] = ["arc", "straight", "spiral"]
## The renderers a bolt or an impact may name in place of a sheet (docs/LEGENDARY_LOOKS.md): the game draws that look.
const BOLT_DRAWS: Array[String] = ["constellation"]
const IMPACT_DRAWS: Array[String] = ["black-hole"]
## What each slot's options must carry besides an id, a name and a note, unless the game draws the look (is_drawn).
const FIELDS := {
	"idle": ["clip"],
	"cast_light": ["clip"],
	"cast_heavy": ["clip"],
	"circle": ["style"],
	"bolt": ["sprite", "strong", "path"],
	"impact": ["sprite"],
}


## Every slot's default option id.
static func defaults(catalog: Dictionary) -> Dictionary:
	var chosen := {}
	for slot in SLOTS:
		var options: Array = catalog.get(slot, [])
		chosen[slot] = String(options[0].get("id", "")) if not options.is_empty() else ""
	return chosen


## A loadout with exactly the known slots, each a known option id (the default where it was not).
static func sanitize(loadout: Variant, catalog: Dictionary) -> Dictionary:
	var clean := defaults(catalog)
	if not loadout is Dictionary:
		return clean
	for slot in SLOTS:
		var wanted: Variant = (loadout as Dictionary).get(slot)
		if wanted is String and not find(catalog, slot, wanted).is_empty():
			clean[slot] = wanted
	# Script Loom and Shard Weave used to be worn as moves (ADR-0040 to 0042). They are circles now (ADR-0044): a save
	# that wore the loom as a move keeps its look as the circle, unless a circle of the new kind was chosen.
	var old: Array = [(loadout as Dictionary).get("cast_light"), (loadout as Dictionary).get("cast_heavy")]
	if "script-loom" in old and not String(clean.circle) in CENTRED_STYLES:
		clean.circle = "script-loom"
	return clean


## The option `id` of `slot`, or {} when there is none.
static func find(catalog: Dictionary, slot: String, id: String) -> Dictionary:
	for entry: Variant in catalog.get(slot, []):
		if entry is Dictionary and String((entry as Dictionary).get("id", "")) == id:
			return entry
	return {}


## The option `id` of `slot`, or the slot's default when it is unknown ({} only for an empty slot).
static func option(catalog: Dictionary, slot: String, id: String) -> Dictionary:
	var found := find(catalog, slot, id)
	if found.is_empty():
		var options: Array = catalog.get(slot, [])
		return options[0] if not options.is_empty() else {}
	return found


## The clip a skin that can play `available` plays for a move slot: the chosen one, else the skin's own.
static func clip(catalog: Dictionary, loadout: Dictionary, slot: String, available: Array) -> String:
	var chosen := String(option(catalog, slot, String(loadout.get(slot, ""))).get("clip", ""))
	return chosen if chosen in available else String(NATIVE.get(slot, ""))


## Whether a skin that can play `available` plays the option itself rather than its own clip.
static func playable(entry: Dictionary, available: Array) -> bool:
	return not entry.has("clip") or String(entry.clip) in available


## Whether `option` is a legendary look (docs/LEGENDARY_LOOKS.md): its name is magenta.
static func is_legendary(option: Dictionary) -> bool:
	# LEARN: "yes" and 1 are truthy in GDScript too, so the type is tested before the flag is trusted.
	var flag: Variant = option.get("legendary", false)
	return flag is bool and flag


## The draws `slot`'s options may name in place of a sheet ([] for a slot that has none).
static func draws_of(slot: String) -> Array[String]:
	var none: Array[String] = []
	match slot:
		"bolt":
			return BOLT_DRAWS
		"impact":
			return IMPACT_DRAWS
	return none


## Whether `option` names a draw its slot knows, so the game draws that look itself and it needs none of its sheet
## fields. An unknown draw is no exemption: the option is held to its sheet as well, and the draw is reported.
static func is_drawn(slot: String, option: Dictionary) -> bool:
	return option.has("draw") and option.get("draw") in draws_of(slot)


## What is wrong with a catalogue, one message per problem ([] when it is sound).
static func check(catalog: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for slot in SLOTS:
		var options: Variant = catalog.get(slot)
		if not options is Array or (options as Array).is_empty():
			problems.append("%s: no options" % slot)
			continue
		var seen := {}
		for entry: Variant in options:
			if not entry is Dictionary:
				problems.append("%s: an option is not an object" % slot)
				continue
			var option := entry as Dictionary
			var id := String(option.get("id", ""))
			if id == "" or seen.has(id):
				problems.append("%s: missing or repeated id '%s'" % [slot, id])
			seen[id] = true
			problems.append_array(_option_problems(slot, option))
		if NATIVE.has(slot) and String(options[0].get("clip", "")) != NATIVE[slot]:
			problems.append("%s: the default must be the native clip %s" % [slot, NATIVE[slot]])
	return problems


## What is wrong with one option's legendary flag, fields, draw, style or path ([] when nothing is).
static func _option_problems(slot: String, option: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var where := "%s.%s" % [slot, String(option.get("id", ""))]
	if option.has("legendary") and not option.get("legendary") is bool:
		problems.append("%s: legendary is not a bool" % where)
	var required: Array[String] = ["name", "note"]
	if not is_drawn(slot, option):
		required.append_array(Array(FIELDS[slot]))
	for field: String in required:
		if not option.get(field) is String:
			problems.append("%s: no %s" % [where, field])
	# LEARN: a draw is tested with has(), not get(). get() gives null both for a missing key and for "draw": null, and a
	# null draw is still a draw the catalogue named.
	if option.has("draw") and not (option.get("draw") in draws_of(slot)):
		problems.append("%s: unknown draw '%s'" % [where, str(option.get("draw"))])
	if slot == "circle" and not String(option.get("style", "")) in CIRCLE_STYLES:
		problems.append("%s: unknown style" % where)
	if slot == "bolt" and not is_drawn(slot, option) and not String(option.get("path", "")) in BOLT_PATHS:
		problems.append("%s: unknown path" % where)
	return problems
