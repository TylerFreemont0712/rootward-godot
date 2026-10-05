class_name ProgramRules
extends RefCounted
## The Shardrun's programs (ADR-0012): what a cast costs, how much work it does, who acts before it lands, and what
## its bolts do. Pure functions over plain data, like the rest of the rules.
##
## A program is a spell whose shards are program cards (catalog.programs.cards, which a program run's catalog serves
## as `shards`). It starts from the seed volley; each card is a real function run in the sandbox, taking the volley and
## the battle and returning a new one. The rules never trust a number the code computed as damage: they read each
## bolt ({power, element, foe?, block?}), clamp it, and resolve it here.
##
## Work: every stage's complexity applied to the size of the volley it handled (the larger of what it was given and
## what it returned, both measured by the harness). A foe whose tempo is below the program's work acts before the
## program lands. Work above the budget is a timeout: nothing lands.

const TIER_LABELS := {
	"constant": "O(1)",
	"logarithmic": "O(log n)",
	"linear": "O(n)",
	"linearithmic": "O(n log n)",
	"quadratic": "O(n²)",
	"exponential": "O(2ⁿ)",
	"pseudo": "O(n·H)",
}
## Slowest last: a program is as slow as its slowest stage's class.
const TIER_ORDER: Array[String] = [
	"constant", "logarithmic", "linear", "linearithmic", "pseudo", "quadratic", "exponential"
]
## Work never counts past this (an exponential stage on a big volley): far past any budget.
const WORK_CAP := 1 << 30


## A program run's catalog: the program cards served as `shards`, one Program for the deck's spells, the basics as
## its cards, and the program's own relics (tiered, `programs/relics/`). Foes and balance are the Shardrun's; the
## layers are too, with the program's own foe HP and encounters where programs.jsonc gives them.
static func catalog_for(catalog: Dictionary) -> Dictionary:
	var programs: Dictionary = catalog.programs
	var config: Dictionary = (catalog.config as Dictionary).duplicate()
	var shape: Dictionary = programs.config.program
	config.deck = {
		"spells": [{"name": shape.name, "capacity": int(shape.capacity)}],
		"cards": (programs.config.basics as Array).duplicate(),
	}
	var foe_hp: Array = programs.config.get("foe_hp", [])
	var encounters: Dictionary = programs.config.get("encounters", {})
	var layers: Array = []
	for index in (config.layers as Array).size():
		var layer: Dictionary = (config.layers[index] as Dictionary).duplicate()
		layer.merge(programs.config.get("map", {}).get(layer.id, {}), true)
		if not foe_hp.is_empty():
			layer.foe_hp = float(foe_hp[mini(index, foe_hp.size() - 1)])
		if encounters.has(layer.id):
			var groups: Dictionary = (layer.encounters as Dictionary).duplicate()
			groups.merge(encounters[layer.id], true)
			layer.encounters = groups
		layers.append(layer)
	# A program run goes deeper than Spellforge: its own layers follow (the Root, docs/NewEnemies.md).
	for extra: Dictionary in programs.config.get("layers", []):
		var layer := extra.duplicate(true)
		layer.foe_hp = float(foe_hp[mini(layers.size(), foe_hp.size() - 1)]) if not foe_hp.is_empty() else layer.foe_hp
		layers.append(layer)
	for layer: Dictionary in layers:
		layer.merge(programs.config.get("layer_looks", {}).get(layer.id, {}), true)
	config.layers = layers
	var derived := catalog.duplicate()
	derived.playstyle = "program"
	derived.config = config
	derived.shards = programs.cards
	derived.relics = programs.get("relics", {})
	# The program run's own foes join the Shardrun's (ADR-0017).
	var foes: Dictionary = (catalog.foes as Dictionary).duplicate()
	foes.merge(programs.get("foes", {}))
	derived.foes = foes
	return derived


static func config_of(catalog: Dictionary) -> Dictionary:
	return catalog.programs.config


## The volley a program starts from in this state: the seed of programs.jsonc (three plain bolts), grown by relics
## that feed the program more input (ProgramRelics).
static func seed(state: Dictionary, catalog: Dictionary) -> Array:
	return ProgramRelics.seed((config_of(catalog).seed as Array).duplicate(true), state, catalog)


