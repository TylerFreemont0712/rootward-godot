class_name ProgramRewards
extends RefCounted
## The cards a program run offers after a fight (Paradigm Update, B4): most are the run's own paradigm (the focus's
## cards likelier), some neutral, and some another paradigm's, so a deck can splash but never loses its identity.
## An elite adds a fourth card from another paradigm, one rarity up; a guardian offers rare cards of the run's own
## paradigm or neutral ones. Rarity follows the fight's weights, with a pity that grows each reward without a rare.
## Everything is drawn from the run's seed (the same room offers the same cards, and reloading cannot reroll it).

const RARITIES: Array[String] = ["common", "uncommon", "rare"]
const OWN := "own"
const NEUTRAL := "neutral"
const OTHER := "other"


## True for a program run that has picked a paradigm: older runs, Spellforge and the card run keep the rarity-only draw.
static func applies(state: Dictionary) -> bool:
	return state.get("playstyle", "") == "program" and String(state.get("paradigm", "")) != ""


## The card ids offered after a fight of `kind` (fight, elite or boss). Updates the run's rare pity.
static func draft_cards(state: Dictionary, kind: String, catalog: Dictionary) -> Array:
	var rules: Dictionary = ProgramRules.config_of(catalog).rewards
	var base: Dictionary = (catalog.config.rewards.shards as Dictionary).get(kind, {})
	var pool := ShardrunCatalog.sorted_values(catalog.shards).filter(
		func(card: Dictionary) -> bool: return card.get("draftable", true)
	)
	var rng := Rng.create(state.seed, "reward:%d:%d" % [state.layer, (state.visited as Array).size()])
	var shares: Dictionary = (rules.shares as Dictionary).duplicate()
	var held := ProgramRelics.modifiers(state, catalog)
	if float(held.reward_shift) > 0.0:
		# Polyglot: more of what you are offered is another paradigm's, less your own.
		shares[OTHER] = float(shares[OTHER]) + float(held.reward_shift)
		shares[OWN] = maxf(0.0, float(shares[OWN]) - float(held.reward_shift))
	if float(held.reward_focus) > 0.0:
		rules = rules.duplicate()
		rules.focus_weight = float(held.reward_focus)
	if kind == "boss":
		shares[OTHER] = 0.0
	var weights := _rarity_weights(base, float(state.get("rare_pity", 0.0)))
	var chosen: Array = []
	var wanted := int(catalog.balance.reward_choices)
	# The Intern (an Issue) puts a fourth card in the next few rewards.
	for boon: Dictionary in state.get("boons", []):
		if boon.kind == "intern":
			wanted += 1
			break
	var attempt := 0
	while chosen.size() < wanted and attempt < 80:
		attempt += 1
		var rarity := _roll_rarity(weights, rng)
		var group := _roll_group(pool, state, chosen, rarity, shares, rng)
		if group != "":
			chosen.append(_pick(pool, state, chosen, rarity, group, rules, rng))
	# At least one card of your own paradigm, always: the last slot becomes one if the dice gave none.
	if (
		not chosen.is_empty()
		and not chosen.any(func(id: String) -> bool: return _group_of(catalog.shards[id], state) == OWN)
	):
		var own := _pick_any(pool, state, chosen, OWN, weights, rules, rng)
		if own != "":
			chosen[chosen.size() - 1] = own
	if kind == "elite" and int(rules.elite_extra) > 0:
		var extra := _elite_extra(pool, state, chosen, weights, rules, rng)
		if extra != "":
			chosen.append(extra)
	_update_pity(state, chosen, catalog, float(rules.pity))
	return chosen


## What a card is to this run: its paradigm's own, neutral, or another paradigm's.
static func _group_of(card: Dictionary, state: Dictionary) -> String:
	var paradigm := String(card.get("paradigm", "neutral"))
	if paradigm == "neutral":
		return NEUTRAL
	return OWN if paradigm == String(state.paradigm) else OTHER


