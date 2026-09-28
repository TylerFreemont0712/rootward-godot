class_name ProgramDeck
extends RefCounted
## A program run's deck in a fight, beyond the Shardrun's piles (ADR-0018): imports that hold for the rest of the fight,
## keywords (`once`, `volatile`, `const`, `__init__`, `lambda`), cards that make cards, and the fight's globals. Pure
## functions over the state, like the rest of the rules; the shared rules call them only in a program run.
##
## A fight's own lists live on the battle: `imports` (import cards in force), `gone` (cards spent for the fight) and
## `globals` ({name: value}).


## A fight begins with nothing imported, nothing gone and no globals.
static func on_battle_start(battle: Dictionary) -> void:
	battle.imports = []
	battle.gone = []
	battle.globals = {}


static func is_import(card_id: String, catalog: Dictionary) -> bool:
	return (catalog.shards.get(card_id, {}) as Dictionary).get("role", "") == "import"


static func has_keyword(card_id: String, keyword: String, catalog: Dictionary) -> bool:
	return keyword in (catalog.shards.get(card_id, {}) as Dictionary).get("keywords", [])


## The imports in force for the program about to run: those imported earlier in the fight, then those in the program
## itself (their lines sit at its top). A module counts once, whichever card imported it.
static func imports(state: Dictionary, catalog: Dictionary) -> Array[String]:
	# LEARN: importing a module twice does nothing more in Python: the second `import heapq` finds it in sys.modules
	# and binds the name again. So an import and its + count once, and their effects never stack.
	var candidates: Array = ((state.get("battle", {}) as Dictionary).get("imports", []) as Array).duplicate()
	var spells: Array = state.get("spells", [])
	if not spells.is_empty() and state.has("battle"):
		for id: String in (spells[0] as Dictionary).get("shards", []):
			if is_import(id, catalog):
				candidates.append(id)
	var out: Array[String] = []
	var seen := {}
	for id: String in candidates:
		var module := String((catalog.shards.get(id, {}) as Dictionary).get("module", id))
		if not seen.has(module):
			seen[module] = true
			out.append(id)
	return out


## The modules the cards' code finds in battle["imports"] ("math").
static func modules(state: Dictionary, catalog: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in imports(state, catalog):
		out.append(String((catalog.shards.get(id, {}) as Dictionary).get("module", id)))
	return out


## The cards of a program that run as its steps: all but its imports.
static func steps(card_ids: Array, catalog: Dictionary) -> Array:
	return card_ids.filter(func(id: String) -> bool: return not is_import(id, catalog))


## After a program runs: its imports stay in force for the fight, `once` cards are gone for the fight, the rest go to
## the discard pile. A card that makes cards puts them on top of the draw pile; a global the program spends starts
## again from 0.
static func spend(state: Dictionary, battle: Dictionary, spell: Dictionary, catalog: Dictionary) -> void:
	for id: String in spell.shards:
		var card: Dictionary = catalog.shards.get(id, {})
		if is_import(id, catalog):
			if not id in battle.imports:
				(battle.imports as Array).append(id)
				var text := "%s: in force for the rest of the fight." % String(card.get("name", id))
				Shardrun.record(state, {"kind": "import", "card": id, "text": text})
		elif has_keyword(id, "once", catalog):
			(battle.gone as Array).append(id)
		else:
			(battle.discard as Array).append(id)
		var adds: Dictionary = card.get("adds", {})
		if not adds.is_empty():
			for i in int(adds.count):
				(battle.draw as Array).push_front(adds.card)
			var made: String = (catalog.shards.get(adds.card, {}) as Dictionary).get("name", adds.card)
			var text := "%s writes %d %s on top of your draw pile." % [card.get("name", id), int(adds.count), made]
			Shardrun.record(state, {"kind": "note", "amount": int(adds.count), "text": text})
		if card.has("spends"):
			(battle.globals as Dictionary)[card.spends] = 0
	spell.shards = []


## A program's landed damage, added to every global in force (`global total`).
static func after_cast(state: Dictionary, battle: Dictionary, dealt: int, catalog: Dictionary) -> void:
	var names: Array = ProgramRelics.modifiers(state, catalog).globals
	if names.is_empty() or dealt <= 0:
		return
	var globals: Dictionary = battle.get("globals", {})
	for name: String in names:
		globals[name] = int(globals.get(name, 0)) + dealt
	battle.globals = globals


## The end of a turn: `const` cards stay in the hand, `volatile` ones still in it (or in a program that never ran) are
## gone for the fight, the rest go to the discard pile. The next hand starts with the held cards and the const ones.
static func end_turn(state: Dictionary, battle: Dictionary, catalog: Dictionary) -> void:
	var leftover: Array = (battle.hand as Array).duplicate()
	for spell: Dictionary in state.spells:
		leftover.append_array(spell.shards)
		spell.shards = []
	var kept: Array = []
	for id: String in leftover:
		if has_keyword(id, "const", catalog):
			kept.append(id)
		elif has_keyword(id, "volatile", catalog):
			(battle.gone as Array).append(id)
		else:
			(battle.discard as Array).append(id)
	var hand: Array = (battle.held as Array).duplicate()
	hand.append_array(kept)
	battle.hand = hand
	battle.held = []


## The draw pile with every `__init__` card on top, in the order they were shuffled: an opening hand always has them.
static func innate_first(draw: Array, catalog: Dictionary) -> Array:
	var first := draw.filter(func(id: String) -> bool: return has_keyword(id, "__init__", catalog))
	first.append_array(draw.filter(func(id: String) -> bool: return not has_keyword(id, "__init__", catalog)))
	return first
