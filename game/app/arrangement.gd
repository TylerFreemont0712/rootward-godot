class_name Arrangement
extends RefCounted
## Moving one shard on the workbench, as the `arrange` command the rules check (every spell listed once, nothing made
## or lost). A place is {"spell": spell id, "index": i} or {"spell": "", "index": i} for the spare shards; an index past
## the end means "at the end".
##
##   var move := Arrangement.move(state, {"spell": "", "index": 0}, {"spell": "spell-1", "index": 1})
##   if move.ok: await session.command(move.command)   else: say(move.message)
##
## Dropping onto a shard puts the moved one before it. When the spell it lands in is full, the two swap places
## instead, so a full spell can still be rearranged by hand.

const SPARE := ""


static func move(state: Dictionary, from: Dictionary, to: Dictionary, onto_shard := false) -> Dictionary:
	var lists := _lists(state)
	var source: Array = lists.get(from.spell, [])
	var from_index := int(from.index)
	if not lists.has(from.spell) or from_index < 0 or from_index >= source.size():
		return _no("There is no shard there.")
	if not lists.has(to.spell):
		return _no("There is no such spell.")
	var target: Array = lists[to.spell]
	var to_index := clampi(int(to.index), 0, target.size())
	var same := String(from.spell) == String(to.spell)
	if same:
		var shard: Variant = source.pop_at(from_index)
		if to_index > from_index:
			to_index -= 1
		source.insert(to_index, shard)
	elif target.size() < _capacity(state, to.spell):
		target.insert(to_index, source.pop_at(from_index))
	elif onto_shard and to_index < target.size():
		var swapped: Variant = target[to_index]
		target[to_index] = source[from_index]
		source[from_index] = swapped
	else:
		var spell := Shardrun.spell_by_id(state, to.spell)
		return _no("%s holds at most %d shards. Drop onto a shard to swap them." % [spell.name, spell.capacity])
	return {"ok": true, "command": _command(state, lists)}


## The command that leaves everything where it is plus `changes` (spell id or SPARE -> shard list).
static func command_with(state: Dictionary, changes: Dictionary) -> Dictionary:
	var lists := _lists(state)
	lists.merge(changes, true)
	return _command(state, lists)


static func _lists(state: Dictionary) -> Dictionary:
	var lists := {SPARE: (state.inventory as Array).duplicate()}
	for spell: Dictionary in state.spells:
		lists[spell.id] = (spell.shards as Array).duplicate()
	return lists


static func _capacity(state: Dictionary, spell_id: String) -> int:
	if spell_id == SPARE:
		return 1 << 30
	return int(Shardrun.spell_by_id(state, spell_id).get("capacity", 0))


static func _command(state: Dictionary, lists: Dictionary) -> Dictionary:
	var spells: Array = []
	for spell: Dictionary in state.spells:
		spells.append({"id": spell.id, "shards": lists[spell.id]})
	return {"type": "arrange", "spells": spells, "inventory": lists[SPARE]}


static func _no(message: String) -> Dictionary:
	return {"ok": false, "message": message}
