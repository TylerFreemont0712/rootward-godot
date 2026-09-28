class_name ShardrunSchemas
extends RefCounted
## The shapes of Shardrun content, with the old zod schemas' rules and defaults (ProgramMe packages/content-schema/
## src/shardrun.ts and balance.ts). Every key a shard's code sees is a single word, so the same names read naturally
## in JSON, Python and JavaScript.

const ELEMENTS := ["none", "fire", "frost", "spark"]
const TARGETS := ["front", "back", "weakest", "strongest", "all"]
const COMPLEXITIES := ["constant", "linear", "linearithmic", "quadratic"]
const WORK_CURVES := ["log", "sqrt", "linear"]
const SHARD_RARITIES := ["common", "uncommon", "rare"]
const RELIC_RARITIES := ["common", "uncommon", "rare", "boss"]
const PLAYSTYLES := ["spellbook", "deck"]
const ROOM_KINDS := ["fight", "elite", "rest", "forge", "treasure"]
const FOE_SIZES := ["small", "medium", "large", "huge", "colossal"]
const AMBIENCES := ["dust", "spores", "embers"]
const LANGUAGES := ["python", "javascript", "typescript", "bash", "sql", "go", "rust", "c", "cpp"]
const POSITIVE := {"type": "int", "min": 1}
const NON_NEGATIVE := {"type": "int", "min": 0}


static func element() -> Dictionary:
	return Schema.one_of(ELEMENTS)


static func bolt() -> Dictionary:
	return (
		Schema
		. object(
			{
				"power": Schema.NUMBER,
				"element": element(),
				"target": Schema.one_of(TARGETS),
				"pierce": Schema.BOOL,
				"ward": Schema.BOOL,
				"mult": Schema.with_default(Schema.NUMBER, 1),
			}
		)
	)


static func shard_battle() -> Dictionary:
	var foe := (
		Schema
		. object(
			{
				"name": Schema.TEXT,
				"hp": Schema.INT,
				"max": Schema.INT,
				"shield": Schema.INT,
				"weak": Schema.list_of(element()),
				"resist": Schema.list_of(element()),
			}
		)
	)
	var me := Schema.object({"hp": Schema.INT, "max": Schema.INT, "block": Schema.INT, "mana": Schema.INT})
	return Schema.object({"turn": POSITIVE, "me": me, "foes": Schema.list_of(foe)})


## `shards/<id>.jsonc`; the loader adds `code` from `<id>.py` and `<id>.js` beside it.
static func shard() -> Dictionary:
	var example := (
		Schema
		. object(
			{
				"name": Schema.TEXT,
				"bolts": Schema.list_of(bolt()),
				"battle": Schema.optional(shard_battle()),
				"expect": Schema.list_of(bolt()),
			}
		)
	)
	var function := {
		"type": "text",
		"pattern": "^[a-z][a-z0-9_]*$",
		"pattern_message": "must be a lowercase snake_case function name",
	}
	var code := Schema.record(Schema.TEXT, [], "^(%s)$" % "|".join(LANGUAGES))
	return (
		Schema
		. object(
			{
				"id": Schema.ID,
				"name": Schema.TEXT,
				"rarity": Schema.one_of(SHARD_RARITIES),
				"cost": Schema.int_range(0, 9),
				"complexity": Schema.with_default(Schema.one_of(COMPLEXITIES), "linear"),
				"summary": Schema.TEXT,
				"art_note": Schema.optional(Schema.TEXT),
				"function": function,
				"code": code,
				"tags": Schema.list_of(Schema.TAG, []),
				"draftable": Schema.with_default(Schema.BOOL, true),
				"forge":
				Schema.optional(Schema.object({"into": Schema.ID, "verb": Schema.one_of(["upgrade", "repair"])})),
				"curse": Schema.optional(Schema.object({"integrity": POSITIVE})),
				"examples": Schema.list_of(example, null, 1),
			}
		)
	)


static func foe() -> Dictionary:
	var intent := (
		Schema
		. union(
			{
				"strike": {"power": POSITIVE},
				"multi": {"power": POSITIVE, "times": Schema.int_range(2, 6)},
				"shield": {"amount": POSITIVE},
				"stoke": {},
				"heal": {"amount": POSITIVE},
			}
		)
	)
	var foe_trait := (
		Schema
		. union(
			{
				"nullify-first": {},
				"thick-hide": {"threshold": POSITIVE},
				"shifting-weakness": {"cycle": Schema.list_of(element(), null, 2)},
				"pattern-ward": {"pattern": Schema.list_of(element(), null, 2)},
			}
		)
	)
	return (
		Schema
		. object(
			{
				"id": Schema.ID,
				"name": Schema.TEXT,
				"sprite": Schema.ID,
				"mirror": Schema.optional(Schema.BOOL),
				"size": Schema.with_default(Schema.one_of(FOE_SIZES), "medium"),
				"hp": POSITIVE,
				"weak": Schema.list_of(element(), []),
				"resist": Schema.list_of(element(), []),
				"trait": Schema.optional(foe_trait),
				"intents": Schema.list_of(intent, null, 1),
				"flavor": Schema.TEXT,
			}
		)
	)


