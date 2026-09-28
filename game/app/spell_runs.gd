class_name SpellRuns
extends RefCounted
## A battle's spells run in the sandbox, each run remembered by its exact input (the old server's run cache): the
## preview the player reads and the cast they make come from the same run of the same code, even when a shard is random.
## Every spell of a turn runs in one sandbox job, on a thread, while the game keeps drawing.
##
##   var runs := SpellRuns.new(catalog)
##   runs.warm(state)                                         # start the turn's spells, do not wait
##   var by_id: Dictionary = await runs.runs_for(state, state.spells)   # spell id -> run
##
## A run is SpellHarness's: {ok: true, bolts, trace, work, console} or {ok: false, reason, shard?, line?, trace,
## console}.

## A batch finished; anyone waiting on one of its spells looks again.
signal settled

## Finished runs remembered; a battle only ever needs a handful at a time.
const LIMIT := 256
const NO_RESULT := {"ok": false, "reason": "the spell produced nothing", "trace": [], "console": ""}

var catalog: Dictionary
var limits: SandboxJob
var _done: Dictionary = {}
var _order: Array[String] = []
var _flying: Dictionary = {}
## The latest run of each key that was not worth remembering (a timeout may be the machine's fault), for whoever was
## waiting on it.
var _last: Dictionary = {}


func _init(run_catalog: Dictionary) -> void:
	catalog = run_catalog
	limits = SandboxJob.new()
	var defaults: Dictionary = catalog.get("sandbox", {})
	if defaults.has("cpu_ms"):
		limits.time_ms = int(defaults.cpu_ms)
	if defaults.has("wall_ms"):
		limits.wall_ms = int(defaults.wall_ms)
	if defaults.has("mem_mb"):
		limits.memory_mb = int(defaults.mem_mb)
	if defaults.has("output_kb"):
		limits.output_kb = int(defaults.output_kb)


## Starts every spell of the battle in the background without waiting.
func warm(state: Dictionary) -> void:
	if state.has("battle"):
		runs_for(state, state.spells)


## A finished run for this spell in this state, or {} while it is still running or was never started.
func finished(state: Dictionary, spell: Dictionary) -> Dictionary:
	var input := input_for(state)
	if input.is_empty():
		return {}
	if _steps(spell).is_empty():
		return empty_run(input)
	return _done.get(key_of(state, spell, input), {})


## Runs for these spells against the state's battle: remembered ones at once, running ones awaited, the rest together
## in one job. Returns spell id -> run; {} outside a battle.
func runs_for(state: Dictionary, spells: Array) -> Dictionary:
	var input := input_for(state)
	var results := {}
	if input.is_empty():
		return results
	var missing: Array[Dictionary] = []
	var keys := {}
	for spell: Dictionary in spells:
		if _steps(spell).is_empty():
			results[spell.id] = empty_run(input)
			continue
		var key := key_of(state, spell, input)
		keys[spell.id] = key
		if _done.has(key):
			results[spell.id] = _done[key]
		elif not _flying.has(key):
			missing.append(spell)
	if not missing.is_empty():
		var batch: Dictionary = await _run_batch(String(state.language), missing, input, keys)
		results.merge(batch)
	for spell: Dictionary in spells:
		if results.has(spell.id):
			continue
		var key: String = keys[spell.id]
		while _flying.has(key):
			await settled
		results[spell.id] = _done.get(key, _last.get(key, NO_RESULT))
	return results


func _run_batch(language: String, spells: Array[Dictionary], input: Dictionary, keys: Dictionary) -> Dictionary:
	var runs := {}
	var programs: Array[Dictionary] = []
	for spell in spells:
		var shards: Array[Dictionary] = []
		var steps := _steps(spell)
		for shard_id: String in steps:
			if catalog.shards.has(shard_id):
				shards.append(catalog.shards[shard_id])
		if shards.size() != steps.size():
			runs[spell.id] = _failure("one of its shards no longer exists")
		else:
			programs.append({"id": spell.id, "shards": shards})
	for program in programs:
		_flying[keys[program.id]] = true
	if not programs.is_empty():
		var job_limits := limits
		# The hooks travel as card ids in the input (its key); the harness needs their code.
		var job_input := input.duplicate()
		var hooks: Array = []
		for hook: Dictionary in input.get("hooks", []):
			var hooked := hook.duplicate()
			hooked.card = catalog.shards.get(hook.card, {})
			hooks.append(hooked)
		job_input.hooks = hooks
		var ran: Dictionary = await Background.run(
			func() -> Dictionary: return SpellHarness.run(language, programs, job_input, job_limits)
		)
		runs.merge(ran)
	for program in programs:
		var key: String = keys[program.id]
		_flying.erase(key)
		_remember(key, runs.get(program.id, NO_RESULT))
	settled.emit()
	return runs


func _remember(key: String, run: Dictionary) -> void:
	# Only runs whose ending the code decided (it finished, or one of its shards raised) are kept; a timeout or a
	# sandbox failure may be the machine's fault, and deserves another try.
	if not run.ok and not run.has("shard"):
		_last[key] = run
		return
	_done[key] = run
	_order.append(key)
	if _order.size() > LIMIT:
		_done.erase(_order.pop_front())


## What a spell starts from in this state's battle: one plain bolt, the battle as shard code sees it, and the limits.
func input_for(state: Dictionary) -> Dictionary:
	var battle: Dictionary = state.get("battle", {})
	if battle.is_empty():
		return {}
	var balance: Dictionary = catalog.balance
	if state.get("playstyle") == "program":
		# A program starts from its seed volley, and may grow up to the program limit (ADR-0012). Its cards see the
		# modules imported and the fight's globals, and its imports' hooks run around the cards of their role
		# (ADR-0018).
		var config := ProgramRules.config_of(catalog)
		var seen := ShardrunRules.shard_battle(state, battle)
		seen.imports = ProgramDeck.modules(state, catalog)
		seen.globals = (battle.get("globals", {}) as Dictionary).duplicate()
		return {
			"bolts": ProgramRules.seed(state, catalog),
			"battle": seen,
			"limit": int(config.max_bolts),
			"trace_limit": int(balance.trace_bolts),
			"count": true,
			"hooks": ProgramRelics.modifiers(state, catalog).hooks,
		}
	return {
		"bolts": [ShardrunRules.base_bolt(balance)],
		"battle": ShardrunRules.shard_battle(state, battle),
		"limit": int(balance.max_pipeline_bolts),
		"trace_limit": int(balance.trace_bolts),
	}


## The cards of a spell that run as its steps: a program's imports are lines at its top, not steps (ADR-0018).
func _steps(spell: Dictionary) -> Array:
	return ProgramDeck.steps(spell.shards, catalog)


static func key_of(state: Dictionary, spell: Dictionary, input: Dictionary) -> String:
	return JsJson.stringify([state.language, spell.shards, input])


static func empty_run(input: Dictionary) -> Dictionary:
	return {"ok": true, "bolts": (input.bolts as Array).duplicate(true), "trace": [], "work": 0, "console": ""}


## A run as the rules take it for a cast. The rules bill the work, so they get the steps rather than a total: only they
## know each shard's complexity class.
static func to_outcome(run: Dictionary) -> Dictionary:
	if not run.ok:
		return {"ok": false, "reason": run.reason}
	var work: Array = []
	for step: Dictionary in run.trace:
		work.append({"shard": step.shard, "given": step.given, "returned": step.get("returned", step.given)})
	return {"ok": true, "bolts": run.bolts, "work": work}


static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "trace": [], "console": ""}
