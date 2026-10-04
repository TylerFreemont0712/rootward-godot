extends SceneTree
## Runs the worked examples of the cards named in ROOTWARD_CPP_ONLY in C++ (scripts/try-cpp.sh). Prints every failure,
## and "C++ ok: N cards" when there are none.


func _initialize() -> void:
	var only := OS.get_environment("ROOTWARD_CPP_ONLY").split(",", false)
	var catalog: Dictionary = ContentLoader.load_shardrun().catalog
	var programs: Dictionary = (catalog.get("programs", {}) as Dictionary).get("cards", {})
	var picked := {"shards": {}, "programs": {"cards": {}}}
	var missing := 0
	# An id can name a program card and a Spellforge shard both (fork): whichever has C++ is tried.
	for id in only:
		var found := false
		if (programs.get(id, {}).get("code", {}) as Dictionary).has("cpp"):
			picked.programs.cards[id] = programs[id]
			found = true
		if (catalog.shards.get(id, {}).get("code", {}) as Dictionary).has("cpp"):
			picked.shards[id] = catalog.shards[id]
			found = true
		if not found:
			print("missing: %s has no C++ code (or no such card)" % id)
			missing += 1
	var languages: Array[String] = [SandboxJob.CPP]
	var failures := ShardExamples.check(picked, languages)
	for diagnostic: Dictionary in failures:
		print(diagnostic.message)
	if failures.is_empty() and missing == 0:
		print("C++ ok: %d cards" % only.size())
	quit(0 if failures.is_empty() and missing == 0 else 1)