static func relic() -> Dictionary:
	var condition := (
		Schema
		. union(
			{
				"volley-size": {"min": POSITIVE, "max": POSITIVE},
				"elements": {"count": Schema.int_range(1, 3)},
				"element": {"element": element()},
				"ward": {"value": Schema.BOOL},
				"pierce": {},
				"target": {"target": Schema.one_of(TARGETS)},
				"turn": {"min": POSITIVE},
				"hurt": {"fraction": Schema.RATIO},
				"block": {"min": POSITIVE},
				"after-ward": {},
				"mixed-roles": {},
			}
		)
	)
	var positive_number := {"type": "number", "positive": true}
	var effect := (
		Schema
		. union(
			{
				"conditional-mult": {"when": condition, "factor": {"type": "number", "positive": true, "max": 10.0}},
				"retain-block": {"fraction": Schema.RATIO},
				"cast-block": {"amount": POSITIVE},
				"cast-burn": {"amount": POSITIVE},
				"turn-burn": {"amount": POSITIVE},
				"cost-tax": {"amount": POSITIVE},
				"bolt-power": {"add": Schema.NUMBER},
				"bolt-mult": {"add": Schema.NUMBER},
				"damage-multiplier": {"factor": positive_number},
				"weak-bonus": {"add": positive_number},
				"mana-per-turn": {"add": Schema.INT},
				"first-cast-discount": {"amount": POSITIVE},
				"turn-block": {"amount": POSITIVE},
				"heal-after-fight": {"amount": POSITIVE},
				"bolt-mult-factor": {"factor": positive_number},
				"mult-per-cast": {"add": positive_number},
				"work-billing": {"curve": Schema.one_of(WORK_CURVES)},
				"bolt-cap": {"add": POSITIVE},
				"spell-capacity": {"add": POSITIVE},
				"max-integrity": {"add": POSITIVE},
				"spell-slot": {"add": POSITIVE},
				"hand-size": {"add": POSITIVE},
				"hold": {"add": POSITIVE},
				"opening-draw": {"add": POSITIVE},
				"draw-on-cast": {"min_cards": POSITIVE, "draw": POSITIVE},
				"reshuffle-block": {"amount": POSITIVE},
				"small-deck-power": {"below": POSITIVE, "per_card": POSITIVE},
				"add-cards": {"cards": Schema.list_of(Schema.ID, null, 1)},
			}
		)
	)
	return (
		Schema
		. object(
			{
				"id": Schema.ID,
				"name": Schema.TEXT,
				"rarity": Schema.one_of(RELIC_RARITIES),
				"icon": Schema.ID,
				"summary": Schema.TEXT,
				"flavor": Schema.TEXT,
				"effects": Schema.list_of(effect, null, 1),
				"cursed": Schema.optional(Schema.BOOL),
				"art_note": Schema.optional(Schema.TEXT),
				"playstyles": Schema.optional(Schema.list_of(Schema.one_of(PLAYSTYLES), null, 1)),
			}
		)
	)


## A layer of the Salvage: its map, its look and sound, how hard its foes are, and who is met in it. A program run
## can add layers of its own after the Shardrun's (programs.jsonc `layers`).
static func layer() -> Dictionary:
	var capacity := Schema.int_range(1, 8)
	var foe_groups := Schema.list_of(Schema.list_of(Schema.ID, null, 1, 4), null, 1)
	return (
		Schema
		. object(
			{
				"id": Schema.ID,
				"name": Schema.TEXT,
				"flavor": Schema.TEXT,
				"backdrop": Schema.ID,
				"boss_backdrop": Schema.optional(Schema.ID),
				"ambience": Schema.with_default(Schema.one_of(AMBIENCES), "dust"),
				"boss_ambience": Schema.optional(Schema.one_of(AMBIENCES)),
				"music": Schema.optional(Schema.ID),
				"battle_music": Schema.optional(Schema.ID),
				"boss_music": Schema.optional(Schema.ID),
				"rest_music": Schema.optional(Schema.ID),
				"rows": Schema.int_range(3, 15),
				"columns": Schema.int_range(2, 7),
				"paths": Schema.int_range(1, 8),
				"fixed_rows": Schema.with_default(Schema.record(Schema.one_of(ROOM_KINDS), [], "^-?\\d+$"), {}),
				"weights": Schema.record({"type": "number", "min": 0.0}, ROOM_KINDS),
				"elite_from_row": Schema.with_default(NON_NEGATIVE, 3),
				"foe_hp": Schema.with_default({"type": "number", "positive": true}, 1),
				"encounters": Schema.object({"fight": foe_groups, "elite": foe_groups, "boss": foe_groups}),
				"boss_spell": Schema.optional(Schema.object({"name": Schema.TEXT, "capacity": capacity})),
			}
		)
	)


