class_name ProgramViews
extends RefCounted
## A program run's numbers for the screen (ADR-0012), from the rules' own preview: what the Program costs, how much work
## it does and at what speed, who moves before it lands, what the code panel warns about, and (when the difficulty and
## the options show predictions) what its bolts will do.


## {program: true, cost, affordable, work, budget, timeout, speed, stages: [{card, n, given, work}], lint: [{index,
##  message}], race: [...], base: {bolts}, steps: [{shard, given, returned, n, work, bolts}], console, revealed,
##  misfire?: {reason, shard?, line?}, result?: {bolts, damage, block, wasted, kills}}
static func run_view(
	state: Dictionary, spell: Dictionary, run: Dictionary, reveal: bool, catalog: Dictionary
) -> Dictionary:
	var preview := ProgramRules.preview(state, spell.id, SpellRuns.to_outcome(run), catalog)
	var work := int(preview.get("work", 0))
	var stages: Array = preview.get("stages", [])
	var view := {
		"program": true,
		"cost": ProgramRules.cost_of(spell, catalog),
		"affordable": bool(preview.get("affordable", false)),
		"work": work,
		"budget": ProgramRules.budget(catalog),
		"timeout": bool(preview.get("timeout", false)),
		"speed": ProgramRules.speed_label(spell.shards, catalog),
		"stages": stages,
		"lint": ProgramRules.lint(spell.shards, catalog),
		"race": race(state, work, catalog),
		"base": {"bolts": (ProgramRules.config_of(catalog).seed as Array).duplicate(true)},
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
	var steps: Array = []
	var trace: Array = run.get("trace", [])
	for index in trace.size():
		var step: Dictionary = trace[index]
		var stage: Dictionary = stages[index] if index < stages.size() else {}
		(
			steps
			. append(
				{
					"shard": step.shard,
					"given": int(step.given),
					"returned": int(step.get("returned", step.given)),
					"n": int(stage.get("n", step.given)),
					"work": int(stage.get("work", 0)),
					"bolts": ProgramRules.normalize(step.get("bolts", []), catalog),
					# Measured in the sandbox: each loop's rounds by its line in the card's code, and how often the
					# card's function was entered (more than once: it is recursive).
					"loops": step.get("loops", {}),
					"calls": int(step.get("calls", 1)),
					# The whole volley after the stage, as measured: its total power and how many bolts of each element.
					"power": float(step.get("power", 0.0)),
					"elements": step.get("elements", {}),
				}
			)
		)
	view.steps = steps
	if reveal and run.ok and not view.timeout and not preview.is_empty():
		view.result = {
			"bolts": preview.bolts,
			"damage": preview.damage,
			"block": preview.block,
			"wasted": preview.wasted,
			"kills": preview.kills,
		}
	return view


## Every living foe's tempo against the program's work, quickest first: [{name, uid, tempo, first}], `first` when it
## will act before the program lands.
static func race(state: Dictionary, work: int, catalog: Dictionary) -> Array[Dictionary]:
	var battle: Dictionary = state.get("battle", {})
	var acted: Array = battle.get("acted", [])
	var out: Array[Dictionary] = []
	for foe: Dictionary in battle.get("foes", []):
		if int(foe.hp) <= 0:
			continue
		var tempo := ProgramRules.tempo_of(foe, catalog)
		out.append({"name": foe.name, "uid": foe.uid, "tempo": tempo, "first": tempo < work and not foe.uid in acted})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.tempo) < int(b.tempo))
	return out


## The lines the code panel draws for a program, each call noted with its complexity class and, once the sandbox has
## measured it, its n and work; a call the lint flags is marked.
static func code_lines(language: String, card_ids: Array, view: Dictionary, catalog: Dictionary) -> Array[Dictionary]:
	var lines := ProgramSource.lines(language, card_ids, catalog)
	var steps: Array = view.get("steps", [])
	var flagged := {}
	for warning: Dictionary in view.get("lint", ProgramRules.lint(card_ids, catalog)):
		flagged[int(warning.index)] = true
	for line in lines:
		if line.kind != "call":
			continue
		var slot: int = line.slot
		var card: Dictionary = catalog.shards.get(line.card, {})
		var note := ShardrunViews.complexity(card)
		if slot < steps.size() and steps[slot].shard == line.card:
			note += "   n %d · %d ops" % [int(steps[slot].n), int(steps[slot].work)]
		line.note = note
		line.note_colour = UiTheme.FAINT
		if flagged.has(slot):
			line.warn = true
			line.note_colour = UiTheme.WARN
	return lines