## Work units for a stage of `complexity` over a volley of `n` bolts. `cap_n` caps n (an algorithm that gives up past
## a size); `height` is the H of an O(n·H) table.
static func work_units(complexity: String, n: int, cap_n := 0, height := 1) -> int:
	var size := maxi(0, n)
	if cap_n > 0:
		size = mini(size, cap_n)
	match complexity:
		"constant":
			return 1
		"logarithmic":
			return ceili(JsMath.log2_whole(size + 1))
		"linearithmic":
			return ceili(size * JsMath.log2_whole(size + 1))
		"quadratic":
			return mini(WORK_CAP, size * size)
		"exponential":
			return WORK_CAP if size >= 30 else mini(WORK_CAP, 1 << size)
		"pseudo":
			return mini(WORK_CAP, size * maxi(1, height))
	return size


## Each stage's work from a run's trace ([{shard, given, returned}]): [{card, n, given, work, complexity}], in order.
## A card's class can be its worst case on the input it gets (quick sort on a sorted volley), or a relic's for its role;
## relics can also make a card's work free (the first card, a card compiled earlier in the fight) or cheaper.
static func stages(state: Dictionary, trace: Array, catalog: Dictionary) -> Array[Dictionary]:
	var m := ProgramRelics.modifiers(state, catalog)
	var ran: Array = (state.get("battle", {}) as Dictionary).get("ran", [])
	var order := "sorted"
	var out: Array[Dictionary] = []
	# A tail call (waives_next) lets the cards after it run without a frame of their own: no work.
	var waived := 0
	var free_roles: Array = (m.first_role_free as Array).map(func(rule: Dictionary) -> String: return rule.role)
	var previous_splits := false
	for index in trace.size():
		var step: Dictionary = trace[index]
		var card: Dictionary = catalog.shards.get(step.shard, {})
		var before_order := order
		order = hooked(order, m.hooks, "before", card, catalog).order
		# LEARN: n is the larger of the volley in and the volley out. A card that turns 7 bolts into 21 pairs did 21
		# pieces of work even though it was handed 7; counting only its input would make growing cards free.
		var n := maxi(int(step.given), int(step.get("returned", step.given)))
		var input_order := ("sorted" if step.input_sorted else "unsorted") if step.has("input_sorted") else order
		var complexity := ProgramRelics.complexity(card, input_order, m)
		var height := int(card.get("height", front_need(state)))
		var work := work_units(complexity, n, int(card.get("cap_n", 0)), height)
		if card.get("work_mode", "") == "measured":
			work = maxi(1, int(step.get("measured", work)))
		if step.get("pruned", false):
			work = 0
		if waived > 0:
			work = 0
			waived -= 1
		waived += int(card.get("waives_next", 0))
		if card.get("role", "") in free_roles:
			free_roles.erase(card.role)
			work = 0
		if previous_splits and float(m.split_next_work) < 1.0:
			work = floori(work * float(m.split_next_work))
		previous_splits = bool(card.get("splits", false))
		if (int(step.get("slot", index)) == 0 and m.free_first_work) or (m.jit and step.shard in ran):
			work = 0
		work = floori(work * float(m.work_factor))
		if (state.get("battle", {}) as Dictionary).get("nice", false):
			work = 0
		elif int((state.get("battle", {}) as Dictionary).get("jobs", 0)) > 1:
			work = work / int(state.battle.jobs)
		out.append(
			{
				"card": step.shard,
				"n": n,
				"given": int(step.given),
				"work": work,
				"complexity": complexity,
				"pruned": bool(step.get("pruned", false))
			}
		)
		if step.has("slot"):
			out.back().slot = int(step.slot)
		if step.get("pruned", false):
			order = before_order
			continue
		if card.has("makes"):
			order = card.makes
		order = hooked(order, m.hooks, "after", card, catalog).order
	var slots := {}
	for i in trace.size():
		slots[int(trace[i].get("slot", i))] = true
	var factor := 1.0
	for rule: Dictionary in m.small_program_work:
		if not slots.is_empty() and slots.size() <= int(rule.max_cards):
			factor *= float(rule.factor)
	# Allocate rounding across stages so the discounted total is floor(total * factor).
	var before_work := 0
	var after_work := 0
	for stage in out:
		before_work += int(stage.work)
		var next_work := floori(before_work * factor)
		stage.work = next_work - after_work
		after_work = next_work
	return out


