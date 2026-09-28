class_name ProgramSchemas
extends RefCounted
## The Shardrun's program content (ADR-0012): each card of `packs/<pack>/programs/cards/` and the pack's
## `programs.jsonc` (paradigms, draft, basics, budget, foe tempos). Checked like the rest of the content (ADR-0004), and
## their references checked against each other and against the foes and relics of the Shardrun catalog.

## How a card's work grows with its input size n (ProgramRules.work_units). "pseudo" is O(n·H): n times the front
## foe's HP, the table of a knapsack.
const COMPLEXITIES := ["constant", "logarithmic", "linear", "linearithmic", "quadratic", "exponential", "pseudo"]
## What a card does, shown on its face: makes bolts, changes them, arranges them, aims them, or guards with them.
const ROLES := ["source", "shape", "order", "strike", "guard"]
## What a card needs of the volley it is given, and what it leaves: "sorted" is weakest first.
const ORDERS := ["sorted", "unsorted"]
## A relic's tier, weakest first: tier 1 is a small nudge, tier 5 changes how a run is played. Loot tables weigh them
## (programs.jsonc `relic_tiers`), so an elite can offer only rare or better.
const TIERS := ["common", "uncommon", "rare", "epic", "legendary"]


static func bolt() -> Dictionary:
	return (
		Schema
		. object(
			{
				"power": Schema.INT,
				"element": Schema.one_of(ShardrunSchemas.ELEMENTS),
				"foe": Schema.optional(Schema.int_min(0)),
				"block": Schema.optional(Schema.BOOL),
			}
		)
	)


static func card() -> Dictionary:
	var example := (
		Schema
		. object(
			{
				"name": Schema.TEXT,
				"bolts": Schema.list_of(bolt()),
				"battle": Schema.optional(ShardrunSchemas.shard_battle()),
				"expect": Schema.list_of(bolt()),
			}
		)
	)
	var function := {
		"type": "text",
		"pattern": "^[a-z][a-z0-9_]*$",
		"pattern_message": "must be a lowercase snake_case function name",
	}
	return (
		Schema
		. object(
			{
				"id": Schema.ID,
				"name": Schema.TEXT,
				"rarity": Schema.one_of(ShardrunSchemas.SHARD_RARITIES),
				# A card may borrow the picture of an old shard by that shard's id; without it, its own id names it.
				"art": Schema.optional(Schema.ID),
				"cost": Schema.int_range(0, 9),
				"paradigm": Schema.ID,
				"role": Schema.one_of(ROLES),
				"complexity": Schema.one_of(COMPLEXITIES),
				"big_o": Schema.optional(Schema.TEXT),
				"cap_n": Schema.optional(Schema.int_min(1)),
				# An O(n·H) card whose table has a fixed height H (a ward aiming at 12 block) instead of the front foe's HP.
				"height": Schema.optional(Schema.int_min(1)),
				# A worse class on some input: quick sort with its first bolt as pivot is O(n²) on a volley already sorted.
				"worst_case":
				Schema.optional(
					Schema.object({"input": Schema.one_of(ORDERS), "complexity": Schema.one_of(COMPLEXITIES)})
				),
				"needs": Schema.optional(Schema.one_of(ORDERS)),
				"makes": Schema.optional(Schema.one_of(ORDERS)),
				"summary": Schema.TEXT,
				"function": function,
				"code": Schema.record(Schema.TEXT, [], "^(%s)$" % "|".join(ShardrunSchemas.LANGUAGES)),
				"draftable": Schema.with_default(Schema.BOOL, true),
				"forge":
				Schema.optional(
					Schema.object({"into": Schema.ID, "verb": Schema.one_of(["upgrade", "repair", "optimize"])})
				),
				"examples": Schema.list_of(example, null, 1),
			}
		)
	)


## A program relic (`packs/<pack>/programs/relics/`): its tier and its effects. The kinds are the Shardrun's that work
## on a program (block, mana, healing, capacity...) and the program's own (ProgramRelics): the seed, work, tempo, the
## budget, and what the volley does when it lands.
static func relic() -> Dictionary:
	var positive := ShardrunSchemas.POSITIVE
	var factor := {"type": "number", "positive": true, "max": 10.0}
	var effect := (
		Schema
		. union(
			{
				"turn-block": {"amount": positive},
				"heal-after-fight": {"amount": positive},
				"max-integrity": {"add": positive},
				"cast-block": {"amount": positive},
				"weak-bonus": {"add": factor},
				"retain-block": {"fraction": Schema.RATIO},
				"spell-capacity": {"add": positive},
				"mana-per-turn": {"add": Schema.INT},
				"damage-multiplier": {"factor": factor},
				"cast-burn": {"amount": positive},
				"turn-burn": {"amount": positive},
				"hold": {"add": positive},
				"opening-draw": {"add": positive},
				"hand-size": {"add": positive},
				"bolt-power": {"add": Schema.NUMBER},
				"seed-bolts": {"count": positive, "power": positive},
				"seed-power": {"add": positive},
				"first-turn-mana": {"add": positive},
				"element-power": {"add": positive},
				"free-first-work": {},
				"work-factor": {"factor": factor},
				"role-complexity": {"role": Schema.one_of(ROLES), "complexity": Schema.one_of(COMPLEXITIES)},
				"role-cost": {"role": Schema.one_of(ROLES), "cost": Schema.int_range(0, 9)},
				"duplicate-free": {},
				"cron": {"every": Schema.int_range(2, 9)},
				"tempo": {"add": Schema.INT},
				"budget": {"add": Schema.INT},
				"budget-factor": {"factor": factor},
				"sorted-landing": {"add": positive},
				"mono-element": {"factor": factor},
				"wasted-to-block": {"fraction": Schema.RATIO},
				"overkill-flows": {},
				"small-program": {"max_cards": positive, "factor": factor},
				"full-program": {"factor": factor},
				"fast-program": {"complexity": Schema.one_of(COMPLEXITIES), "factor": factor},
				"jit": {},
				"initiative": {"factor": factor},
				"kill-mana": {"amount": positive, "max": positive},
				"kill-heal": {"amount": positive},
				"block-per-card": {"amount": positive},
				"strongest-mult": {"factor": factor},
				"echo": {},
				"all-elements": {},
			}
		)
	)
	return (
		Schema
		. object(
			{
				"id": Schema.ID,
				"name": Schema.TEXT,
				"tier": Schema.one_of(TIERS),
				# The picture's id (shardrun/relic-<icon>); a relic borrowed from Spellforge keeps its old one.
				"icon": Schema.optional(Schema.ID),
				"summary": Schema.TEXT,
				"flavor": Schema.TEXT,
				"effects": Schema.list_of(effect, null, 1),
				"cursed": Schema.optional(Schema.BOOL),
				"art_note": Schema.optional(Schema.TEXT),
			}
		)
	)


