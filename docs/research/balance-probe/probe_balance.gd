extends SceneTree
## Balance probe (a research script, not part of the game; see README.md): plays program runs with a one-turn-lookahead
## bot. Every turn it runs every affordable, ordered program the hand can make in one sandbox job, simulates each cast
## and the foes' answer with the real rules, and plays the best. Writes one JSON line per run.
##   godot --headless --path game -s "$PWD/docs/research/balance-probe/probe_balance.gd" -- paradigms=greedy seeds=4 \
##       out=/tmp/runs.jsonl < /dev/null

const LANGUAGE := "javascript"
const STALEMATE := 40
const RARITY := {"common": 1.0, "uncommon": 2.0, "rare": 3.0}

var catalog: Dictionary
var limits: SandboxJob
var difficulty := "beginner"
var hp_weight := 2.5
var variants: PackedStringArray = []
var policy := "smart"
var picks := "plain"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("variant="):
			variants = arg.substr(8).split(",")
		elif arg.begins_with("policy="):
			policy = arg.substr(7)
		elif arg.begins_with("picks="):
			picks = arg.substr(6)
	var raw: Dictionary = ContentLoader.load_shardrun().catalog
	_apply_variants(raw)
	catalog = ProgramRules.catalog_for(raw)
	limits = SandboxJob.new()
	limits.time_ms = 120000
	limits.wall_ms = 300000
	limits.memory_mb = 1024
	limits.output_kb = 262144
	var paradigms: PackedStringArray = ["divide-conquer", "search-index", "greedy", "brute-force", "dynamic"]
	var seeds := 3
	var offset := 0
	var out_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("paradigms="):
			paradigms = arg.substr(10).split(",")
		elif arg.begins_with("seeds="):
			seeds = int(arg.substr(6))
		elif arg.begins_with("offset="):
			offset = int(arg.substr(7))
		elif arg.begins_with("difficulty="):
			difficulty = arg.substr(11)
		elif arg.begins_with("hp_weight="):
			hp_weight = float(arg.substr(10))
		elif arg.begins_with("out="):
			out_path = arg.substr(4)
	for paradigm: String in paradigms:
		for i in seeds:
			var started := Time.get_ticks_msec()
			var report := play_run(paradigm, "%s-%d" % [paradigm, i + offset])
			report.seconds = (Time.get_ticks_msec() - started) / 1000.0
			var line := JSON.stringify(report)
			print(
				(
					"RUN %s seed=%s status=%s layer=%d fights=%d secs=%.0f"
					% [paradigm, report.seed, report.status, report.layer, report.fights_won, report.seconds]
				)
			)
			if out_path != "":
				var file := FileAccess.open(out_path, FileAccess.READ_WRITE)
				if file == null:
					file = FileAccess.open(out_path, FileAccess.WRITE)
				file.seek_end()
				file.store_line(line)
				file.close()
	quit()


## What-if changes to the content, in memory only: the repository is never touched.
func _apply_variants(raw: Dictionary) -> void:
	var config: Dictionary = raw.programs.config
	for variant: String in variants:
		match variant:
			"sources4":
				config.basics = [
					"salvo", "salvo", "salvo", "salvo", "fork", "amplify", "ward", "ward", "round-robin", "kindle"
				]
			"salvo-pool":
				(config.neutral as Array).append("salvo")
			"curve":
				raw.config.layers[1].foe_hp = 1.8
				raw.config.layers[2].foe_hp = 3.6
			"seed3":
				config.seed = [
					{"power": 3, "element": "none"}, {"power": 3, "element": "none"}, {"power": 3, "element": "none"}
				]
			"golem":
				# The Deadlock Golem's pattern ward softened: off-pattern bolts do half, not a quarter.
				raw.balance.pattern_off_multiplier = 0.5


## A seed whose draft offers `paradigm`.
func seed_for(paradigm: String, base: String) -> String:
	var ids: Array = (ProgramRules.config_of(catalog).paradigms as Array).map(
		func(p: Dictionary) -> String: return p.id
	)
	for k in 200:
		var seed := "%s~%d" % [base, k]
		var offers := Rng.create(seed, "paradigms").shuffled(ids).slice(0, 3)
		if paradigm in offers:
			return seed
	return base