## The volley's order once an import's hooks have run `when` a card of this card's role runs (bisect sorts after each
## source, heapq hands strikes the strongest first): {order, by (the import's name, or "")}.
static func hooked(order: String, hooks: Array, when: String, card: Dictionary, catalog: Dictionary) -> Dictionary:
	var result := {"order": order, "by": ""}
	for hook: Dictionary in hooks:
		if hook.when == when and hook.role == card.get("role", ""):
			var by: Dictionary = catalog.shards.get(hook.card, {})
			if by.has("makes"):
				result = {"order": by.makes, "by": by.get("name", hook.card)}
	return result


static func total_work(stage_list: Array[Dictionary]) -> int:
	var total := 0
	for stage in stage_list:
		total = mini(WORK_CAP, total + int(stage.work))
	return total


## The HP plus shield of the first living foe: the H of an O(n·H) table.
static func front_need(state: Dictionary) -> int:
	for foe: Dictionary in (state.get("battle", {}) as Dictionary).get("foes", []):
		if int(foe.hp) > 0:
			return int(foe.hp) + int(foe.shield)
	return 1


## The slowest complexity class among a program's steps (its imports are not steps), as its label ("O(n log n)").
static func speed_label(card_ids: Array, catalog: Dictionary) -> String:
	var slowest := 0
	var steps := ProgramDeck.steps(card_ids, catalog)
	for id: String in steps:
		var card: Dictionary = catalog.shards.get(id, {})
		slowest = maxi(slowest, TIER_ORDER.find(card.get("complexity", "linear")))
	return TIER_LABELS[TIER_ORDER[slowest]] if not steps.is_empty() else "O(1)"


## The slowest class the stages actually ran at (worst cases and relics included), as a class name.
static func slowest_class(stage_list: Array[Dictionary]) -> String:
	var slowest := 0
	for stage in stage_list:
		slowest = maxi(slowest, TIER_ORDER.find(String(stage.get("complexity", "linear"))))
	return TIER_ORDER[slowest]


static func big_o(card: Dictionary) -> String:
	return card.get("big_o", TIER_LABELS.get(card.get("complexity", "linear"), "O(n)"))


## The operations a foe waits before it acts this turn: the speed of the intent it is about to carry out (ADR-0017),
## from the intent itself (a program foe's) or programs.jsonc (a Shardrun foe's, one per intent), else the default,
## and what relics add to it.
static func tempo_of(foe: Dictionary, state: Dictionary, catalog: Dictionary) -> int:
	var config := config_of(catalog)
	var at := int(foe.get("intent_index", 0))
	var tempo := int(config.tempo_default)
	var speeds: Array = (config.tempo as Dictionary).get(foe.get("id", ""), [])
	if not speeds.is_empty():
		tempo = int(speeds[at % speeds.size()])
	var intents: Array = foe.get("intents", [])
	if not intents.is_empty():
		var intent: Dictionary = intents[at % intents.size()]
		tempo = int(intent.get("tempo", tempo))
		# Self-hosting (the Root Compiler, ADR-0026): exactly the work the last program did.
		if intent.get("self_hosting", false):
			tempo = int((state.get("battle", {}) as Dictionary).get("last_work", tempo))
	return maxi(1, tempo + int(ProgramRelics.modifiers(state, catalog).tempo))


## Work above which a program times out: the config's for this layer, raised or cut by relics.
static func budget(state: Dictionary, catalog: Dictionary) -> int:
	var m := ProgramRelics.modifiers(state, catalog)
	var by_layer: Array = config_of(catalog).budget
	var base := int(by_layer[clampi(int(state.get("layer", 0)), 0, by_layer.size() - 1)])
	return maxi(1, floori((base + int(m.budget)) * float(m.budget_factor)))


## How much a foe the program lands before takes: Initiative (programs.jsonc), made stronger by relics.
static func initiative(state: Dictionary, catalog: Dictionary) -> float:
	var relics := ProgramRelics.modifiers(state, catalog)
	return (1.0 + float(config_of(catalog).get("initiative", 0.0))) * float(relics.initiative)


static func cost_of(state: Dictionary, spell: Dictionary, catalog: Dictionary) -> int:
	return ProgramRelics.cost(state, spell.shards, catalog)


