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
	for index in trace.size():
		var step: Dictionary = trace[index]
		var card: Dictionary = catalog.shards.get(step.shard, {})
		order = hooked(order, m.hooks, "before", card, catalog).order
		# LEARN: n is the larger of the volley in and the volley out. A card that turns 7 bolts into 21 pairs did 21
		# pieces of work even though it was handed 7; counting only its input would make growing cards free.
		var n := maxi(int(step.given), int(step.get("returned", step.given)))
		var complexity := ProgramRelics.complexity(card, order, m)
		var height := int(card.get("height", front_need(state)))
		var work := work_units(complexity, n, int(card.get("cap_n", 0)), height)
		if (index == 0 and m.free_first_work) or (m.jit and step.shard in ran):
			work = 0
		work = floori(work * float(m.work_factor))
		out.append({"card": step.shard, "n": n, "given": int(step.given), "work": work, "complexity": complexity})
		if card.has("makes"):
			order = card.makes
		order = hooked(order, m.hooks, "after", card, catalog).order
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
		tempo = int((intents[at % intents.size()] as Dictionary).get("tempo", tempo))
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
	if not battle.has("acted"):
		battle.acted = []
	var stage_list := stages(state, outcome.get("work", []), catalog) if outcome.ok else ([] as Array[Dictionary])
	var work := total_work(stage_list)
	var context := landing_context(state, battle, spell, stage_list, work, catalog)
	battle.mana -= cost
	(battle.cast as Array).append(spell.id)
	battle.casts += 1
	state.stats.casts += 1
	state.stats.mana_spent += cost
	# Faster foes first: each acts once, now, and not again at the end of the turn.
	for foe in faster_foes(state, battle, work, catalog):
		var tempo := tempo_of(foe, state, catalog)
		var text := "%s moves first: %d ops is faster than your %d." % [foe.name, tempo, work]
		Shardrun.record(state, {"kind": "tempo", "foe": foe.uid, "amount": tempo, "text": text})
		(battle.acted as Array).append(foe.uid)
		ShardrunBattle.foe_act(state, battle, foe)
		if int(state.integrity) <= 0:
			ShardrunBattle.lose(state)
			return {}
	if not outcome.ok:
		var crashed := "%s crashes: %s" % [spell.name, outcome.reason]
		Shardrun.record(state, {"kind": "fizzle", "spell": spell.id, "amount": cost, "text": crashed})
		remember(battle, spell.shards, [])
		return {}
	var limit := budget(state, catalog)
	if work > limit:
		var text := "%s runs out of time: %d ops against a budget of %d." % [spell.name, work, limit]
		Shardrun.record(state, {"kind": "timeout", "spell": spell.id, "amount": work, "cost": cost, "text": text})
		remember(battle, spell.shards, [])
		return {}
	var bolts := normalize(outcome.bolts, catalog)
	state.stats.bolts += bolts.size()
	var noun := "bolt" if bolts.size() == 1 else "bolts"
	var cast_text := "%s: %d %s, %d ops, %d mana." % [spell.name, bolts.size(), noun, work, cost]
	Shardrun.record(state, {"kind": "cast", "spell": spell.id, "amount": cost, "work": work, "text": cast_text})
	var curse := int(ShardrunRules.relic_modifiers(state, catalog).cast_burn)
	if curse > 0:
		state.integrity = maxi(0, int(state.integrity) - curse)
		Shardrun.record(state, {"kind": "curse", "amount": curse, "text": "The cast burns %d Integrity." % curse})
	var landed := resolve(state, battle, bolts, catalog, context)
	remember(battle, spell.shards, bolts)
	ShardrunBattle.cast_defense(state, battle, catalog)
	ProgramRelics.after_cast(state, battle, spell.shards, int(landed.kills), catalog)
	ProgramDeck.after_cast(state, battle, int(landed.dealt), catalog)
	state.stats.damage += int(landed.dealt)
	var by_spell: Dictionary = state.stats.damage_by_spell
	by_spell[spell.id] = int(by_spell.get(spell.id, 0)) + int(landed.dealt)
	state.stats.best_cast = maxi(int(state.stats.best_cast), int(landed.dealt) + int(landed.wasted))
	if int(state.integrity) <= 0:
		ShardrunBattle.lose(state)
	elif (battle.foes as Array).all(func(foe: Dictionary) -> bool: return int(foe.hp) == 0):
		ShardrunBattle.win(state, battle, catalog)
	return {}