func play_run(paradigm: String, base: String) -> Dictionary:
	var seed := seed_for(paradigm, base)
	var options := {
		"seed": seed, "language": LANGUAGE, "difficulty": difficulty, "playstyle": "program", "sandbox": false
	}
	var state := Shardrun.start(catalog, options)
	var report := {
		"paradigm": paradigm,
		"seed": seed,
		"fights": [],
		"refusals": [],
		"rooms": [],
		"picks": [],
	}
	var fight: Dictionary = {}
	var steps := 0
	while not state.status in Shardrun.ENDED and steps < 3000:
		steps += 1
		if state.status == "battle":
			if fight.is_empty():
				fight = _open_fight(state)
			if int(state.battle.turn) > STALEMATE:
				(fight.notes as Array).append("stalemate")
				state = _apply(state, {"type": "abandon"}, report)
				continue
			var turn := _best_turn(state)
			(fight.turns as Array).append(turn.record)
			state = turn.state
			if state.status != "battle":
				fight.won = state.status != "lost"
				fight.integrity_after = int(state.integrity)
				(report.fights as Array).append(fight)
				fight = {}
			continue
		var command := _next_command(state, paradigm, report)
		if command.is_empty():
			break
		state = _apply(state, command, report)
	report.status = state.status
	report.layer = int(state.layer) + 1
	report.integrity = int(state.integrity)
	report.integrity_max = int(state.integrity_max)
	report.deck = state.deck
	report.relics = state.relics
	report.capacity = int(state.spells[0].capacity)
	report.fights_won = (report.fights as Array).filter(func(f: Dictionary) -> bool: return f.won).size()
	report.stats = state.stats
	return report


func _apply(state: Dictionary, command: Dictionary, report: Dictionary) -> Dictionary:
	var result := Shardrun.step(state, command, catalog)
	if not result.ok:
		(report.refusals as Array).append({"command": command, "error": result.error})
		if state.status == "map":
			return state
		var fallback := Shardrun.step(state, {"type": "abandon"}, catalog)
		return fallback.state if fallback.ok else state
	return result.state


func _open_fight(state: Dictionary) -> Dictionary:
	var battle: Dictionary = state.battle
	return {
		"layer": int(state.layer) + 1,
		"kind": battle.kind,
		"foes": (battle.foes as Array).map(func(f: Dictionary) -> String: return f.id),
		"foe_hp": (battle.foes as Array).map(func(f: Dictionary) -> int: return int(f.hp)),
		"integrity_before": int(state.integrity),
		"deck_size": (state.deck as Array).size(),
		"turns": [],
		"notes": [],
		"won": false,
	}


# --- Combat -----------------------------------------------------------------------------------------------------------


func _best_turn(state: Dictionary) -> Dictionary:
	var battle: Dictionary = state.battle
	var spell: Dictionary = state.spells[0]
	var pool: Array = (battle.hand as Array).duplicate()
	var sequences := _sequences(pool, int(spell.capacity), int(battle.mana))
	var outcomes := _run_all(state, pool, sequences)
	var best: Dictionary = {}
	var best_value := -INF
	var max_damage := 0
	var timeouts := 0
	var with_faster := 0
	var dealt_order_value := -INF
	if policy == "dealt":
		var greedy: Array = []
		var left := int(battle.mana)
		for i in pool.size():
			var cost := int((catalog.shards[pool[i]] as Dictionary).cost)
			if greedy.size() < int(spell.capacity) and cost <= left:
				greedy.append(i)
				left -= cost
		sequences = [greedy]
	for seq: Array in sequences:
		var ids: Array = seq.map(func(i: int) -> String: return pool[i])
		var key := ",".join(ids)
		var outcome: Dictionary = outcomes.get(key, {"ok": false, "reason": "missing"})
		var sim := _simulate(state, pool, seq, [], outcome)
		if sim.is_empty():
			continue
		var value := _value(state, sim.state)
		if int(sim.damage) > max_damage:
			max_damage = int(sim.damage)
		if sim.timeout:
			timeouts += 1
		if int(sim.faster) > 0:
			with_faster += 1
		if _is_dealt_order(seq):
			dealt_order_value = maxf(dealt_order_value, value)
		if value > best_value:
			best_value = value
			best = {"seq": seq, "outcome": outcome, "sim": sim}
	# Hold the most valuable card left over for the next turn.
	var chosen: Array = best.seq
	var leftover: Array = []
	for i in pool.size():
		if not i in chosen:
			leftover.append(i)
	var held: Array = []
	if not leftover.is_empty() and ShardrunRules.hold_limit(state, catalog) > 0:
		leftover.sort_custom(func(a: int, b: int) -> bool: return _card_worth(pool[a]) > _card_worth(pool[b]))
		held = [leftover[0]]
	var final := _simulate(state, pool, chosen, held, best.outcome)
	if final.is_empty():
		final = best.sim
	var ids: Array = chosen.map(func(i: int) -> String: return pool[i])
	var record := {
		"turn": int(battle.turn),
		"mana": int(battle.mana),
		"hand": pool,
		"program": ids,
		"work": int(final.work),
		"faster": int(final.faster),
		"timeout": final.timeout,
		"damage": int(final.damage),
		"wasted": int(final.wasted),
		"block": int(final.block),
		"hp_lost": int(state.integrity) - int(final.state.integrity),
		"candidates": sequences.size(),
		"cand_timeouts": timeouts,
		"cand_faster": with_faster,
		"max_damage": max_damage,
		"lint": ProgramRules.lint(ids, catalog).size(),
		"order_gain": best_value - dealt_order_value if dealt_order_value > -INF else 0.0,
	}
	return {"state": final.state, "record": record}


