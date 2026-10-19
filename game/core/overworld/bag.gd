class_name Bag
extends RefCounted
## The player's bag (Concept/v0.4/01, 5.6): a list of stacks, {"item": id, "count": n}, in the order the player's own
## add() and remove() leave them. Pure: counting, checking a live answer with the task's own judges, and the things
## in town that give items (pickups) with their regrowing.
##
##   Bag.counts(state.bag)                         # {"apple": 2, "cabbage": 3}
##   Bag.valid_add(before, after, "apple")         # the bag_add judge's verdict on one live call
##   Bag.pickup_at(pickups, "lanternroot", rect)   # the pickup under a prop's footprint, or {}
##   Bag.ripe(state, "lanternroot", cell, 240.0)   # it has grown back since it was last picked


static func stacks(bag: Variant) -> Array:
	return bag if bag is Array else []


static func count(bag: Variant, item: String) -> int:
	var n := 0
	for stack: Variant in stacks(bag):
		if stack is Dictionary and String((stack as Dictionary).get("item", "")) == item:
			n += int((stack as Dictionary).get("count", 0))
	return n


static func counts(bag: Variant) -> Dictionary:
	var out := {}
	for stack: Variant in stacks(bag):
		if not stack is Dictionary:
			continue
		var item := String((stack as Dictionary).get("item", ""))
		if item != "":
			out[item] = int(out.get(item, 0)) + int((stack as Dictionary).get("count", 0))
	return out


## One live add judged as the task judges its cases: {ok, reason, ...}.
static func valid_add(before: Array, after: Variant, item: String) -> Dictionary:
	var cases := [{"args": [before, item]}]
	return TaskJudges.judge("bag_add", cases, [{"ok": true, "value": after}])[0]


static func valid_remove(before: Array, after: Variant, item: String) -> Dictionary:
	var cases := [{"args": [before, item]}]
	return TaskJudges.judge("bag_remove", cases, [{"ok": true, "value": after}])[0]


## A bag as the game keeps it: only stacks with an item and a whole count of 1 or more (counts made whole).
static func cleaned(bag: Variant) -> Array:
	var out: Array = []
	for stack: Variant in stacks(bag):
		if stack is Dictionary and String((stack as Dictionary).get("item", "")) != "":
			var n := int((stack as Dictionary).get("count", 0))
			if n >= 1:
				out.append({"item": String(stack.item), "count": n})
	return out


# --- pickups -------------------------------------------------------------------------------------------------------


## The pickup whose cell lies in `footprint` on `map_id` ({at, item, regrow}), or {} when that prop gives nothing.
static func pickup_at(pickups: Dictionary, map_id: String, footprint: Rect2i) -> Dictionary:
	for pickup: Variant in pickups.get(map_id, []):
		if not pickup is Dictionary:
			continue
		var at := OverworldMap.cell_of((pickup as Dictionary).get("at", [-1, -1]))
		if footprint.has_point(at):
			return pickup
	return {}


static func key_of(map_id: String, at: Vector2i) -> String:
	return "%s:%d,%d" % [map_id, at.x, at.y]


## Whether the pickup at `at` can be picked now: never picked, or picked `regrow` seconds of play ago or more. A
## regrow below 0 gives once only.
static func ripe(state: Dictionary, map_id: String, at: Vector2i, regrow: float) -> bool:
	var picked: Dictionary = state.get("picked", {}) if state.get("picked", {}) is Dictionary else {}
	var key := key_of(map_id, at)
	if not picked.has(key):
		return true
	if regrow < 0.0:
		return false
	return float(state.get("played_seconds", 0.0)) - float(picked[key]) >= regrow


## The state with the pickup at `at` picked now (the played seconds), and "picked-<item>" set.
static func picked(state: Dictionary, map_id: String, at: Vector2i, item: String) -> Dictionary:
	var out := state.duplicate(true)
	if not out.get("picked") is Dictionary:
		out["picked"] = {}
	out.picked[key_of(map_id, at)] = float(state.get("played_seconds", 0.0))
	var flags: Dictionary = (out.get("flags", {}) as Dictionary).duplicate()
	flags["picked-" + item] = true
	out.flags = flags
	return out
