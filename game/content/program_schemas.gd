class_name ProgramSchemas
extends RefCounted
## The Shardrun's program content (ADR-0012): each card of `packs/<pack>/programs/cards/` and the pack's
## `programs.jsonc` (paradigms, draft, basics, budget, foe tempos). Checked like the rest of the content (ADR-0004), and
## their references checked against each other and against the foes and relics of the Shardrun catalog.

## How a card's work grows with its input size n (ProgramRules.work_units). "pseudo" is O(n·H): n times the front
## foe's HP, the table of a knapsack.
const COMPLEXITIES := ["constant", "logarithmic", "linear", "linearithmic", "quadratic", "exponential", "pseudo"]
const ROLES := ["grow", "shape", "order", "strike", "guard"]
## What a card needs of the volley it is given, and what it leaves: "sorted" is weakest first.
const ORDERS := ["sorted", "unsorted"]


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
				"relics": Schema.list_of(Schema.ID, []),
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
	for relic_id: String in config.relics:
		if not catalog.relics.has(relic_id):
			_error(diagnostics, 'relics names an unknown relic "%s"' % relic_id, file)


static func _error(diagnostics: Array[Dictionary], message: String, file: String) -> void:
	diagnostics.append({"severity": "error", "code": "reference", "message": message, "file": file})