## The living foes that would act before a program of `work` lands: those whose tempo is below it and that have not
## acted this turn.
static func faster_foes(state: Dictionary, battle: Dictionary, work: int, catalog: Dictionary) -> Array[Dictionary]:
	var acted: Array = battle.get("acted", [])
	var out: Array[Dictionary] = []
	for foe: Dictionary in battle.foes:
		if int(foe.hp) > 0 and not foe.uid in acted and tempo_of(foe, state, catalog) < work:
			out.append(foe)
	return out


## What the code panel warns about, by step (a program's cards but its imports): a card that needs a sorted volley
## after one that left it unsorted, an import's hook included. The seed's bolts are equal, so it starts sorted.
## [{index, message}]
static func lint(card_ids: Array, catalog: Dictionary, hooks: Array = []) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	var order := "sorted"
	var culprit := "the seed"
	var steps := ProgramDeck.steps(card_ids, catalog)
	for index in steps.size():
		var card: Dictionary = catalog.shards.get(steps[index], {})
		var before := hooked(order, hooks, "before", card, catalog)
		if before.by != "":
			order = before.order
			culprit = before.by
		if card.get("needs", "") == "sorted" and order != "sorted":
			var message := "%s needs a sorted volley, and %s left it unsorted." % [card.get("name", "?"), culprit]
			warnings.append({"index": index, "message": message})
		if card.has("makes"):
			order = card.makes
			culprit = card.get("name", "?")
		var after := hooked(order, hooks, "after", card, catalog)
		if after.by != "":
			order = after.order
			culprit = after.by
	return warnings


# --- Casting ----------------------------------------------------------------------------------------------------------


## Casts a program: pay its cards' mana, let faster foes act, then land its bolts (or time out). Returns a refusal
## ({code, message}) or {}.
static func cast(
	state: Dictionary, battle: Dictionary, spell: Dictionary, outcome: Dictionary, catalog: Dictionary
) -> Dictionary:
	var cost := cost_of(state, spell, catalog)
	if cost > int(battle.mana):
		return {
			"code": "not-enough-mana", "message": "%s needs %d mana and you have %d." % [spell.name, cost, battle.mana]
		}
	play(state, battle, spell, outcome, catalog)
	return {}


