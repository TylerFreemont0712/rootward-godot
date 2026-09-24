class_name ShardrunViews
extends RefCounted
## What the screens show about a run, worked out from the state and the rules (the old server's views): a spell's run
## step by step, foe intents and traits in words, which rooms can be entered, what a forge offers. Pure functions, so
## a screen never decides anything; it only reads these.

const COMPLEXITY := {
	"constant": "O(1)",
	"linear": "O(n)",
	"linearithmic": "O(n log n)",
	"quadratic": "O(n²)",
}


## A spell's run for the screen. With `reveal`, every step says what its bolts would do if the spell ended there, by
## the rules' own resolution against this battle; without it, only the cost and any misfire are shown.
##   {cost, affordable, base: {bolts, outcome?}, steps: [{shard, given, returned, work, bolts, outcome}], console,
##    misfire?: {reason, shard?, line?}, result?: {bolts, damage, potential, block}}
static func spell_run_view(
	state: Dictionary, spell: Dictionary, run: Dictionary, reveal: bool, catalog: Dictionary
) -> Dictionary:
	var base := ShardrunRules.base_bolt(catalog.balance)
	var preview := ShardrunBattle.preview_cast(state, spell.id, SpellRuns.to_outcome(run), catalog)
	var view := {
		"cost": int(preview.get("cost", 0)),
		"affordable": bool(preview.get("affordable", false)),
		"base": {"bolts": [base]},
		"steps": [],
		"console": String(run.get("console", "")),
		"revealed": reveal,
	}
	if not run.ok:
		var misfire := {"reason": run.reason}
		if run.has("shard"):
			misfire.shard = run.shard
		if run.has("line"):
			misfire.line = int(run.line)
		view.misfire = misfire
	if not reveal:
		return view
	view.base = {"bolts": [base], "outcome": ShardrunBattle.preview_bolts(state, [base], catalog)}
	var steps: Array = []
	for step: Dictionary in run.get("trace", []):
		var shard: Dictionary = catalog.shards.get(step.shard, {})
		(
			steps
			. append(
				{
					"shard": step.shard,
					"given": int(step.given),
					"returned": int(step.returned),
					"work": ShardrunRules.work_units(shard.get("complexity", "linear"), float(step.given)),
					"bolts": display_bolts(step.bolts),
					"outcome": ShardrunBattle.preview_bolts(state, step.bolts, catalog),
				}
			)
		)
	view.steps = steps
	if run.ok and not preview.is_empty():
		view.result = {
			"bolts": preview.bolts, "damage": preview.damage, "potential": preview.potential, "block": preview.block
		}
	return view


## Bolts as the code view shows them: well-formed ones only, power and multiplier to two decimals.
static func display_bolts(raw: Array) -> Array:
	var shown: Array = []
	for candidate: Variant in raw:
		var bolt := ShardrunRules.parse_bolt(candidate)
		if bolt.is_empty():
			continue
		bolt.power = snappedf(float(bolt.power), 0.01)
		bolt.mult = snappedf(float(bolt.mult), 0.01)
		shown.append(bolt)
	return shown


## The foe's next move, in words. A stoked strike shows its doubled power.
static func intent_text(foe: Dictionary) -> String:
	var intents: Array = foe.get("intents", [])
	if intents.is_empty():
		return "Watching"
	var intent: Dictionary = intents[int(foe.intent_index) % intents.size()]
	match intent.kind:
		"strike":
			return "Strike for %d" % (int(intent.power) * (2 if foe.get("stoked", false) else 1))
		"multi":
			return "Strike %d times for %d" % [int(intent.times), int(intent.power)]
		"shield":
			return "Shield %d" % int(intent.amount)
		"stoke":
			return "Stoke: its next strike doubles"
		"heal":
			return "Heal %d" % int(intent.amount)
	return "Watching"


static func intent_kind(foe: Dictionary) -> String:
	var intents: Array = foe.get("intents", [])
	if intents.is_empty():
		return "strike"
	return (intents[int(foe.intent_index) % intents.size()] as Dictionary).kind


