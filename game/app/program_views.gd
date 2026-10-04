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
		"cost": ProgramRules.cost_of(state, spell, catalog),
		"affordable": bool(preview.get("affordable", false)),
		"work": work,
		"budget": ProgramRules.budget(state, catalog),
		"timeout": bool(preview.get("timeout", false)),
		"speed": ProgramRules.speed_label(spell.shards, catalog),
		"stages": stages,
		"lint": ProgramRules.lint(spell.shards, catalog, ProgramRelics.modifiers(state, catalog).hooks),
		"race": race(state, work, catalog),
		"base": {"bolts": ProgramRules.seed(state, catalog)},
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
	view.card_ids = (spell.shards as Array).duplicate()
	view.steps = slot_steps(run.get("trace", []), stages, catalog)

	if reveal and run.ok and not view.timeout and not preview.is_empty():
		view.result = {
			"bolts": preview.bolts,
			"damage": preview.damage,
			"block": preview.block,
			"wasted": preview.wasted,
			"kills": preview.kills,
		}
	# A deadlock holding is telegraphed whatever the difficulty shows: it is the foe's rule, not a prediction.
	view.locked = int(preview.get("locked", 0))
	# So is a Quine's (docs/NewEnemies.md): the bolts its fixed point stops, and what its reprint will send back.
	view.fixed = int(preview.get("fixed", 0))
	view.reprints = preview.get("reprints", [])
	# So are the guardians' (ADR-0026): a loop's guard, a riddle, a prediction, dead code, a throw to catch.
	view.notes = preview.get("notes", [])
	return view


## Parts are separate measurements but one original slot on the table. The joined snapshot is presentation only;
## damage still comes exclusively from the run's final output and the shared resolver.
static func slot_steps(trace: Array, stages: Array, catalog: Dictionary) -> Array:
	var steps: Array = []
	for index in trace.size():
		var step: Dictionary = trace[index]
		var stage: Dictionary = stages[index] if index < stages.size() else {}
		var slot := int(step.get("slot", index))
		while steps.size() <= slot:
			steps.append(
				{"shard": "", "given": 0, "returned": 0, "n": 0, "work": 0, "calls": 0, "loops": {}, "parts": 0}
			)
		var joined: Dictionary = steps[slot]
		joined.shard = step.shard
		joined.given += int(step.given)
		joined.returned += int(step.get("returned", step.given))
		joined.n += int(stage.get("n", step.given))
		joined.work += int(stage.get("work", 0))
		joined.calls += int(step.get("calls", 1))
		joined.parts += 1
		joined.pruned = bool(joined.get("pruned", true)) and bool(step.get("pruned", false))
		for number: String in step.get("loops", {}):
			joined.loops[number] = int(joined.loops.get(number, 0)) + int(step.loops[number])
		joined.bolts = ProgramRules.normalize(step.get("joined", step.get("bolts", [])), catalog)
		joined.power = float(step.get("joined_power", step.get("power", 0.0)))
		joined.elements = step.get("joined_elements", step.get("elements", {}))
		if step.has("joined_returned"):
			joined.returned = int(step.joined_returned)
	return steps


## Every living foe's tempo against the program's work, quickest first: [{name, uid, tempo, first}], `first` when it
## will act before the program lands (the others the program lands before: they take Initiative's bonus).
static func race(state: Dictionary, work: int, catalog: Dictionary) -> Array[Dictionary]:
	var battle: Dictionary = state.get("battle", {})
	var acted: Array = battle.get("acted", [])
	var out: Array[Dictionary] = []
	for foe: Dictionary in battle.get("foes", []):
		if int(foe.hp) <= 0:
			continue
		var tempo := ProgramRules.tempo_of(foe, state, catalog)
		out.append({"name": foe.name, "uid": foe.uid, "tempo": tempo, "first": tempo < work and not foe.uid in acted})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.tempo) < int(b.tempo))
	return out


## The lines the code panel draws for a program, its imports at the top, each call noted with its complexity class and,
## once the sandbox has measured it, its n and work; a call the lint flags is marked.
static func code_lines(state: Dictionary, card_ids: Array, view: Dictionary, catalog: Dictionary) -> Array[Dictionary]:
	var hooks: Array = ProgramRelics.modifiers(state, catalog).hooks
	var seed: Array = (view.get("base", {}) as Dictionary).get("bolts", [])
	var imports := ProgramDeck.imports(state, catalog)
	var modifiers := ProgramRelics.modifiers(state, catalog)
	var body := {"depth": int(modifiers.recurse_depth), "rejoin_power": int(modifiers.rejoin_power)}
	var lines := ProgramSource.lines(String(state.language), card_ids, catalog, seed, imports, hooks, body)
	var steps: Array = view.get("steps", [])
	var flagged := {}
	for warning: Dictionary in view.get("lint", ProgramRules.lint(card_ids, catalog, hooks)):
		flagged[int(warning.index)] = true
	for line in lines:
		if line.kind != "call":
			continue
		var slot: int = line.slot
		var card: Dictionary = catalog.shards.get(line.card, {})
		var note := ShardrunViews.complexity(card)
		if slot < steps.size() and steps[slot].shard == line.card:
			note += "   n %d · %d ops" % [int(steps[slot].n), int(steps[slot].work)]
		if slot < steps.size() and steps[slot].get("pruned", false):
			note += "   " + Text.t("pruned")
		line.note = note
		line.note_colour = UiTheme.FAINT
		if flagged.has(slot):
			line.warn = true
			line.note_colour = UiTheme.WARN
		# After an Unreachable's `return` (ADR-0026) a call is dead code: it does not run.
		var cut := ProgramGuardians.dead_from(state.get("battle", {}))
		if cut >= 0 and slot >= cut:
			line.note = Text.f("dead code: after the return at slot %d", [cut + 1])
			line.note_colour = UiTheme.FAINT
			line.dead = true
	return lines
