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
const CIRCLE_STYLES: Array[String] = ["codex", "rootglass", "clockwork", "constellation", "script-loom"]
const BOLT_PATHS: Array[String] = ["arc", "straight", "spiral"]
## What each slot's options must carry besides an id and a name.
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
	if entry.get("construction", "") == "shards":
		return true
	return not entry.has("clip") or String(entry.clip) in available


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
			var id := String((entry as Dictionary).get("id", ""))
			if id == "" or seen.has(id):
				problems.append("%s: missing or repeated id '%s'" % [slot, id])
			seen[id] = true
			for field: String in ["name", "note"] + Array(FIELDS[slot]):
				if not (entry as Dictionary).get(field) is String:
					problems.append("%s.%s: no %s" % [slot, id, field])
			if slot == "circle" and not String(entry.get("style", "")) in CIRCLE_STYLES:
				problems.append("circle.%s: unknown style" % id)
			if slot == "bolt" and not String(entry.get("path", "")) in BOLT_PATHS:
				problems.append("bolt.%s: unknown path" % id)
			if entry.has("construction"):
				if slot not in ["cast_light", "cast_heavy"] or entry.construction != "shards":
					problems.append("%s.%s: unknown construction" % [slot, id])
			if entry.has("circle_style"):
				if entry.get("construction", "") != "shards" or not String(entry.circle_style) in CIRCLE_STYLES:
					problems.append("%s.%s: unknown construction style" % [slot, id])
		if NATIVE.has(slot) and String(options[0].get("clip", "")) != NATIVE[slot]:
			problems.append("%s: the default must be the native clip %s" % [slot, NATIVE[slot]])
	return problems