## Everything a cast does once it is paid for, from the faster foes to the relics after it lands. The cast and its
## preview both play it, the preview on a copy (`rehearsal`: no win or loss is declared), so the preview is the cast.
## Returns {landed (the resolver's result, empty when nothing landed), gained (block the cast and the relics after it
## added), lethal (the run ends during the cast)}.
## LEARN: one function for both paths is what keeps them equal; two copies of the same steps drifted apart before
## (a faster foe acted in the cast but not in the preview, docs/PHASE2.md P2-01).
static func play(
	state: Dictionary,
	battle: Dictionary,
	spell: Dictionary,
	outcome: Dictionary,
	catalog: Dictionary,
	rehearsal := false
) -> Dictionary:
	var played := {"landed": {}, "gained": 0, "lethal": false}
	var cost := cost_of(state, spell, catalog)
	if not battle.has("acted"):
		battle.acted = []
	var stage_list := stages(state, outcome.get("work", []), catalog) if outcome.ok else ([] as Array[Dictionary])
	var work := total_work(stage_list)
	battle.max_work = maxi(int(battle.get("max_work", 0)), work)
	var relics := ProgramRelics.modifiers(state, catalog)
	ProgramMemory.begin(state, battle, catalog)
	var context := landing_context(state, battle, spell, stage_list, work, catalog)
	# What ran is what the cards spent afterwards may do (ProgramDeck.spend), so it is kept with the battle.
	battle.last_ran = context.ran
	battle.mana -= cost
	for spent: String in ["free_program", "free_cards"]:
		battle.erase(spent)
	(battle.cast as Array).append(spell.id)
	battle.casts += 1
	state.stats.casts += 1
	state.stats.mana_spent += cost
	# The program aimed at the foes alive when it ran; a faster foe may summon, swap or fall before it lands.
	var aimed_at := alive_uids(battle)
	# Faster foes first: each acts once, now, and not again at the end of the turn.
	for foe in faster_foes(state, battle, work, catalog):
		var tempo := tempo_of(foe, state, catalog)
		var text := "%s moves first: %d ops is faster than your %d." % [foe.name, tempo, work]
		Shardrun.record(state, {"kind": "tempo", "foe": foe.uid, "amount": tempo, "text": text})
		(battle.acted as Array).append(foe.uid)
		ShardrunBattle.foe_act(state, battle, foe, catalog)
		if int(state.integrity) <= 0:
			played.lethal = true
			if not rehearsal:
				ShardrunBattle.lose(state)
			return played
	if not outcome.ok:
		var crashed := "%s crashes: %s" % [spell.name, outcome.reason]
		Shardrun.record(state, {"kind": "fizzle", "spell": spell.id, "amount": cost, "text": crashed})
		remember(battle, spell.shards, [])
		ProgramMemory.row(battle, 0, 0, relics)
		return played
	var limit := budget(state, catalog)
	if work > limit:
		var text := "%s runs out of time: %d ops against a budget of %d." % [spell.name, work, limit]
		Shardrun.record(state, {"kind": "timeout", "spell": spell.id, "amount": work, "cost": cost, "text": text})
		remember(battle, spell.shards, [])
		ProgramMemory.row(battle, 0, 0, relics)
		state.integrity = maxi(0, int(state.integrity) - int(relics.timeout_integrity))
		if relics.timeout_refund:
			battle.mana += cost
			battle.block += maxi(0, work - limit) / 64
		if int(state.integrity) <= 0:
			played.lethal = true
			if not rehearsal:
				ShardrunBattle.lose(state)
		return played
	var bolts := reaim(normalize(outcome.bolts, catalog, bolt_limit(state, catalog)), aimed_at, battle)
	state.stats.bolts += bolts.size()
	var noun := "bolt" if bolts.size() == 1 else "bolts"
	var cast_text := "%s: %d %s, %d ops, %d mana." % [spell.name, bolts.size(), noun, work, cost]
	Shardrun.record(state, {"kind": "cast", "spell": spell.id, "amount": cost, "work": work, "text": cast_text})
	var curse := int(ShardrunRules.relic_modifiers(state, catalog).cast_burn)
	if curse > 0:
		state.integrity = maxi(0, int(state.integrity) - curse)
		Shardrun.record(state, {"kind": "curse", "amount": curse, "text": "The cast burns %d Integrity." % curse})
	var landed := resolve(state, battle, bolts, catalog, context)
	for spent: String in ["double_next", "gc_seed"]:
		battle.erase(spent)
	var landed_block := int(battle.block)
	remember(battle, spell.shards, bolts)
	battle.last_work = work
	ShardrunBattle.cast_defense(state, battle, catalog)
	ProgramRelics.after_cast(state, battle, context.ran, int(landed.kills), catalog)
	ProgramDeck.after_cast(state, battle, int(landed.dealt), catalog)
	played.landed = landed
	played.gained = int(landed.block) + int(battle.block) - landed_block
	state.stats.damage += int(landed.dealt)
	var by_spell: Dictionary = state.stats.damage_by_spell
	by_spell[spell.id] = int(by_spell.get(spell.id, 0)) + int(landed.dealt)
	state.stats.best_cast = maxi(int(state.stats.best_cast), int(landed.dealt) + int(landed.wasted))
	if int(state.integrity) <= 0:
		played.lethal = true
		if not rehearsal:
			ShardrunBattle.lose(state)
	elif not rehearsal and (battle.foes as Array).all(func(foe: Dictionary) -> bool: return int(foe.hp) == 0):
		ShardrunBattle.win(state, battle, catalog)
	return played


## What the landing needs to know about the program that made the bolts: how many cards it ran of how many slots, its
## slowest class, which foes it out-sped (they have not moved yet when it lands), and the cards that ran (`ran`).
## The cards that ran are judged now, before any faster foe acts, as the sandbox judged them.
static func landing_context(
	state: Dictionary,
	battle: Dictionary,
	spell: Dictionary,
	stage_list: Array[Dictionary],
	work: int,
	catalog: Dictionary
) -> Dictionary:
	var out_sped: Array = []
	for foe: Dictionary in battle.foes:
		if int(foe.hp) > 0 and tempo_of(foe, state, catalog) >= work:
			out_sped.append(foe.uid)
	return {
		"cards": (spell.shards as Array).duplicate(),
		"capacity": int(spell.capacity),
		"speed": slowest_class(stage_list),
		"out_sped": out_sped,
		"ran": executed_cards(battle, spell.shards, stage_list, catalog),
		"work": work,
	}


