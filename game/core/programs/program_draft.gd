class_name ProgramDraft
extends RefCounted
## A program run begins with a draft (ADR-0012): pick one paradigm of the few offered, whose signature cards join the
## basics, then one card from each of a few small packs. Every offer is drawn from the run's seed, so the same seed
## offers the same draft, and a different seed a different one.
##
## While drafting, the state's status is "draft" and state.draft is {offers: [paradigm ids], round, rounds, pack:
## [card ids]}; `pack` is empty until a paradigm is picked.

## The Program is a file named for the run's language.
const EXTENSIONS := {"python": "py", "javascript": "js"}
## How often a card of each rarity turns up in a pack, relative to a common one.
const RARITY_WEIGHTS := {"common": 1.0, "uncommon": 0.6, "rare": 0.3}
## A card of the chosen paradigm is this much likelier than a neutral one.
const PARADIGM_WEIGHT := 2.0


## Turns a freshly started deck-shaped run into a program run waiting on its draft.
static func open(state: Dictionary, catalog: Dictionary) -> void:
	var config := ProgramRules.config_of(catalog)
	var draft: Dictionary = config.draft
	var ids: Array = (config.paradigms as Array).map(func(paradigm: Dictionary) -> String: return paradigm.id)
	var offers := Rng.create(state.seed, "paradigms").shuffled(ids).slice(0, int(draft.paradigms_offered))
	state.playstyle = "program"
	state.status = "draft"
	for spell: Dictionary in state.spells:
		spell.name = "%s.%s" % [spell.name, EXTENSIONS.get(state.language, "py")]
	state.paradigm = ""
	state.draft = {"offers": offers, "round": 0, "rounds": int(draft.rounds), "pack": []}
	var text := "Before the descent, choose how your program thinks."
	Shardrun.record(state, {"kind": "note", "text": text})


static func paradigm_of(catalog: Dictionary, id: String) -> Dictionary:
	for paradigm: Dictionary in ProgramRules.config_of(catalog).paradigms:
		if paradigm.id == id:
			return paradigm
	return {}


## pick-paradigm {paradigm_id}: its signature cards join the deck, and the first pack opens.
static func pick_paradigm(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var draft: Dictionary = next.get("draft", {})
	if next.status != "draft" or not (draft.pack as Array).is_empty() or next.paradigm != "":
		return {"code": "not-choosing", "message": "There is no paradigm to choose now."}
	var id: String = command.get("paradigm_id", "")
	if not id in draft.offers:
		return {"code": "not-offered", "message": "That paradigm was not offered."}
	var paradigm := paradigm_of(catalog, id)
	next.paradigm = id
	(next.deck as Array).append_array(paradigm.signature)
	var names: Array = (paradigm.signature as Array).map(
		func(card_id: String) -> String: return (catalog.shards.get(card_id, {}) as Dictionary).get("name", card_id)
	)
	var text := "%s: %s join your deck." % [paradigm.name, " and ".join(names)]
	Shardrun.record(next, {"kind": "reward", "text": text})
	_next_pack(next, catalog)
	return {}


## draft-card {card_id}: one card of the open pack joins the deck; the next pack opens, or the descent begins.
static func pick_card(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var draft: Dictionary = next.get("draft", {})
	if next.status != "draft" or (draft.get("pack", []) as Array).is_empty():
		return {"code": "no-pack", "message": "There is no pack open."}
	var id: String = command.get("card_id", "")
	if not id in draft.pack:
		return {"code": "not-offered", "message": "That card is not in the pack."}
	(next.deck as Array).append(id)
	var name: String = (catalog.shards.get(id, {}) as Dictionary).get("name", id)
	Shardrun.record(next, {"kind": "reward", "text": "%s joins your deck." % name})
	draft.round += 1
	_next_pack(next, catalog)
	return {}


static func _next_pack(next: Dictionary, catalog: Dictionary) -> void:
	var draft: Dictionary = next.draft
	if int(draft.round) >= int(draft.rounds):
		next.erase("draft")
		next.status = "map"
		var text := "Your deck holds %d cards. The Salvage opens below." % (next.deck as Array).size()
		Shardrun.record(next, {"kind": "note", "text": text})
		return
	draft.pack = pack(next, int(draft.round), catalog)


## The pack of a draft round: distinct draftable cards of the paradigm's pool and the neutral ones, the paradigm's
## likelier, rarer ones rarer.
static func pack(state: Dictionary, round: int, catalog: Dictionary) -> Array:
	var config := ProgramRules.config_of(catalog)
	var own: Array = paradigm_of(catalog, state.paradigm).get("pool", [])
	var candidates: Array[String] = []
	for id: String in own + (config.neutral as Array):
		var card: Dictionary = catalog.shards.get(id, {})
		if not card.is_empty() and card.get("draftable", true) and not id in candidates:
			candidates.append(id)
	var weights: Array[float] = []
	for id in candidates:
		var card: Dictionary = catalog.shards[id]
		var weight := float(RARITY_WEIGHTS.get(card.rarity, 1.0))
		weights.append(weight * (PARADIGM_WEIGHT if id in own else 1.0))
	var rng := Rng.create(state.seed, "draft:%d" % round)
	var chosen: Array = []
	while chosen.size() < int(config.draft.pack_size) and chosen.size() < candidates.size():
		var index := Rng.pick_weighted(weights, rng.next())
		chosen.append(candidates[index])
		# LEARN: sampling without replacement by zeroing the weight of what was drawn: the next roll spreads over what
		# is left, still in proportion, and nothing has to be removed from the list (which would shift every index).
		weights[index] = 0.0
	return chosen
