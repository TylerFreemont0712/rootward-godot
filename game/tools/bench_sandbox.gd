extends SceneTree
## Times the sandbox: a trivial program, and a Shardrun turn (three spells of three real shards), in both languages.
##   godot --headless --path game -s res://tools/bench_sandbox.gd

const REPEATS := 15


func _initialize() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://test/fixtures/spells.json"))
	var shards := {}
	for shard: Dictionary in fixture.shards:
		shards[shard.id] = shard
	var spells: Array[Dictionary] = []
	for i in 3:
		var chain: Array = (fixture.spells as Array).filter(
			func(s: Dictionary) -> bool: return s.id == "chain-%d" % (i + 1)
		)
		var list: Array[Dictionary] = []
		for id: String in (chain[0] as Dictionary).shards:
			list.append(shards[id])
		spells.append({"id": "spell-%d" % i, "shards": list})
	var raw: Dictionary = fixture.inputs[0]
	var input := {"bolts": raw.bolts, "battle": raw.battle, "limit": int(raw.limit), "trace_limit": int(raw.traceLimit)}
	for language: String in SandboxJob.LANGUAGES:
		var entry := "main.py" if language == SandboxJob.PYTHON else "main.js"
		var hello := "print(1)" if language == SandboxJob.PYTHON else "console.log(1)"
		var first := _time(func() -> void: Sandbox.run(SandboxJob.of(language, {entry: hello}, entry)))
		var trivial := _median(func() -> void: Sandbox.run(SandboxJob.of(language, {entry: hello}, entry)))
		var turn := _median(func() -> void: SpellHarness.run(language, spells, input))
		print(
			(
				"%s: first run %d ms, trivial run %d ms (median), a turn of 3 spells %d ms (median)"
				% [language, first, trivial, turn]
			)
		)
	quit()


func _time(work: Callable) -> int:
	var started := Time.get_ticks_usec()
	work.call()
	return (Time.get_ticks_usec() - started) / 1000


func _median(work: Callable) -> int:
	var times: Array[int] = []
	for i in REPEATS:
		times.append(_time(work))
	times.sort()
	return times[REPEATS / 2]