## A pruned step is attempted in the sandbox but its output and side effects are discarded.
static func executed_cards(battle: Dictionary, ids: Array, stage_list: Array[Dictionary], catalog: Dictionary) -> Array:
	var candidates := ran_cards(battle, ids, catalog)
	if stage_list.is_empty() or not stage_list.any(func(stage: Dictionary) -> bool: return stage.has("slot")):
		return candidates
	var accepted := {}
	for stage in stage_list:
		if not stage.get("pruned", false):
			accepted[int(stage.slot)] = true
	var out: Array = []
	var slot := 0
	for id: String in ids:
		if ProgramDeck.is_import(id, catalog):
			if id in candidates:
				out.append(id)
			continue
		if accepted.has(slot) and id in candidates:
			out.append(id)
		slot += 1
	return out


## The cards of a program that actually run: its imports, and its steps up to a living Unreachable's `return`. Dead
## code after it still costs mana and is still spent, but whatever a card does by running (cards it makes, a global it
## spends, block per card, the Mutator's tests) it does only if it ran (docs/PHASE2.md P2-06).
static func ran_cards(battle: Dictionary, card_ids: Array, catalog: Dictionary) -> Array:
	var cut := ProgramGuardians.dead_from(battle)
	if cut < 0:
		return card_ids.duplicate()
	var out: Array = []
	var step := 0
	for id: String in card_ids:
		if ProgramDeck.is_import(id, catalog):
			out.append(id)
			continue
		if step < cut:
			out.append(id)
		step += 1
	return out


## Program output bolts: {power, element, foe?, block?, stash?, from_index?, pivot?, idle?}, at most max_bolts. `idle` is
## short-lived provenance for scheduler spacers; the matching guard consumes it before landing.
static func bolt_limit(state: Dictionary, catalog: Dictionary) -> int:
	return maxi(int(config_of(catalog).max_bolts), int(ProgramRelics.modifiers(state, catalog).max_bolts))


static func normalize(raw: Array, catalog: Dictionary, limit := -1) -> Array[Dictionary]:
	var config := config_of(catalog)
	var out: Array[Dictionary] = []
	for candidate: Variant in raw.slice(0, int(config.max_bolts) if limit < 0 else limit):
		if not candidate is Dictionary:
			continue
		var bolt: Dictionary = candidate
		var power: Variant = bolt.get("power", 0)
		var element: Variant = bolt.get("element", "none")
		var clean := {
			"power": clampi(int(power) if (power is int or power is float) else 0, 0, int(config.max_power)),
			"element": element if element in ShardrunSchemas.ELEMENTS else "none",
		}
		var foe: Variant = bolt.get("foe")
		if (foe is int or foe is float) and int(foe) >= 0:
			clean.foe = int(foe)
		for flag: String in ["block", "stash", "from_index", "pivot", "idle"]:
			if bolt.get(flag, false) == true:
				clean[flag] = true
		out.append(clean)
	return out


## The uids of a battle's living foes, in order: what a program's `foe` indices count in.
static func alive_uids(battle: Dictionary) -> Array:
	var out: Array = []
	for foe: Dictionary in battle.foes:
		if int(foe.hp) > 0:
			out.append(foe.uid)
	return out


## Bolts aimed by index into the foes alive when the program ran (`aimed_at`, their uids), re-aimed at the same foes in
## the battle as it is now, after faster foes acted: a summon or a swap moves the indices, not the aim (P2-08). A bolt
## aimed at a foe that has since fallen flies at the front foe, as one aimed past the last does.
static func reaim(bolts: Array[Dictionary], aimed_at: Array, battle: Dictionary) -> Array[Dictionary]:
	var now := alive_uids(battle)
	if now == aimed_at or aimed_at.is_empty():
		return bolts
	for bolt in bolts:
		if not bolt.has("foe"):
			continue
		var at := int(bolt.foe)
		var uid: String = aimed_at[at] if at < aimed_at.size() else aimed_at[0]
		bolt.foe = maxi(0, now.find(uid))
	return bolts


