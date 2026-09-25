extends SceneTree
## Loads and checks all content, and runs every shard's and program card's worked examples in the sandbox
## (scripts/validate.sh).
## Exit code 1 when anything is an error.


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var loaded := ContentLoader.load_shardrun()
	var diagnostics: Array = loaded.diagnostics
	var catalog: Dictionary = loaded.catalog
	var executed := 0
	if loaded.ok and not OS.get_cmdline_user_args().has("--no-exec"):
		diagnostics.append_array(ShardExamples.check(catalog))
		var cards: Dictionary = (catalog.get("programs", {}) as Dictionary).get("cards", {})
		for shard: Dictionary in catalog.shards.values() + cards.values():
			executed += (shard.examples as Array).size()
	for diagnostic: Dictionary in diagnostics:
		print(ContentLoader.describe(diagnostic))
	var errors := diagnostics.filter(func(d: Dictionary) -> bool: return d.severity == "error").size()
	var warnings := diagnostics.size() - errors
	var counts := [
		(catalog.shards as Dictionary).size(),
		((catalog.get("programs", {}) as Dictionary).get("cards", {}) as Dictionary).size(),
		(catalog.relics as Dictionary).size(),
		(catalog.foes as Dictionary).size()
	]
	var line := "Loaded %d shards, %d program cards, %d relics, %d foes; ran %d worked examples in each language."
	print(line % (counts + [executed]))
	print("%d error(s), %d warning(s) in %.1fs" % [errors, warnings, (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if errors > 0 else 0)