## True when the sequence plays cards in the order they were dealt (a "no thought" program with the same cards).
func _is_dealt_order(seq: Array) -> bool:
	for k in range(1, seq.size()):
		if int(seq[k]) < int(seq[k - 1]):
			return false
	return true


func _sequences(pool: Array, capacity: int, mana: int) -> Array:
	var out: Array = []
	var seen := {}
	_extend([], pool, capacity, mana, out, seen)
	return out


func _extend(prefix: Array, pool: Array, capacity: int, mana: int, out: Array, seen: Dictionary) -> void:
	var key := ",".join(prefix.map(func(i: int) -> String: return pool[i]))
	if seen.has(key):
		return
	seen[key] = true
	out.append(prefix.duplicate())
	if prefix.size() >= capacity:
		return
	for i in pool.size():
		if i in prefix:
			continue
		var cost := int((catalog.shards[pool[i]] as Dictionary).cost)
		if cost > mana:
			continue
		prefix.append(i)
		_extend(prefix, pool, capacity, mana - cost, out, seen)
		prefix.pop_back()


func _run_all(state: Dictionary, pool: Array, sequences: Array) -> Dictionary:
	var config := ProgramRules.config_of(catalog)
	var input := {
		"bolts": (config.seed as Array).duplicate(true),
		"battle": ShardrunRules.shard_battle(state, state.battle),
		"limit": int(config.max_bolts),
		"trace_limit": 1,
	}
	var programs: Array[Dictionary] = []
	var outcomes := {}
	for seq: Array in sequences:
		var ids: Array = seq.map(func(i: int) -> String: return pool[i])
		var key := ",".join(ids)
		if ids.is_empty():
			outcomes[key] = {"ok": true, "bolts": (config.seed as Array).duplicate(true), "work": []}
			continue
		var shards: Array[Dictionary] = []
		for id: String in ids:
			shards.append(catalog.shards[id])
		programs.append({"id": key, "shards": shards})
	if programs.is_empty():
		return outcomes
	var runs := SpellHarness.run(LANGUAGE, programs, input, limits)
	for key: String in runs:
		outcomes[key] = SpellRuns.to_outcome(runs[key])
	return outcomes


## Composes `seq` into the Program and casts it with `outcome`; {} when the rules refuse.
func _simulate(state: Dictionary, pool: Array, seq: Array, held: Array, outcome: Dictionary) -> Dictionary:
	var ids: Array = seq.map(func(i: int) -> String: return pool[i])
	var hand: Array = []
	var keep: Array = []
	for i in pool.size():
		if i in seq:
			continue
		if i in held:
			keep.append(pool[i])
		else:
			hand.append(pool[i])
	var spell: Dictionary = state.spells[0]
	var compose := {"type": "compose", "spells": [{"id": spell.id, "shards": ids}], "hand": hand, "held": keep}
	var composed := Shardrun.step(state, compose, catalog)
	if not composed.ok:
		return {}
	var cast := Shardrun.step(composed.state, {"type": "cast", "spell_id": spell.id, "outcome": outcome}, catalog)
	if not cast.ok:
		return {}
	var after: Dictionary = cast.state
	var sim := {"state": after, "work": 0, "faster": 0, "timeout": false, "damage": 0, "wasted": 0, "block": 0}
	for entry: Dictionary in after.log:
		match entry.kind:
			"cast":
				sim.work = int(entry.get("work", 0))
			"timeout":
				sim.timeout = true
				sim.work = int(entry.amount)
			"tempo":
				sim.faster += 1
			"hit":
				sim.damage += int(entry.amount)
				if entry.has("overkill"):
					sim.wasted += int(entry.overkill)
			"wasted":
				sim.wasted += int(entry.amount)
			"ward":
				sim.block += int(entry.amount)
	return sim


func _foe_total(state: Dictionary) -> float:
	if not state.has("battle"):
		return 0.0
	var total := 0.0
	for foe: Dictionary in state.battle.foes:
		if int(foe.hp) > 0:
			total += int(foe.hp) + 0.5 * int(foe.shield)
	return total


