class_name RunHistory
extends RefCounted
## Every finished run, kept as a commit in a `git log`: a hash, an author (the look the Maintainer wore), a date, a
## branch (the paradigm, or the playstyle), a conventional commit message that says how it ended, and a diffstat in
## which damage dealt counts as insertions and Integrity lost as deletions. Pure: the store (SaveStore) keeps the
## entries, a view draws them; this only turns a finished state into an entry and an entry into the lines git prints.
##
##   var entry := RunHistory.entry(state, catalog, "2026-09-28T04:12:00", "vesper")
##   RunHistory.oneline(entry)   # "3f9a2c1 (tag: shipped) feat(greedy): ship it, the Root Daemon falls"


## The record of a finished run (won, lost or abandoned).
static func entry(state: Dictionary, catalog: Dictionary, finished_at: String, author: String) -> Dictionary:
	var stats: Dictionary = state.stats
	var layers: Array = (catalog.get("config", {}) as Dictionary).get("layers", [])
	var layer: Dictionary = layers[int(state.layer)] if int(state.layer) < layers.size() else {}
	var record := {
		"hash": "%08x" % Rng.hash_string("%s|%s|%d" % [state.seed, finished_at, int(state.revision)]),
		"date": finished_at,
		"author": author,
		"seed": state.seed,
		"status": state.status,
		"playstyle": state.get("playstyle", "spellbook"),
		"branch": String(state.get("paradigm", "")) if String(state.get("paradigm", "")) != "" else state.playstyle,
		"language": state.language,
		"difficulty": state.difficulty,
		"layer": int(state.layer) + 1,
		"layers": layers.size(),
		"place": String(layer.get("name", "")),
		"rooms": (state.visited as Array).size(),
		"fights": int(stats.fights),
		"turns": int(stats.turns),
		"damage": int(stats.damage),
		"best_cast": int(stats.best_cast),
		"integrity": int(state.integrity),
		"integrity_max": int(state.integrity_max),
		"score": int(ShardrunScore.score(state).total),
		"deck": (state.get("deck", []) as Array).duplicate(),
		"relics": (state.relics as Array).duplicate(),
	}
	# Who ended it: the foes still standing in the fight the run was lost in.
	var battle: Dictionary = state.get("battle", {})
	if state.status == "lost" and not battle.is_empty():
		var standing := (battle.foes as Array).filter(func(foe: Dictionary) -> bool: return int(foe.hp) > 0)
		record.killer = ", ".join(standing.map(func(foe: Dictionary) -> String: return String(foe.name)))
		record.fight = String(battle.get("kind", "fight"))
	return record


static func short_hash(record: Dictionary) -> String:
	return String(record.get("hash", "0000000")).substr(0, 7)


## The commit message's first line, in the conventional form: `feat` ships a win, `revert` rolls back a lost run,
## `chore` resets an abandoned one.
static func subject(record: Dictionary) -> String:
	var branch := String(record.get("branch", "run"))
	match record.get("status", ""):
		"won":
			return "feat(%s): ship it, all %d layers cleared" % [branch, int(record.get("layers", 0))]
		"lost":
			var killer := String(record.get("killer", ""))
			var by := " by %s" % killer if killer != "" else ""
			return "revert(%s): kernel panic on layer %d%s" % [branch, int(record.get("layer", 1)), by]
		_:
			return "chore(%s): reset --hard on layer %d" % [branch, int(record.get("layer", 1))]


## The decoration git prints after the hash: the newest run is HEAD, a win is tagged.
static func decoration(record: Dictionary, newest: bool) -> String:
	var parts: Array[String] = []
	if newest:
		parts.append("HEAD -> main")
	if record.get("status", "") == "won":
		parts.append("tag: shipped")
	return "(%s) " % ", ".join(parts) if not parts.is_empty() else ""


static func oneline(record: Dictionary, newest := false) -> String:
	return "%s %s%s" % [short_hash(record), decoration(record, newest), subject(record)]


## Damage dealt as insertions, Integrity lost as deletions, the rooms entered as the files changed.
static func diffstat(record: Dictionary) -> String:
	var lost := maxi(0, int(record.get("integrity_max", 0)) - int(record.get("integrity", 0)))
	return (
		" %d rooms changed, %d insertions(+), %d deletions(-)"
		% [int(record.get("rooms", 0)), int(record.get("damage", 0)), lost]
	)


## What `git show` prints for a run: the header, the message, its body, and the diffstat.
static func show(record: Dictionary, newest := false) -> Array[String]:
	var author := String(record.get("author", "maintainer"))
	var lines: Array[String] = [
		"commit %s %s" % [String(record.get("hash", "")), decoration(record, newest).strip_edges()],
		"Author: %s <%s@rootward>" % [author.capitalize(), author],
		"Date:   %s" % String(record.get("date", "")).replace("T", " "),
		"",
		"    " + subject(record),
		"",
		(
			"    %s · %s · %s · seed %s"
			% [
				record.get("place", ""),
				record.get("language", ""),
				record.get("difficulty", ""),
				record.get("seed", "")
			]
		),
		(
			"    %d fights, %d turns, best cast %d, score %d"
			% [int(record.fights), int(record.turns), int(record.best_cast), int(record.score)]
		),
	]
	var relics: Array = record.get("relics", [])
	if not relics.is_empty():
		lines.append("    relics: %s" % ", ".join(PackedStringArray(relics)))
	var deck: Array = record.get("deck", [])
	if not deck.is_empty():
		lines.append("    deck (%d): %s" % [deck.size(), ", ".join(PackedStringArray(deck))])
	lines.append("")
	lines.append(diffstat(record))
	return lines
