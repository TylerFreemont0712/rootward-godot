extends SceneTree
## The Mutator's census (ADR-0026, scripts/mutants.sh): runs every program card's mutants on its worked examples in both
## languages and writes the ones that still run to programs/mutants.jsonc, the only mutants a fight draws.

const OUT := "res://content/packs/core/programs/mutants.jsonc"


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var catalog: Dictionary = ContentLoader.load_shardrun().catalog
	var lines: Array[String] = [
		"// The Mutator's census (ADR-0026), written by scripts/mutants.sh: for every program card, the mutation operators",
		"// (ProgramMutants.OPERATORS, by index) whose mutant still runs all of the card's worked examples without crashing",
		"// or hanging. A fight only draws mutants from here. Re-run the script when a card's code changes.",
		"{",
	]
	var languages: Array[String] = [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]
	for l in languages.size():
		var language := languages[l]
		var census := ShardExamples.mutant_census(catalog, language)
		var ids: Array = census.keys()
		ids.sort()
		var kept := 0
		var tried := 0
		lines.append('  "%s": {' % language)
		for i in ids.size():
			var safe: Array = census[ids[i]]
			kept += safe.size()
			var card: Dictionary = catalog.programs.cards[ids[i]]
			for op in ProgramMutants.OPERATORS.size():
				var mutant := ProgramMutants.mutate(String(card.code.get(language, "")), language, op)
				if not mutant.is_empty() and int(mutant.op) == op:
					tried += 1
			var comma := "," if i < ids.size() - 1 else ""
			lines.append('    "%s": %s%s' % [ids[i], JSON.stringify(safe), comma])
		lines.append("  }%s" % ("," if l < languages.size() - 1 else ""))
		print("%s: %d of %d mutants run" % [language, kept, tried])
	lines.append("}")
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("wrote %s in %.1fs" % [OUT, (Time.get_ticks_msec() - started) / 1000.0])
	quit()