## Lands bolts in order. A bolt with `block` shields you; any other flies at the foe its `foe` names (an index into
## the foes alive when the program ran), or at the front foe. Bolts at a foe already down are wasted, as is damage
## past a foe's HP: aiming is what the strike cards are for. A foe the program out-sped takes more (Initiative). Relics
## change the landing (ProgramRelics): what the bolts weigh, factors for the whole program, a stronger Initiative,
## overkill that flows on, waste turned into block. `context` is landing_context's. Returns {dealt, wasted, block,
## kills}.
static func resolve(
	state: Dictionary, battle: Dictionary, bolts: Array[Dictionary], catalog: Dictionary, context := {}
) -> Dictionary:
	return ProgramLanding.resolve(state, battle, bolts, catalog, context)


## The uids of the foes a volley's attacking bolts are aimed at (a bolt without an aim, or aimed past the last, flies
## at the front foe).
static func targets(bolts: Array[Dictionary], alive: Array) -> Dictionary:
	var aimed := {}
	for bolt in bolts:
		if bolt.get("block", false) or bolt.get("stash", false) or alive.is_empty():
			continue
		var at := int(bolt.get("foe", 0))
		aimed[(alive[at] if at < alive.size() else alive[0]).uid] = true
	return aimed


## A deadlocked foe's partner while it still holds the lock: standing, and not hit by this program. {} when the foe
## can be hurt (no lock, its partner broken, or both hit at once).
static func lock_holder(foe: Dictionary, alive: Array, targeted: Dictionary) -> Dictionary:
	var foe_trait: Dictionary = foe.get("trait", {})
	if foe_trait.get("kind") != "deadlock":
		return {}
	for other: Dictionary in alive:
		if other.id == foe_trait.partner and int(other.hp) > 0 and not targeted.has(other.uid):
			return other
	return {}


## The Quine's fixed point (docs/NewEnemies.md): a program of exactly the cards, in the order, of the last one that ran
## cannot hurt it.
static func fixed_point(foe: Dictionary, context: Dictionary) -> bool:
	if (foe.get("trait", {}) as Dictionary).get("kind") != "quine" or not foe.has("last_cards"):
		return false
	# LEARN: `==` on two Arrays compares their contents in order, not whether they are the same object, so the same
	# cards in a new list still match, and the same cards in another order do not.
	return foe.last_cards == context.get("cards", [])


## A Quine remembers the last program that ran: its cards (the fixed point) and the shape of what it fired, which its
## `reprint` sends back (ShardrunBattle.foe_act). A program that crashed or timed out ran and printed nothing.
static func remember(battle: Dictionary, cards: Array, bolts: Array[Dictionary]) -> void:
	var attacking := 0
	var ward := 0
	for bolt in bolts:
		if bolt.get("block", false):
			ward += int(bolt.power)
		else:
			attacking += 1
	for foe: Dictionary in battle.foes:
		if (foe.get("trait", {}) as Dictionary).get("kind") == "quine":
			foe.echo = {"bolts": attacking, "ward": ward}
			foe.last_cards = cards.duplicate()