## What the landing needs to know about the program that made the bolts: how many cards it ran of how many slots, its
## slowest class, and which foes it out-sped (they have not moved yet when it lands).
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
	}


## Program output as bolts the rules accept: {power (whole, 0..max_power), element, foe?, block?}, at most max_bolts.
static func normalize(raw: Array, catalog: Dictionary) -> Array[Dictionary]:
	var config := config_of(catalog)
	var out: Array[Dictionary] = []
	for candidate: Variant in raw.slice(0, int(config.max_bolts)):
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
		if bolt.get("block", false) == true:
			clean.block = true
		out.append(clean)
	return out


## Lands bolts in order. A bolt with `block` shields you; any other flies at the foe its `foe` names (an index into
## the foes alive when the program ran), or at the front foe. Bolts at a foe already down are wasted, as is damage
## past a foe's HP: aiming is what the strike cards are for. A foe the program out-sped takes more (Initiative). Relics
## change the landing (ProgramRelics): what the bolts weigh, factors for the whole program, a stronger Initiative,
## overkill that flows on, waste turned into block. `context` is landing_context's. Returns {dealt, wasted, block,
## kills}.
static func resolve(
	state: Dictionary, battle: Dictionary, bolts: Array[Dictionary], catalog: Dictionary, context := {}
) -> Dictionary:
	var balance: Dictionary = catalog.balance
	var m := ShardrunRules.relic_modifiers(state, catalog)
	var relics := ProgramRelics.modifiers(state, catalog)
	var landing := ProgramRelics.landing(bolts, relics)
	var program_factor := ProgramRelics.program_factor(landing, context, relics)
	var hottest := ProgramRelics.strongest(landing) if float(relics.strongest_mult) != 1.0 else -1
	var out_sped: Array = context.get("out_sped", [])
	var first := initiative(state, catalog)
	var alive := (battle.foes as Array).filter(func(foe: Dictionary) -> bool: return int(foe.hp) > 0)
	var targeted := targets(landing, alive)
	var dealt := 0
	var wasted := 0
	var gathered := 0
	var locked := 0
	var fixed := 0
	for index in landing.size():
		var bolt: Dictionary = landing[index]
		var power := int(bolt.power) + int(m.bolt_power)
		var shape := {"bolt": index, "target": "front"}
		if bolt.get("block", false):
			battle.block += power
			gathered += power
			var ward := {
				"kind": "ward", "amount": power, "element": bolt.element, "text": "A ward gathers %d block." % power
			}
			ward.merge(shape)
			Shardrun.record(state, ward)
			continue
		if alive.is_empty():
			break
		var at := int(bolt.get("foe", 0))
		var foe: Dictionary = alive[at] if at < alive.size() else alive[0]
		if int(foe.hp) == 0:
			wasted += power
			var gone := {"kind": "wasted", "foe": foe.uid, "amount": power, "element": bolt.element}
			gone.merge(shape)
			gone.text = "%d power flies at %s, already down." % [power, foe.name]
			Shardrun.record(state, gone)
			continue
		var foe_trait: Dictionary = foe.get("trait", {})
		if foe_trait.get("kind") == "nullify-first" and not foe.nullified:
			foe.nullified = true
			var absorb := {"kind": "absorb", "foe": foe.uid, "element": bolt.element}
			absorb.merge(shape)
			absorb.text = "%s swallows the first bolt whole." % foe.name
			Shardrun.record(state, absorb)
			continue
		if fixed_point(foe, context):
			fixed += 1
			var same := {"kind": "absorb", "foe": foe.uid, "element": bolt.element, "word": "fixed point"}
			same.merge(shape)
			same.text = "%s recognises its own source: the same program cannot hurt it." % foe.name
			Shardrun.record(state, same)
			continue
		if foe_trait.get("kind") == "thick-hide" and power < int(foe_trait.threshold):
			var glance := {"kind": "glance", "foe": foe.uid, "element": bolt.element}
			glance.merge(shape)
			glance.text = "A %d-power bolt glances off %s." % [power, foe.name]
			Shardrun.record(state, glance)
			continue
		var holder := lock_holder(foe, alive, targeted)
		if not holder.is_empty():
			locked += 1
			var held := {"kind": "locked", "foe": foe.uid, "amount": power, "element": bolt.element}
			held.merge(shape)
			held.text = "%s holds its lock: this program never touches %s." % [foe.name, holder.name]
			Shardrun.record(state, held)
			continue
		var multiplier: float = m.damage_multiplier * program_factor
		if index == hottest:
			multiplier *= float(relics.strongest_mult)
		var first_strike: bool = foe.uid in out_sped
		if first_strike:
			multiplier *= first
		if foe_trait.get("kind") == "pattern-ward" and bolt.element != foe.get("pattern"):
			multiplier *= float(config_of(catalog).get("pattern_off", balance.pattern_off_multiplier))
		# A relic can make every bolt the element a foe is weak to (and then nothing resists it).
		var weak: bool = bolt.element in foe.weak or (relics.all_elements and not (foe.weak as Array).is_empty())
		var resisted: bool = not weak and bolt.element in foe.resist
		if weak:
			multiplier *= float(balance.weak_multiplier) + m.weak_bonus
		elif resisted:
			multiplier *= float(balance.resist_multiplier)
		var damage := floori(power * multiplier)
		var blocked := mini(int(foe.shield), damage)
		foe.shield -= blocked
		damage -= blocked
		var landed := mini(damage, int(foe.hp))
		foe.hp -= landed
		dealt += landed
		var hit := {"kind": "hit", "foe": foe.uid, "amount": landed, "element": bolt.element}
		hit.merge(shape)
		if first_strike and first != 1.0:
			hit.initiative = true
		if weak:
			hit.affinity = "weak"
		elif resisted:
			hit.affinity = "resist"
		if blocked > 0:
			hit.blocked = blocked
		if damage > landed:
			hit.overkill = damage - landed
		var shield_note := " (%d into its shield)" % blocked if blocked > 0 else ""
		var lead := "Initiative: " if hit.has("initiative") else ""
		hit.text = "%s%s takes %d%s." % [lead, foe.name, landed, shield_note]
		Shardrun.record(state, hit)
		if int(foe.hp) == 0:
			Shardrun.record(state, {"kind": "defeat", "foe": foe.uid, "text": "%s breaks apart." % foe.name})
		var spill := damage - landed
		if relics.overkill_flows:
			spill = _flow(state, alive, foe, spill, bolt.element, shape)
			dealt += (damage - landed) - spill
		wasted += spill
	if float(relics.wasted_to_block) > 0.0 and wasted > 0:
		var kept := floori(wasted * float(relics.wasted_to_block))
		if kept > 0:
			battle.block += kept
			gathered += kept
			var text := "The unused %d power is kept as block." % kept
			Shardrun.record(state, {"kind": "ward", "amount": kept, "element": "none", "text": text})
	var kills := alive.filter(func(foe: Dictionary) -> bool: return int(foe.hp) == 0).size()
	return {"dealt": dealt, "wasted": wasted, "block": gathered, "kills": kills, "locked": locked, "fixed": fixed}