## A foe trait's name and what it does, or {} for a foe without one.
static func trait_view(foe: Dictionary) -> Dictionary:
	var foe_trait: Dictionary = foe.get("trait", {})
	match foe_trait.get("kind", ""):
		"nullify-first":
			return {"name": "Nullify", "text": "The first bolt that hits it each turn does nothing."}
		"thick-hide":
			return {"name": "Thick hide", "text": "Bolts under %d power glance off." % int(foe_trait.threshold)}
		"shifting-weakness":
			var cycle := ", then ".join(PackedStringArray(foe_trait.cycle))
			return {"name": "Shifting", "text": "Its weakness moves each turn: %s." % cycle}
		"pattern-ward":
			var pattern := ", ".join(PackedStringArray(foe_trait.pattern))
			return {"name": "Pattern ward", "text": "Only this turn's element in %s hits at full strength." % pattern}
	return {}


## Each room's place in the walk: "current", "visited", "open" (enterable now), "passed" or "ahead".
static func node_states(state: Dictionary) -> Dictionary:
	var open := {}
	if state.status == "map":
		for node: Dictionary in ShardrunMap.next_rooms(state.map, state.position):
			open[node.id] = true
	var current_row := -1
	for node: Dictionary in state.map.nodes:
		if node.id == state.position:
			current_row = int(node.row)
	var states := {}
	for node: Dictionary in state.map.nodes:
		if node.id == state.position:
			states[node.id] = "current"
		elif node.id in state.visited:
			states[node.id] = "visited"
		elif open.has(node.id):
			states[node.id] = "open"
		elif int(node.row) <= current_row:
			states[node.id] = "passed"
		else:
			states[node.id] = "ahead"
	return states


## The foes waiting in a room, by name, before it is entered.
static func room_foes(state: Dictionary, node: Dictionary, catalog: Dictionary) -> Array[Dictionary]:
	var foes: Array[Dictionary] = []
	var layer := ShardrunRules.layer_of(state, catalog)
	for foe_id: String in ShardrunRules.encounter_for(state.seed, node, layer):
		if catalog.foes.has(foe_id):
			foes.append(catalog.foes[foe_id])
	return foes


## What a forge can do right now: shards that can be reworked (one entry per kind), spells that can be widened, and the
## spell that could be bound ({} when none).
static func forge_options(state: Dictionary, catalog: Dictionary) -> Dictionary:
	var owned: Array[String] = []
	var carried: Array = []
	if state.playstyle == "deck":
		carried = state.deck
	else:
		for spell: Dictionary in state.spells:
			carried.append_array(spell.shards)
		carried.append_array(state.inventory)
	for shard_id: String in carried:
		var forge: Dictionary = (catalog.shards.get(shard_id, {}) as Dictionary).get("forge", {})
		if forge.has("into") and not shard_id in owned:
			owned.append(shard_id)
	var widen: Array[String] = []
	for spell: Dictionary in state.spells:
		if int(spell.capacity) < int(catalog.balance.max_spell_capacity):
			widen.append(spell.id)
	return {"shards": owned, "spells": widen, "bind": ShardrunRules.bindable_spell(state, catalog)}


static func rest_heal(state: Dictionary, catalog: Dictionary) -> int:
	return Shardrun.heal_amount(state, float(catalog.balance.rest_heal_fraction))


static func cursed_relics(state: Dictionary, catalog: Dictionary) -> Array[Dictionary]:
	var cursed: Array[Dictionary] = []
	for relic_id: String in state.relics:
		var relic: Dictionary = catalog.relics.get(relic_id, {})
		if relic.get("cursed", false):
			cursed.append(relic)
	return cursed


## The current foe intents' damage in total, for a warning next to the End turn button.
static func incoming(state: Dictionary) -> int:
	var total := 0
	for foe: Dictionary in (state.get("battle", {}) as Dictionary).get("foes", []):
		if int(foe.hp) <= 0:
			continue
		var intents: Array = foe.intents
		var intent: Dictionary = intents[int(foe.intent_index) % intents.size()]
		if intent.kind == "strike":
			total += int(intent.power) * (2 if foe.get("stoked", false) else 1)
		elif intent.kind == "multi":
			total += int(intent.power) * int(intent.times)
	return total


static func complexity(shard: Dictionary) -> String:
	return COMPLEXITY.get(shard.get("complexity", "linear"), "O(n)")