## What each living Quine about to reprint would send back after this program: [{name, hits, power}]. A Quine faster
## than the program (named in `faster`) reprints the one before it (`before`, the battle as it stands); a slower one
## reprints this one (`after`, the battle once this program has landed).
static func reprints(before: Dictionary, after: Dictionary, faster: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in (after.foes as Array).size():
		var foe: Dictionary = before.foes[index] if before.foes[index].name in faster else after.foes[index]
		var intents: Array = foe.get("intents", [])
		if int(after.foes[index].hp) <= 0 or intents.is_empty():
			continue
		var intent: Dictionary = intents[int(foe.intent_index) % intents.size()]
		if intent.kind != "reprint":
			continue
		var hits := mini(int((foe.get("echo", {}) as Dictionary).get("bolts", 0)), int(intent.max))
		out.append({"name": foe.name, "hits": hits, "power": int(intent.power)})
	return out


## Overkill flowing on (a relic): what is left after `from` falls goes into the next foe still standing, through its
## shield, and so on. Returns what is still left once no foe stands.
static func _flow(
	state: Dictionary, alive: Array, from: Dictionary, spill: int, element: String, shape: Dictionary
) -> Dictionary:
	var start := alive.find(from)
	var step := 1
	var dealt := 0
	var exact: Array = []
	var damage_by := {}
	while spill > 0 and step < alive.size():
		var next: Dictionary = alive[(start + step) % alive.size()]
		step += 1
		if int(next.hp) == 0 or not flows_into(next):
			continue
		var blocked := mini(int(next.shield), spill)
		next.shield -= blocked
		spill -= blocked
		var taken := mini(spill, int(next.hp))
		next.hp -= taken
		spill -= taken
		dealt += taken
		damage_by[next.uid] = taken
		ProgramMemory.hit(state.battle, next, {"power": taken, "element": element}, taken)
		if int(next.hp) == 0 and spill == 0:
			exact.append(next.uid)
		var hit := {"kind": "hit", "foe": next.uid, "amount": taken, "element": element, "flowed": true}
		hit.merge(shape)
		hit.text = "The overflow runs on: %s takes %d." % [next.name, taken]
		Shardrun.record(state, hit)
		if int(next.hp) == 0:
			Shardrun.record(state, {"kind": "defeat", "foe": next.uid, "text": "%s breaks apart." % next.name})
			GuardianLanding.on_defeat(state, state.battle, next)
	return {"spill": spill, "dealt": dealt, "exact": exact, "damage": damage_by}


## Whether overflow can run on into a foe: only a plain one. A foe whose trait changes how damage lands (a guardian, its
## parts, a thick hide, a pattern ward) is passed over, so overflow never slips past its rules (docs/PHASE2.md P2-04).
## A shifting weakness only changes elements, which overflow does not carry.
static func flows_into(foe: Dictionary) -> bool:
	var kind: String = (foe.get("trait", {}) as Dictionary).get("kind", "")
	return kind in ["", "shifting-weakness"]


## What casting would do, worked out on a copy of the state: {cost, affordable, work, budget, timeout, speed,
## faster: [foe names], bolts, damage, wasted, block, kills, locked (bolts a deadlock held), misfire?}.
static func preview(state: Dictionary, spell_id: String, outcome: Dictionary, catalog: Dictionary) -> Dictionary:
	var battle: Dictionary = state.get("battle", {})
	var spell := Shardrun.spell_by_id(state, spell_id)
	if battle.is_empty() or spell.is_empty():
		return {}
	var cost := cost_of(state, spell, catalog)
	var stage_list := stages(state, outcome.get("work", []), catalog) if outcome.ok else ([] as Array[Dictionary])
	var work := total_work(stage_list)
	var limit := budget(state, catalog)
	var view := {
		"cost": cost,
		"affordable": not spell.id in battle.cast and cost <= int(battle.mana),
		"work": work,
		"budget": limit,
		"timeout": work > limit,
		"speed": speed_label(spell.shards, catalog),
		"faster": faster_foes(state, battle, work, catalog).map(func(foe: Dictionary) -> String: return foe.name),
		"stages": stage_list,
		"bolts": 0,
		"damage": 0,
		"wasted": 0,
		"block": 0,
		"kills": 0,
		"locked": 0,
	}
	var copy := state.duplicate(true)
	copy.log = []
	var shadow: Dictionary = copy.battle
	var played := play(copy, shadow, Shardrun.spell_by_id(copy, spell_id), outcome, catalog, true)
	view.lethal = played.lethal
	var notes: Array[String] = []
	if played.lethal:
		notes.append(
			(
				"A faster foe ends the run before this program lands."
				if played.landed.is_empty()
				else "The cast's burn takes your last Integrity."
			)
		)
	if not outcome.ok:
		view.misfire = outcome.reason
		view.notes = notes
		return view
	if view.timeout or played.landed.is_empty():
		view.notes = notes
		return view
	var landed: Dictionary = played.landed
	view.reprints = reprints(battle, shadow, view.faster)
	# What the guardians make of this program, before it runs (ADR-0026).
	notes.append_array(landed.notes)
	notes.append_array(GuardianLanding.telegraph(battle, shadow, spell.shards, stage_list, catalog))
	view.notes = notes
	view.bolts = normalize(outcome.bolts, catalog, bolt_limit(state, catalog)).size()
	view.damage = landed.dealt
	view.wasted = landed.wasted
	view.block = played.gained
	view.kills = landed.kills
	view.locked = landed.locked
	view.fixed = landed.fixed
	return view
