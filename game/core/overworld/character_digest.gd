class_name CharacterDigest
extends RefCounted
## One Lanternroot character at a glance (ADR-0061), for the character screen and a character's progress: how many
## quests are done, how many townspeople they have met, which keys their boots know, how long they have played. Pure:
## it reads a saved state and the content, and decides nothing.
##
##   CharacterDigest.quests_done(catalog.quests, state.flags)   # 2
##   CharacterDigest.met(catalog.townsfolk, state.flags)        # ["innkeeper", "pip"]
##   CharacterDigest.keys_taught(state)                         # ["right", "left"]

## The flag set when a townsperson has been met: "met-" and their id (the talk sets it).
const MET := "met-"


static func flags_of(state: Dictionary) -> Dictionary:
	return state.get("flags", {}) if state.get("flags", {}) is Dictionary else {}


## How many quests are done.
static func quests_done(quests: Dictionary, flags: Dictionary) -> int:
	var n := 0
	for id: String in quests:
		if Quests.status(quests, id, flags) == Quests.DONE:
			n += 1
	return n


## The townspeople met so far, in the content's order.
static func met(townsfolk: Dictionary, flags: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in townsfolk:
		if bool(flags.get(MET + id, false)):
			out.append(id)
	return out


## Whether the boots run code the player typed (rather than their blocks).
static func typed(state: Dictionary) -> bool:
	var boots: Dictionary = state.get("boots", {}) if state.get("boots", {}) is Dictionary else {}
	return String(boots.get("mode", OverworldState.BLOCKS)) == OverworldState.CODE


## The keys the boots answer, in BootsRules.KEYS order. Blocks say it exactly: a key with a rule that changes x or y.
## Typed code cannot be read without running it, so it counts as all four once the town has seen all four work (the
## "all-ways" flag), and as none before.
static func keys_taught(state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if typed(state):
		if bool(flags_of(state).get("all-ways", false)):
			out.assign(BootsRules.KEYS)
		return out
	var boots: Dictionary = state.get("boots", {}) if state.get("boots", {}) is Dictionary else {}
	var blocks: Array = boots.get("blocks", []) if boots.get("blocks", []) is Array else []
	for key in BootsRules.KEYS:
		for block: Variant in blocks:
			if block is Dictionary and String((block as Dictionary).get("key", "")) == key and _moves(block):
				out.append(key)
				break
	return out


static func _moves(block: Dictionary) -> bool:
	for action: Variant in block.get("do", []):
		if not action is Dictionary:
			continue
		var change := String((action as Dictionary).get("change", ""))
		if change in BootsCode.AXES and int((action as Dictionary).get("by", 0)) != 0:
			return true
	return false


## The code the boots run, as the player would read it; "" for a state without boots.
static func source(state: Dictionary) -> String:
	# A state without boots, or with empty ones, has no code: read the key through get(), since a missing key is an error.
	var boots: Variant = state.get("boots", {})
	if not boots is Dictionary or (boots as Dictionary).is_empty():
		return ""
	var kept := boots as Dictionary
	var whole := state.duplicate()
	whole.boots = {
		"mode": String(kept.get("mode", OverworldState.BLOCKS)),
		"blocks": kept.get("blocks", []) if kept.get("blocks", []) is Array else [],
		"code": kept.get("code", {}) if kept.get("code", {}) is Dictionary else {},
	}
	return OverworldState.boots_source(whole)


## Time played as whole hours and minutes: 4000 seconds is (1, 6).
static func played(state: Dictionary) -> Vector2i:
	var seconds := maxi(0, int(state.get("played_seconds", 0)))
	@warning_ignore("integer_division")
	return Vector2i(seconds / 3600, (seconds % 3600) / 60)


## How many calendar days ago `then` was, seen from `now` (unix seconds, both in the player's local time): 0 is
## today, 1 yesterday.
static func days_ago(then: float, now: float, bias_minutes := 0) -> int:
	var shift := bias_minutes * 60
	var then_day := floori((then + shift) / 86400.0)
	var now_day := floori((now + shift) / 86400.0)
	return maxi(0, now_day - then_day)
