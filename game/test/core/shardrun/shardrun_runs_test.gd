extends GdUnitTestSuite
## Whole seeded runs replayed against their recordings (game/test/fixtures/shardrun-runs.json.gz): every command,
## every refusal, every snapshot, every preview, and the final score, over the frozen rules catalog. Re-recording
## replays each run's commands and records what this engine does with them (Fixtures).

var catalog: Dictionary
var runs: Array


func before() -> void:
	catalog = Fixtures.load_json("shardrun-catalog")
	runs = (Fixtures.load_json_gz("shardrun-runs") as Dictionary).runs


func after() -> void:
	if Fixtures.updating():
		Fixtures.save_json_gz("shardrun-runs", {"runs": runs})


func test_every_run_replays_exactly() -> void:
	var failures: Array[String] = []
	var steps := 0
	for run: Dictionary in runs:
		var failure := _record(run) if Fixtures.updating() else _replay(run)
		steps += (run.steps as Array).size()
		if failure != "":
			failures.append(failure)
	assert_int(steps).is_greater(1000)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()


## Replays one run; returns the first mismatch, or "".
func _replay(run: Dictionary) -> String:
	var name := "%s (%s%s)" % [run.seed, run.playstyle, ", sandbox" if run.sandbox else ""]
	var options := {"seed": run.seed, "language": "python", "difficulty": run.difficulty}
	options.playstyle = run.playstyle
	options.sandbox = run.sandbox
	var state := Shardrun.start(catalog, options)
	var start := Fixtures.diff(state, Fixtures.snake(run.start))
	if start != "":
		return "%s start: %s" % [name, start]
	var map: Dictionary = Fixtures.snake(run.start).map
	var steps: Array = run.steps
	for i in steps.size():
		var step: Dictionary = steps[i]
		var command: Dictionary = Fixtures.snake(step.command)
		var where := "%s step %d (%s)" % [name, i, command.type]
		if step.has("preview"):
			var preview := ShardrunBattle.preview_cast(state, command.spell_id, command.outcome, catalog)
			var preview_diff := Fixtures.diff(preview, Fixtures.snake(step.preview), "preview")
			if preview_diff != "":
				return "%s: %s" % [where, preview_diff]
		var result := Shardrun.step(state, command, catalog)
		if step.has("error"):
			if result.ok:
				return "%s: accepted, but the recording refused it (%s)" % [where, step.error.code]
			var error_diff := Fixtures.diff(result.error, step.error, "error")
			if error_diff != "":
				return "%s: %s" % [where, error_diff]
			continue
		if not result.ok:
			return "%s: refused %s (%s)" % [where, result.error.code, result.error.message]
		state = result.state
		if step.has("map"):
			map = Fixtures.snake(step.map)
		var want: Dictionary = Fixtures.snake(step.state)
		want.map = map
		var state_diff := Fixtures.diff(state, want)
		if state_diff != "":
			return "%s: %s" % [where, state_diff]
	var score_diff := Fixtures.diff(ShardrunScore.score(state), run.score, "score")
	return "" if score_diff == "" else "%s: %s" % [name, score_diff]


## Re-records one run: its commands kept, and what this engine does with each in place of what was recorded. A step
## keeps the map only when it changed, as the recordings do.
func _record(run: Dictionary) -> String:
	var options := {"seed": run.seed, "language": "python", "difficulty": run.difficulty}
	options.playstyle = run.playstyle
	options.sandbox = run.sandbox
	var state := Shardrun.start(catalog, options)
	run.start = state.duplicate(true)
	var map: Variant = state.map
	for step: Dictionary in run.steps:
		var command: Dictionary = Fixtures.snake(step.command)
		step.command = command
		for key: String in ["error", "map", "state"]:
			step.erase(key)
		if step.has("preview"):
			step.preview = ShardrunBattle.preview_cast(state, command.spell_id, command.outcome, catalog)
		var result := Shardrun.step(state, command, catalog)
		if not result.ok:
			step.error = result.error
			continue
		state = result.state
		var snapshot: Dictionary = state.duplicate(true)
		if Fixtures.diff(snapshot.map, map) != "":
			map = snapshot.map
			step.map = map
		snapshot.erase("map")
		step.state = snapshot
	run.score = ShardrunScore.score(state)
	return ""
