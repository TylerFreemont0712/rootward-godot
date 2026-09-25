class_name CardTable
extends RefCounted
## The Shardrun table (the deck playstyle): every place a card can sit during a fight, and what moving one does, as
## pure functions over a plain Dictionary (old client's `table.ts`). The screen only proposes a new table; the rules'
## `compose` checks that no card was made or lost, that no spell overflows, that the hold is within its limit, and that
## a spell cast this turn stays shut.
##
##   var table := CardTable.of(state, catalog)
##   var moved := CardTable.move(table, {"zone": "hand", "index": 0}, {"zone": "spell", "spell": "spell-1", "index": 9})
##   if not moved.is_empty(): session.command(CardTable.command(moved))
##
## A spot is {zone: "hand" | "hold" | "spell", index, spell?}. The table is {spells: [{id, name, capacity, shards,
## spent}], hand, held, hold_limit}.


static func of(state: Dictionary, catalog: Dictionary) -> Dictionary:
	var battle: Dictionary = state.get("battle", {})
	var spells: Array = []
	for spell: Dictionary in state.spells:
		(
			spells
			. append(
				{
					"id": spell.id,
					"name": spell.name,
					"capacity": int(spell.capacity),
					"shards": (spell.shards as Array).duplicate(),
					"spent": spell.id in (battle.get("cast", []) as Array),
				}
			)
		)
	return {
		"spells": spells,
		"hand": (battle.get("hand", []) as Array).duplicate(),
		"held": (battle.get("held", []) as Array).duplicate(),
		"hold_limit": ShardrunRules.hold_limit(state, catalog),
	}


## The `compose` command that asks the rules for this table.
static func command(table: Dictionary) -> Dictionary:
	var spells: Array = []
	for spell: Dictionary in table.spells:
		spells.append({"id": spell.id, "shards": (spell.shards as Array).duplicate()})
	return {
		"type": "compose",
		"spells": spells,
		"hand": (table.hand as Array).duplicate(),
		"held": (table.held as Array).duplicate()
	}


## Moves the card at `from` so it ends up at `to`, the way dropping it there would. Into a list with room, the card is
## inserted at `to.index` (past the end means last). Dropped on a card in a full list, the two swap places. {} when
## nothing would change or the move cannot happen: a spent spell, a full list dropped past its end, no card at `from`.
static func move(table: Dictionary, from: Dictionary, to: Dictionary) -> Dictionary:
	if _spent(table, from) or _spent(table, to):
		return {}
	var next := copy(table)
	var found_source: Variant = _cards_at(next, from)
	var found_target: Variant = _cards_at(next, to)
	if found_source == null or found_target == null:
		return {}
	var source: Array = found_source
	var target: Array = found_target
	var at := int(from.index)
	if at < 0 or at >= source.size():
		return {}
	var card: String = source[at]
	# LEARN: Arrays are passed by reference in GDScript, so two spots in the same list give the same Array object;
	# `is_same` asks whether they are one object, not whether they hold equal cards.
	if is_same(source, target):
		var index := mini(int(to.index), target.size() - 1)
		if index == at:
			return {}
		source.remove_at(at)
		target.insert(index, card)
		return next
	if target.size() < _room(next, to):
		source.remove_at(at)
		target.insert(mini(int(to.index), target.size()), card)
		return next
	var index := int(to.index)
	if index < 0 or index >= target.size():
		return {}
	var displaced: String = target[index]
	target[index] = card
	source[at] = displaced
	return next


## A click: a card in the hand goes to the end of `target_spell` (or the first spell with room when that one is full or
## spent); a card in a spell or the hold goes back to the hand. {} when there is nowhere for it to go.
static func tap(table: Dictionary, spot: Dictionary, target_spell := "") -> Dictionary:
	if spot.zone != "hand":
		return move(table, spot, {"zone": "hand", "index": (table.hand as Array).size()})
	var order: Array = table.spells.filter(func(s: Dictionary) -> bool: return s.id == target_spell)
	order.append_array(table.spells.filter(func(s: Dictionary) -> bool: return s.id != target_spell))
	for spell: Dictionary in order:
		if not spell.spent and (spell.shards as Array).size() < int(spell.capacity):
			return move(table, spot, {"zone": "spell", "spell": spell.id, "index": int(spell.capacity)})
	return {}


## A card in the hand put into the hold, or one in the hold put back in the hand.
static func toggle_hold(table: Dictionary, spot: Dictionary) -> Dictionary:
	if spot.zone == "hold":
		return move(table, spot, {"zone": "hand", "index": (table.hand as Array).size()})
	if spot.zone == "hand":
		return move(table, spot, {"zone": "hold", "index": (table.held as Array).size()})
	return {}


## The spell a click would play into: `wanted` if it has room, else the first spell with room, else "".
static func target(table: Dictionary, wanted: String) -> String:
	for spell: Dictionary in table.spells:
		if spell.id == wanted and _open(spell):
			return wanted
	for spell: Dictionary in table.spells:
		if _open(spell):
			return spell.id
	return ""


static func copy(table: Dictionary) -> Dictionary:
	var spells: Array = []
	for spell: Dictionary in table.spells:
		var twin := spell.duplicate()
		twin.shards = (spell.shards as Array).duplicate()
		spells.append(twin)
	return {
		"spells": spells,
		"hand": (table.hand as Array).duplicate(),
		"held": (table.held as Array).duplicate(),
		"hold_limit": int(table.hold_limit),
	}


static func _open(spell: Dictionary) -> bool:
	return not spell.spent and (spell.shards as Array).size() < int(spell.capacity)


static func _cards_at(table: Dictionary, spot: Dictionary) -> Variant:
	match String(spot.get("zone", "")):
		"hand":
			return table.hand
		"hold":
			return table.held
		"spell":
			for spell: Dictionary in table.spells:
				if spell.id == spot.get("spell", ""):
					return spell.shards
	return null


static func _room(table: Dictionary, spot: Dictionary) -> int:
	match String(spot.zone):
		"hand":
			return 1 << 30
		"hold":
			return int(table.hold_limit)
		"spell":
			for spell: Dictionary in table.spells:
				if spell.id == spot.get("spell", ""):
					return int(spell.capacity)
	return 0


static func _spent(table: Dictionary, spot: Dictionary) -> bool:
	if spot.get("zone", "") != "spell":
		return false
	for spell: Dictionary in table.spells:
		if spell.id == spot.get("spell", ""):
			return bool(spell.spent)
	return false
