class_name ShardrunChecks
extends RefCounted
## Checks between Shardrun content files, which no single file's schema can see (the old validateShardrun): the run
## names shards, foes and relics that exist, every shard has code in both Shardrun languages, forges lead somewhere, and
## every reward pool can offer something.

const LANGUAGES: Array[String] = ["python", "javascript"]


static func check(catalog: Dictionary, run_file: String, diagnostics: Array[Dictionary]) -> void:
	var shards: Dictionary = catalog.shards
	var relics: Dictionary = catalog.relics
	var foes: Dictionary = catalog.foes
	var config: Dictionary = catalog.config
	for shard: Dictionary in shards.values():
		var file := "shard %s" % shard.id
		for language in LANGUAGES:
			if not (shard.code as Dictionary).has(language):
				_add(diagnostics, "error", "shard-language", 'shard "%s" has no %s code' % [shard.id, language], file)
		if shard.has("forge"):
			var into: String = shard.forge.into
			if into == shard.id:
				_add(diagnostics, "error", "shard-forge", 'shard "%s" cannot forge into itself' % shard.id, file)
			elif not shards.has(into):
				_add(
					diagnostics,
					"error",
					"unknown-shard",
					'shard "%s" forges into unknown shard "%s"' % [shard.id, into],
					file
				)

	var shard_ref := func(id: String, where: String) -> void:
		if not shards.has(id):
			_add(diagnostics, "error", "unknown-shard", '%s names unknown shard "%s"' % [where, id], run_file)
	for spell: Dictionary in config.start.spells:
		var held: Array = spell.shards
		if held.size() > int(spell.capacity):
			var message := (
				'starting spell "%s" holds %d shards but has room for %d' % [spell.name, held.size(), spell.capacity]
			)
			_add(diagnostics, "error", "spell-capacity", message, run_file)
		for id: String in held:
			shard_ref.call(id, 'starting spell "%s"' % spell.name)
	for id: String in config.start.inventory:
		shard_ref.call(id, "the starting inventory")
	for id: String in (config.get("deck", {}) as Dictionary).get("cards", []):
		shard_ref.call(id, "the deck playstyle's starting cards")
	for relic: Dictionary in relics.values():
		for effect: Dictionary in relic.effects:
			if effect.kind != "add-cards":
				continue
			for card: String in effect.cards:
				if not shards.has(card):
					var message := 'relic "%s" adds unknown shard "%s"' % [relic.id, card]
					_add(diagnostics, "error", "unknown-shard", message, "relic %s" % relic.id)
	for id: String in config.start.relics:
		if not relics.has(id):
			_add(diagnostics, "error", "unknown-relic", 'the starting relics name unknown relic "%s"' % id, run_file)
	var seen := {}
	for difficulty: Dictionary in config.difficulties:
		if seen.has(difficulty.id):
			_add(diagnostics, "error", "duplicate-id", 'difficulty "%s" is listed twice' % difficulty.id, run_file)
		seen[difficulty.id] = true
	for layer: Dictionary in config.layers:
		for kind: String in ["fight", "elite", "boss"]:
			for group: Array in layer.encounters[kind]:
				for foe: String in group:
					if not foes.has(foe):
						var message := 'layer "%s": a %s encounter names unknown foe "%s"' % [layer.id, kind, foe]
						_add(diagnostics, "error", "unknown-foe", message, run_file)
		if int(layer.paths) > int(layer.columns) * 2:
			var message := 'layer "%s" draws %d paths across only %d columns' % [layer.id, layer.paths, layer.columns]
			_add(diagnostics, "warning", "shardrun-crowded-map", message, run_file)
	for kind: String in ["fight", "elite"]:
		var weights: Dictionary = config.rewards.shards[kind]
		var offered := shards.values().any(
			func(shard: Dictionary) -> bool: return shard.draftable and float(weights[shard.rarity]) > 0.0
		)
		if not offered:
			var message := "%s rewards can never offer a shard: no draftable shard has a weighted rarity" % kind
			_add(diagnostics, "warning", "shardrun-no-rewards", message, run_file)
	for kind: String in ["elite", "treasure", "boss"]:
		var weights: Dictionary = config.rewards.relics[kind]
		if not relics.values().any(func(relic: Dictionary) -> bool: return float(weights[relic.rarity]) > 0.0):
			var message := "%s rewards can never offer a relic: no relic has a weighted rarity" % kind
			_add(diagnostics, "warning", "shardrun-no-relics", message, run_file)


static func _add(diagnostics: Array[Dictionary], severity: String, code: String, message: String, file: String) -> void:
	diagnostics.append({"severity": severity, "code": code, "message": message, "file": file})