## The fight's rarity weights, with the pity added to the rare ones (the weights are percentages).
static func _rarity_weights(base: Dictionary, pity: float) -> Array[float]:
	var weights: Array[float] = []
	for rarity in RARITIES:
		var weight := float(base.get(rarity, 0.0))
		if rarity == "rare":
			weight += pity * 100.0
		weights.append(weight)
	return weights


static func _roll_rarity(weights: Array[float], rng: Rng) -> String:
	var index := Rng.pick_weighted(weights, rng.next())
	return RARITIES[index] if index >= 0 else RARITIES[0]


## Which group a slot comes from: by the shares, among the groups that still have a card of this rarity to give.
static func _roll_group(
	pool: Array, state: Dictionary, chosen: Array, rarity: String, shares: Dictionary, rng: Rng
) -> String:
	var groups: Array[String] = []
	var weights: Array[float] = []
	for group: String in [OWN, NEUTRAL, OTHER]:
		if float(shares.get(group, 0.0)) > 0.0 and not _left(pool, state, chosen, rarity, group).is_empty():
			groups.append(group)
			weights.append(float(shares[group]))
	var roll := rng.next()
	var index := Rng.pick_weighted(weights, roll)
	return groups[index] if index >= 0 else ""


## A card of `group` and `rarity`, the focus's cards ×focus_weight among the paradigm's own.
static func _pick(
	pool: Array, state: Dictionary, chosen: Array, rarity: String, group: String, rules: Dictionary, rng: Rng
) -> String:
	var candidates := _left(pool, state, chosen, rarity, group)
	var weights: Array[float] = []
	for card: Dictionary in candidates:
		var weight := 1.0
		if group == OWN and _is_focus(card, state):
			weight = float(rules.focus_weight)
		weights.append(weight)
	return String((candidates[Rng.pick_weighted(weights, rng.next())] as Dictionary).id)


## A card of `group` at any rarity the fight can give: for the guarantee of an own card.
static func _pick_any(
	pool: Array, state: Dictionary, chosen: Array, group: String, weights: Array[float], rules: Dictionary, rng: Rng
) -> String:
	for attempt in 12:
		var rarity := _roll_rarity(weights, rng)
		if not _left(pool, state, chosen, rarity, group).is_empty():
			return _pick(pool, state, chosen, rarity, group, rules, rng)
	for rarity in RARITIES:
		if not _left(pool, state, chosen, rarity, group).is_empty():
			return _pick(pool, state, chosen, rarity, group, rules, rng)
	return ""


## An elite's fourth card: another paradigm's, one rarity better than the dice gave (a rare stays rare).
static func _elite_extra(
	pool: Array, state: Dictionary, chosen: Array, weights: Array[float], rules: Dictionary, rng: Rng
) -> String:
	var rolled := RARITIES.find(_roll_rarity(weights, rng))
	for step: int in [mini(rolled + 1, RARITIES.size() - 1), rolled, 0]:
		var rarity: String = RARITIES[step]
		if not _left(pool, state, chosen, rarity, OTHER).is_empty():
			return _pick(pool, state, chosen, rarity, OTHER, rules, rng)
	return ""


static func _left(pool: Array, state: Dictionary, chosen: Array, rarity: String, group: String) -> Array:
	return pool.filter(
		func(card: Dictionary) -> bool:
			return card.rarity == rarity and not card.id in chosen and _group_of(card, state) == group
	)


static func _is_focus(card: Dictionary, state: Dictionary) -> bool:
	var focus := String(state.get("focus", ""))
	return focus != "" and String(card.get("focus", "")) == focus


## Each reward without a rare card raises the next one's chance of one; an offered rare resets it.
static func _update_pity(state: Dictionary, chosen: Array, catalog: Dictionary, step: float) -> void:
	var rare := chosen.any(func(id: String) -> bool: return catalog.shards[id].rarity == "rare")
	state.rare_pity = 0.0 if rare else minf(float(state.get("rare_pity", 0.0)) + step, 0.5)