## `shardrun/run.jsonc`: the loadout a run starts with, its difficulties, its layers, and its rewards.
static func run_config() -> Dictionary:
	var capacity := Schema.int_range(1, 8)
	var shard_weights := Schema.record({"type": "number", "min": 0.0}, SHARD_RARITIES)
	var relic_weights := Schema.record({"type": "number", "min": 0.0}, RELIC_RARITIES)
	var layer_schema := layer()
	var difficulty := (
		Schema
		. object(
			{
				"id": Schema.ID,
				"name": Schema.TEXT,
				"summary": Schema.TEXT,
				"show_summaries": Schema.BOOL,
				"show_predictions": Schema.BOOL,
				"foe_hp": {"type": "number", "positive": true},
			}
		)
	)
	var start_spell := Schema.object({"name": Schema.TEXT, "capacity": capacity, "shards": Schema.list_of(Schema.ID)})
	var start := (
		Schema
		. object(
			{
				"spells": Schema.list_of(start_spell, null, 1, 4),
				"inventory": Schema.list_of(Schema.ID, []),
				"relics": Schema.list_of(Schema.ID, []),
			}
		)
	)
	var deck_spell := Schema.object({"name": Schema.TEXT, "capacity": capacity})
	return (
		Schema
		. object(
			{
				"start": start,
				"spell_slots":
				Schema.optional(Schema.object({"names": Schema.list_of(Schema.TEXT, null, 1), "capacity": capacity})),
				"deck":
				Schema.optional(
					Schema.object(
						{"spells": Schema.list_of(deck_spell, null, 1, 4), "cards": Schema.list_of(Schema.ID, null, 1)}
					)
				),
				"difficulties": Schema.list_of(difficulty, null, 1),
				"layers": Schema.list_of(layer_schema, null, 1),
				"rewards":
				(
					Schema
					. object(
						{
							"shards":
							Schema.object({"fight": shard_weights, "elite": shard_weights, "boss": shard_weights}),
							"relics":
							Schema.object({"elite": relic_weights, "treasure": relic_weights, "boss": relic_weights}),
						}
					)
				),
			}
		)
	)


## The `shardrun` section of balance.jsonc.
static func balance() -> Dictionary:
	var income := Schema.object({"base": POSITIVE, "per_layer": NON_NEGATIVE})
	var work_billing := Schema.object(
		{"curve": Schema.one_of(WORK_CURVES), "per_mana": POSITIVE, "log_base": {"type": "number", "min": 1.1}}
	)
	var deck := (
		Schema
		. object(
			{
				"hand_size": POSITIVE,
				"opening_draw": NON_NEGATIVE,
				"hold": NON_NEGATIVE,
				"mana_per_turn": income,
				"min_cards": POSITIVE,
			}
		)
	)
	return (
		Schema
		. object(
			{
				"integrity_start": POSITIVE,
				"mana_per_turn": income,
				"spell_base_cost": NON_NEGATIVE,
				"work_billing": work_billing,
				"base_bolt_power": POSITIVE,
				"bolt_cap": Schema.object({"base": POSITIVE, "per_layer": NON_NEGATIVE, "max": POSITIVE}),
				"max_pipeline_bolts": POSITIVE,
				"max_bolt_power": POSITIVE,
				"max_bolt_mult": {"type": "number", "min": 1.0},
				"max_foe_hp": POSITIVE,
				"weak_multiplier": {"type": "number", "min": 1.0},
				"resist_multiplier": Schema.RATIO,
				"scatter_multiplier": Schema.RATIO,
				"pattern_off_multiplier": Schema.RATIO,
				"rest_heal_fraction": Schema.RATIO,
				"reward_choices": POSITIVE,
				"elite_relic_choices": NON_NEGATIVE,
				"treasure_relic_choices": POSITIVE,
				"treasure_curse_chance": Schema.optional(Schema.RATIO),
				"boss_relic_choices": POSITIVE,
				"max_spells": POSITIVE,
				"max_spell_capacity": POSITIVE,
				"layer_heal_fraction": Schema.RATIO,
				"trace_bolts": POSITIVE,
				"deck": deck,
			}
		)
	)


## The `sandbox_defaults` section of balance.jsonc: the limits every job runs under.
static func sandbox_defaults() -> Dictionary:
	return (
		Schema
		. object(
			{
				"wall_ms": POSITIVE,
				"cpu_ms": POSITIVE,
				"mem_mb": POSITIVE,
				"pids": POSITIVE,
				"output_kb": POSITIVE,
				"max_concurrent": POSITIVE,
			}
		)
	)
