class_name ShardrunSession
extends RefCounted
## One playstyle's run as the old server kept it (ShardrunService): the state, saved whole after every command; its
## spells run in the sandbox (SpellRuns); the rules (Shardrun) deciding everything else. Screens send commands here and
## draw what comes back; they never change a state themselves.
##
##   var session := ShardrunSession.new(catalog, SaveStore.new())
##   session.start("python", "beginner")
##   var result: Dictionary = await session.command({"type": "enter", "node_id": "l0-r0-c1"})
##   if result.ok: draw(result.before, result.state, result.replay)   else: say(result.error.message)
##
## Every command is awaited: a cast runs its spell in the sandbox first (or takes the run its preview came from).

## A command was accepted; the state is new.
signal changed

var catalog: Dictionary
var saves: SaveStore
var playstyle: String
var runs: SpellRuns
var state: Dictionary = {}
## A command is being worked out; another one waits its turn rather than racing it.
var busy := false


func _init(run_catalog: Dictionary, save_store: SaveStore, run_playstyle := "spellbook") -> void:
	catalog = run_catalog
	saves = save_store
	playstyle = run_playstyle
	runs = SpellRuns.new(catalog)


## Picks up the saved run, if there is one. `saves.problem` says why a save could not be used.
func load_saved() -> void:
	state = saves.load_run(playstyle)
	runs.warm(state)


func has_run() -> bool:
	return not state.is_empty()


func in_progress() -> bool:
	return has_run() and not state.status in Shardrun.ENDED


## Starts a new run, replacing the saved one. An empty seed picks a fresh one.
func start(language: String, difficulty: String, seed := "", sandbox := false) -> Dictionary:
	if seed == "":
		seed = Crypto.new().generate_random_bytes(8).hex_encode()
	var options := {
		"seed": seed, "language": language, "difficulty": difficulty, "playstyle": playstyle, "sandbox": sandbox
	}
	var before := state
	state = Shardrun.start(catalog, options)
	saves.save_run(playstyle, state)
	changed.emit()
	return {"ok": true, "before": before, "state": state, "replay": {}}


## Applies one command. Returns {ok: true, before, state, replay} or {ok: false, error: {code, message}}; `replay` is
## the cast's run step by step ({spell_id, shards, run}) for the code view, or {} for anything else.
## LEARN: a function that contains `await` is a coroutine: it pauses there, the game keeps drawing frames, and it
## carries on when the awaited thing is done. Callers must `await` it too, or they get the pause instead of the result.
## `busy` makes a second command wait for the first, so two quick clicks cannot both start from the same state.
func command(request: Dictionary) -> Dictionary:
	if state.is_empty():
		return Shardrun.refuse("no-run", "There is no run underway.")
	while busy:
		await changed
	busy = true
	var before := state
	var sent := request
	var replay := {}
	if request.type == "cast":
		var spell := Shardrun.spell_by_id(state, String(request.get("spell_id", "")))
		var battle: Dictionary = state.get("battle", {})
		if not spell.is_empty() and not battle.is_empty() and not spell.id in battle.cast:
			var by_id: Dictionary = await runs.runs_for(state, [spell])
			var run: Dictionary = by_id.get(spell.id, SpellRuns.NO_RESULT)
			sent = {"type": "cast", "spell_id": spell.id, "outcome": SpellRuns.to_outcome(run)}
			var view := ShardrunViews.spell_run_view(state, spell, run, true, catalog)
			replay = {"spell_id": spell.id, "shards": (spell.shards as Array).duplicate(), "run": view}
		else:
			# The rules refuse this cast before they look at an outcome, so nothing needs to run.
			sent = {"type": "cast", "spell_id": request.get("spell_id", ""), "outcome": {"ok": false, "reason": ""}}
	var result := Shardrun.step(state, sent, catalog)
	busy = false
	if not result.ok:
		changed.emit()
		return result
	state = result.state
	saves.save_run(playstyle, state)
	runs.warm(state)
	changed.emit()
	return {"ok": true, "before": before, "state": state, "replay": replay}


## Every spell's run view against the current battle, waiting for any still running: {revision, spells: {id: view}}.
## `predictions` is the player's option; the difficulty can still hide them.
func previews(predictions := true) -> Dictionary:
	var at := state
	if not at.has("battle"):
		return {"revision": at.get("revision", 0), "spells": {}}
	var reveal := predictions and show_predictions()
	var by_id: Dictionary = await runs.runs_for(at, at.spells)
	var views := {}
	for spell: Dictionary in at.spells:
		var run: Dictionary = by_id.get(spell.id, SpellRuns.NO_RESULT)
		views[spell.id] = ShardrunViews.spell_run_view(at, spell, run, reveal, catalog)
	return {"revision": at.revision, "spells": views}


func difficulty() -> Dictionary:
	return ShardrunRules.difficulty_of(catalog, String(state.get("difficulty", "")))


func show_predictions() -> bool:
	return bool(difficulty().get("show_predictions", true))


func show_summaries() -> bool:
	return bool(difficulty().get("show_summaries", true))


func score() -> Dictionary:
	return ShardrunScore.score(state) if has_run() else {}