## The uids of the foes a volley's attacking bolts are aimed at (a bolt without an aim, or aimed past the last, flies
## at the front foe).
static func targets(bolts: Array[Dictionary], alive: Array) -> Dictionary:
	var aimed := {}
	for bolt in bolts:
		if bolt.get("block", false) or alive.is_empty():
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
) -> int:
	var start := alive.find(from)
	var step := 1
	while spill > 0 and step < alive.size():
		var next: Dictionary = alive[(start + step) % alive.size()]
		step += 1
		if int(next.hp) == 0:
			continue
		var blocked := mini(int(next.shield), spill)
		next.shield -= blocked
		spill -= blocked
		var taken := mini(spill, int(next.hp))
		next.hp -= taken
		spill -= taken
		var hit := {"kind": "hit", "foe": next.uid, "amount": taken, "element": element, "flowed": true}
		hit.merge(shape)
		hit.text = "The overflow runs on: %s takes %d." % [next.name, taken]
		Shardrun.record(state, hit)
		if int(next.hp) == 0:
			Shardrun.record(state, {"kind": "defeat", "foe": next.uid, "text": "%s breaks apart." % next.name})
	return spill


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
	if not outcome.ok:
		view.misfire = outcome.reason
		return view
	if view.timeout:
		return view
	var copy := state.duplicate(true)
	copy.log = []
	var shadow: Dictionary = copy.battle
	var context := landing_context(copy, shadow, spell, stage_list, work, catalog)
	var bolts := normalize(outcome.bolts, catalog)
	var landed := resolve(copy, shadow, bolts, catalog, context)
	remember(shadow, spell.shards, bolts)
	view.reprints = reprints(battle, shadow, view.faster)
	view.bolts = bolts.size()
	view.damage = landed.dealt
	view.wasted = landed.wasted
	view.block = landed.block
	view.kills = landed.kills
	view.locked = landed.locked
	view.fixed = landed.fixed
	return view