func _alive(state: Dictionary) -> int:
	if not state.has("battle"):
		return 0
	return (state.battle.foes as Array).filter(func(f: Dictionary) -> bool: return int(f.hp) > 0).size()


func _value(before: Dictionary, after: Dictionary) -> float:
	if after.status == "lost":
		return -1.0e9 + _foe_total(before) - _foe_total(after)
	var won := not after.has("battle")
	var value := _foe_total(before) - _foe_total(after)
	value -= hp_weight * (int(before.integrity) - int(after.integrity))
	value += 15.0 * (_alive(before) - _alive(after))
	if won:
		value += 1000.0 + 3.0 * int(after.integrity)
	return value


# --- Between fights ---------------------------------------------------------------------------------------------------


func _card_worth(id: String) -> float:
	var card: Dictionary = catalog.shards.get(id, {})
	return float(RARITY.get(card.get("rarity", "common"), 1.0)) + 0.5 * int(card.get("cost", 0))


func _pick_score(id: String, paradigm: String, deck: Array) -> float:
	var card: Dictionary = catalog.shards.get(id, {})
	var own: Array = ProgramDraft.paradigm_of(catalog, paradigm).get("pool", [])
	var score := float(RARITY.get(card.get("rarity", "common"), 1.0))
	if id in own:
		score += 2.0
	var strikes := (
		deck
		. filter(func(c: String) -> bool: return (catalog.shards.get(c, {}) as Dictionary).get("role", "") == "strike")
		. size()
	)
	if card.get("role", "") == "strike" and strikes < 3:
		score += 1.5
	# Diminishing returns on copies.
	score -= 0.75 * deck.count(id)
	# A drafter who knows a program needs input: sources are worth a lot while they are scarce in the deck.
	if picks == "sources" and card.get("role", "") == "source" and id != "pairwise":
		var sources := deck.filter(func(c: String) -> bool: return c in ["salvo", "fork"]).size()
		if sources * 4 < deck.size():
			score += 3.0
	return score


func _next_command(state: Dictionary, paradigm: String, report: Dictionary) -> Dictionary:
	match state.status:
		"draft":
			var draft: Dictionary = state.draft
			if String(state.get("paradigm", "")) == "":
				return {"type": "pick-paradigm", "paradigm_id": paradigm}
			var pack: Array = draft.pack
			var best := _best_pick(pack, paradigm, state.deck)
			(report.picks as Array).append({"offered": pack, "took": best})
			return {"type": "draft-card", "card_id": best}
		"map":
			return _pick_room(state, report)
		"reward":
			var reward: Dictionary = state.get("reward", {})
			if reward.has("chest"):
				return {"type": "open-chest"}
			if reward.has("relics") and not (reward.relics as Array).is_empty():
				return {"type": "claim-relic", "relic_id": reward.relics[0]}
			if reward.has("shards") and not (reward.shards as Array).is_empty():
				var best := _best_pick(reward.shards, paradigm, state.deck)
				(report.picks as Array).append({"offered": reward.shards, "took": best})
				return {"type": "take", "shard_id": best}
			return {"type": "leave"}
		"rest":
			var cursed := ShardrunViews.cursed_relics(state, catalog)
			if not cursed.is_empty() and int(state.integrity) * 10 > int(state.integrity_max) * 7:
				return {"type": "cleanse-relic", "relic_id": cursed[0].id}
			return {"type": "rest"}
		"forge":
			var options := ShardrunViews.forge_options(state, catalog)
			if not (options.shards as Array).is_empty():
				return {"type": "forge", "shard_id": options.shards[0]}
			if not (options.spells as Array).is_empty():
				return {"type": "widen", "spell_id": options.spells[0]}
			return {"type": "forge", "shard_id": null}
	return {}


func _best_pick(offered: Array, paradigm: String, deck: Array) -> String:
	var best: String = offered[0]
	var best_score := -INF
	for id: String in offered:
		var score := _pick_score(id, paradigm, deck)
		if score > best_score:
			best_score = score
			best = id
	return best


func _pick_room(state: Dictionary, report: Dictionary) -> Dictionary:
	var rooms := ShardrunMap.next_rooms(state.map, state.position)
	if rooms.is_empty():
		return {}
	var healthy := int(state.integrity) * 10 >= int(state.integrity_max) * 6
	var order: Array = (
		["fight", "treasure", "elite", "forge", "rest", "boss"]
		if healthy
		else ["rest", "treasure", "forge", "fight", "elite", "boss"]
	)
	rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return order.find(a.kind) < order.find(b.kind))
	(report.rooms as Array).append("%d:%s" % [int(state.layer) + 1, rooms[0].kind])
	return {"type": "enter", "node_id": rooms[0].id}
