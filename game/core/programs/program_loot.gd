class_name ProgramLoot
extends RefCounted
## Where a program run's relics come from. Every program relic has a tier (common, uncommon, rare, epic, legendary),
## and every place relics are found has a table of tier weights (programs.jsonc `relic_tiers`): a treasure leans
## common, an elite offers only rare or better, a guardian epic or legendary. A draw picks a tier by weight among the
## tiers that still have a relic to offer, then a relic of that tier, all from the run's seed: the same room always
## offers the same, and reloading cannot reroll it.


## `count` distinct relics the run does not hold yet, found at `where` (treasure, elite or boss). Fewer when the tiers
## that place offers have run dry.
static func draft_relics(state: Dictionary, where: String, count: int, catalog: Dictionary) -> Array:
	var table: Dictionary = (ProgramRules.config_of(catalog).relic_tiers as Dictionary).get(where, {})
	var pool := ShardrunCatalog.sorted_values(catalog.relics).filter(
		func(relic: Dictionary) -> bool: return not relic.get("cursed", false) and not relic.id in state.relics
	)
	var rng := Rng.create(state.seed, "relic:%s:%d:%d" % [where, state.layer, (state.visited as Array).size()])
	var choices: Array = []
	while choices.size() < count:
		var tiers: Array[String] = []
		var weights: Array[float] = []
		for tier: String in ProgramSchemas.TIERS:
			# LEARN: a tier with nothing left to give is taken out of the draw, not rolled and then skipped, so an elite
			# always offers a relic while any rare-or-better one remains, and the weights of the rest stay in proportion.
			if float(table.get(tier, 0.0)) > 0.0 and not _left(pool, tier, choices).is_empty():
				tiers.append(tier)
				weights.append(float(table[tier]))
		if tiers.is_empty():
			break
		var candidates := _left(pool, tiers[Rng.pick_weighted(weights, rng.next())], choices)
		choices.append((candidates[floori(rng.next() * candidates.size())] as Dictionary).id)
	return choices


## The relics of `tier` in `pool` not already chosen.
static func _left(pool: Array, tier: String, chosen: Array) -> Array:
	return pool.filter(func(relic: Dictionary) -> bool: return relic.tier == tier and not relic.id in chosen)


## A relic's tier as a number, 1 (common) to 5 (legendary); 0 for a curse or a relic without one.
static func tier_number(relic: Dictionary) -> int:
	if relic.get("cursed", false):
		return 0
	return ProgramSchemas.TIERS.find(String(relic.get("tier", ""))) + 1