static func config() -> Dictionary:
	var paradigm := (
		Schema
		. object(
			{
				"id": Schema.ID,
				"name": Schema.TEXT,
				"tier": Schema.TEXT,
				"colour": Schema.TEXT,
				"summary": Schema.TEXT,
				"signature": Schema.list_of(Schema.ID, null, 1),
				"pool": Schema.list_of(Schema.ID, null, 1),
			}
		)
	)
	return (
		Schema
		. object(
			{
				"seed": Schema.list_of(bolt(), null, 1),
				"program": Schema.object({"name": Schema.TEXT, "capacity": Schema.int_range(1, 9)}),
				"budget": Schema.int_min(1),
				"max_power": Schema.int_min(1),
				"max_bolts": Schema.int_min(1),
				"draft":
				(
					Schema
					. object(
						{
							"paradigms_offered": Schema.int_range(1, 6),
							"rounds": Schema.int_range(0, 12),
							"pack_size": Schema.int_range(1, 6),
						}
					)
				),
				"basics": Schema.list_of(Schema.ID, null, 1),
				"paradigms": Schema.list_of(paradigm, null, 1),
				"neutral": Schema.list_of(Schema.ID, null, 1),
				"tempo_default": Schema.int_min(1),
				"tempo": Schema.record(Schema.int_min(1)),
				# Where relics are found, and how likely each tier is there. A tier missing from a table never drops there.
				"relic_tiers":
				Schema.record(
					Schema.record({"type": "number", "min": 0.0}, [], "^(%s)$" % "|".join(TIERS)),
					["treasure", "elite", "boss"]
				),
				# Foe HP by layer for a program run (the Shardrun's own layers keep theirs for Spellforge). Missing: theirs.
				"foe_hp": Schema.optional(Schema.list_of({"type": "number", "positive": true}, null, 1)),
				# What a bolt of the wrong element does against a pattern ward in a program run (Spellforge keeps its own).
				"pattern_off": Schema.optional({"type": "number", "min": 0.0, "max": 1.0}),
			}
		)
	)


## Cross-references: every card a config names exists (and is draftable where it is drafted), every paradigm a card
## names exists, forges lead to cards, tempos name foes, relics exist. `file` is the config's, for the diagnostics.
static func check(catalog: Dictionary, file: String, diagnostics: Array[Dictionary]) -> void:
	var programs: Dictionary = catalog.programs
	var config: Dictionary = programs.config
	var cards: Dictionary = programs.cards
	var paradigm_ids: Array = (config.paradigms as Array).map(func(p: Dictionary) -> String: return p.id)
	var named := func(list: Array, where: String, draftable: bool) -> void:
		for id: String in list:
			if not cards.has(id):
				_error(diagnostics, 'unknown card "%s" in %s' % [id, where], file)
			elif draftable and not bool(cards[id].draftable):
				_error(diagnostics, 'card "%s" in %s is not draftable' % [id, where], file)
	named.call(config.basics, "basics", false)
	named.call(config.neutral, "neutral", true)
	for paradigm: Dictionary in config.paradigms:
		named.call(paradigm.signature, "%s's signature" % paradigm.id, false)
		named.call(paradigm.pool, "%s's pool" % paradigm.id, true)
	for card: Dictionary in cards.values():
		if card.paradigm != "neutral" and not card.paradigm in paradigm_ids:
			_error(diagnostics, 'card "%s" names an unknown paradigm "%s"' % [card.id, card.paradigm], file)
		var forge: Dictionary = card.get("forge", {})
		if forge.has("into") and not cards.has(forge.into):
			_error(diagnostics, 'card "%s" forges into an unknown card "%s"' % [card.id, forge.into], file)
		for language: String in ShardrunChecks.LANGUAGES:
			if not (card.code as Dictionary).has(language):
				_error(diagnostics, 'card "%s" has no %s code' % [card.id, language], file)
	for foe_id: String in config.tempo:
		if not catalog.foes.has(foe_id):
			_error(diagnostics, 'tempo names an unknown foe "%s"' % foe_id, file)
	var relics: Dictionary = programs.get("relics", {})
	for where: String in config.relic_tiers:
		var reachable := false
		for relic: Dictionary in relics.values():
			if (
				not relic.get("cursed", false)
				and float((config.relic_tiers[where] as Dictionary).get(relic.tier, 0.0)) > 0
			):
				reachable = true
		if not reachable:
			_error(diagnostics, "no relic of the tiers %s offers" % where, file)


static func _error(diagnostics: Array[Dictionary], message: String, file: String) -> void:
	diagnostics.append({"severity": "error", "code": "reference", "message": message, "file": file})
