class_name IssueSchemas
extends RefCounted
## The schemas of a program run's Issues and scripts (ProgramIssues, ProgramScripts), apart from ProgramSchemas to keep
## each file small.


## An Issue: an event with a tracker's look and a few choices, each a list of effects (ProgramIssues).
static func issue() -> Dictionary:
	return (
		Schema
		. object(
			{
				"id": Schema.ID,
				"name": Schema.TEXT,
				"title": Schema.TEXT,
				"labels": Schema.with_default(Schema.list_of(Schema.TEXT), []),
				"layers": Schema.with_default(Schema.list_of(Schema.int_range(0, 3)), []),
				"weight": Schema.with_default({"type": "number", "positive": true}, 1.0),
				"picture": Schema.optional(Schema.ID),
				"text": Schema.TEXT,
				"choices":
				(
					Schema
					. list_of(
						(
							Schema
							. object(
								{
									"label": Schema.TEXT,
									"needs":
									Schema.with_default(
										Schema.object({"cycles": Schema.with_default(Schema.int_min(0), 0)}),
										{"cycles": 0}
									),
									"effects": Schema.with_default(Schema.list_of(issue_effect()), []),
								}
							)
						),
						null,
						1
					)
				),
			}
		)
	)


## What an issue's choice does. `then`, `effects`, `right` and `wrong` hold effects of their own (checked in `check`).
static func issue_effect() -> Dictionary:
	var positive := ShardrunSchemas.POSITIVE
	var nested := Schema.with_default({"type": "any"}, [])
	return (
		Schema
		. union(
			{
				"gain-cycles": {"amount": positive},
				"lose-cycles": {"amount": positive},
				"lose-integrity": {"amount": positive},
				"heal": {"amount": positive},
				"heal-fraction": {"fraction": Schema.RATIO},
				"max-integrity": {"amount": Schema.INT},
				"gain-script":
				{
					"rarity": Schema.with_default(Schema.one_of(ProgramSchemas.SCRIPT_RARITIES), "common"),
					"count": Schema.with_default(positive, 1)
				},
				"gain-relic":
				{
					"tier": Schema.with_default(Schema.one_of(ProgramSchemas.TIERS + ["any", "rare-plus"]), "any"),
					"curse_chance": Schema.with_default(Schema.RATIO, 0.0)
				},
				"gain-relic-id": {"relic": Schema.ID},
				"gain-curse": {},
				"add-random-card":
				{
					"scope": Schema.one_of(["own", "neutral", "other", "any"]),
					"rarity": Schema.with_default(Schema.one_of(["any", "rare"]), "any"),
					"refactored": Schema.with_default(Schema.BOOL, false)
				},
				"upgrade-random": {"count": positive},
				"transform-random": {"count": positive},
				"transform-commons": {"lose_max": Schema.with_default(Schema.int_min(0), 0)},
				"pick":
				{
					"purpose":
					Schema.one_of(["remove", "upgrade", "transform", "duplicate", "trade", "remove-basic", "keep"]),
					"count": Schema.with_default(positive, 1),
					"then": nested,
				},
				"offer":
				{
					"scope": Schema.one_of(["own", "neutral", "other", "any", "chosen"]),
					"count": Schema.with_default(positive, 3),
					"refactored": Schema.with_default(Schema.BOOL, false)
				},
				"swap-focus": {},
				"copy-quiz-card": {},
				"pending": {"rooms": positive, "effects": nested},
				"boon": {"boon": Schema.one_of(["mana", "draw", "block", "intern"]), "fights": positive},
				"bounty": {"bounty": Schema.one_of(["one-program", "fast"]), "reward": positive},
				"fight": {},
				"quiz": {"quiz": Schema.one_of(ProgramQuiz.KINDS), "right": nested, "wrong": nested},
			}
		)
	)


## A script: a one-use command on the belt (ProgramScripts).
static func script() -> Dictionary:
	var positive := ShardrunSchemas.POSITIVE
	return (
		Schema
		. object(
			{
				"id": Schema.ID,
				"name": Schema.TEXT,
				"rarity": Schema.one_of(ProgramSchemas.SCRIPT_RARITIES),
				"price": positive,
				"summary": Schema.TEXT,
				"icon": Schema.optional(Schema.ID),
				"target": Schema.with_default(Schema.one_of(["none", "foe"]), "none"),
				"when": Schema.with_default(Schema.one_of(["fight", "anywhere"]), "fight"),
				"effect":
				(
					Schema
					. union(
						{
							"heal": {"amount": positive},
							"hand-card": {"card": Schema.ID},
							"reveal-intents": {},
							"foe-half": {},
							"draw": {"count": positive},
							"free-card": {},
							"revert": {"max": positive},
							"nice": {},
							"foe-damage": {"amount": positive},
							"trait-off": {},
							"double-next": {},
							"free-program": {},
							"gc": {},
							"stash-hand": {},
							"work-divide": {"divisor": Schema.int_range(2, 16)},
							"shed-curses": {},
						}
					)
				),
			}
		)
	)
