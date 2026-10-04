extends SceneTree
## Balance probe (a research script, not part of the game; see README.md): plays program runs with a one-turn-lookahead
## bot. Every turn it enumerates affordable ordered programs, deterministically samples at most 128 candidates, runs
## them in one sandbox job, simulates each cast and the foes' answer with the real rules, and plays the best. Writes
## one JSON line per run.
##   godot --headless --path game -s "$PWD/docs/research/balance-probe/probe_balance.gd" -- paradigms=greedy seeds=4 \
##       out=/tmp/runs.jsonl < /dev/null

const LANGUAGE := "javascript"
const STALEMATE := 40
const RARITY := {"common": 1.0, "uncommon": 2.0, "rare": 3.0}
const MAX_SEQUENCE_EVALUATIONS := 128
const PROBE_CPU_MS := 120000
const PROBE_WALL_MS := 300000
const PROBE_MEMORY_MB := 1024

var catalog: Dictionary
var limits: SandboxJob
var difficulty := "beginner"
var hp_weight := 2.5
var variants: PackedStringArray = []
var policy := "smart"
var picks := "plain"
var focus_choice := "first"
## A program run's foe HP by layer, in place of programs.jsonc's (`foe_hp=2.8,4.2,4.8`).
var foe_hp: Array = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("variant="):
			variants = arg.substr(8).split(",")
		elif arg.begins_with("policy="):
			policy = arg.substr(7)
		elif arg.begins_with("picks="):
			picks = arg.substr(6)
		elif arg.begins_with("focus="):
			focus_choice = arg.substr(6)
		elif arg.begins_with("foe_hp="):
			foe_hp = Array(arg.substr(7).split(",")).map(func(text: String) -> float: return float(text))
	var raw: Dictionary = ContentLoader.load_shardrun().catalog
	_apply_variants(raw)
	catalog = ProgramRules.catalog_for(raw)
	limits = SandboxJob.new()
	# Smart policy evaluates a batch of hypothetical programs, not the one program the game executes. Keep its research
	# batch budget fixed and bounded; the 2-second in-game CPU limit applies only to a single submitted program.
	limits.time_ms = PROBE_CPU_MS
	limits.wall_ms = PROBE_WALL_MS
	limits.memory_mb = PROBE_MEMORY_MB
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
			var selected_focus := focus_choice
			if focus_choice == "cycle":
				var focus_list: Array = ProgramDraft.paradigm_of(catalog, paradigm).get("focuses", [])
				selected_focus = String(focus_list[i % focus_list.size()].id) if not focus_list.is_empty() else "first"
			var report := play_run(paradigm, "%s-%d" % [paradigm, i + offset], selected_focus)
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
				if file == null:
					push_error(
						"Could not open probe output: %s (%s)" % [out_path, error_string(FileAccess.get_open_error())]
					)
					quit(1)
					return
				file.seek_end()
				file.store_line(line)
				file.close()
	quit()


## What-if changes to the content, in memory only: the repository is never touched.
func _apply_variants(raw: Dictionary) -> void:
	var config: Dictionary = raw.programs.config
	if not foe_hp.is_empty():
		config.foe_hp = foe_hp
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
				# A pattern ward softened: off-pattern bolts do half, not a quarter (the content's own value since ADR-0016).
				config.pattern_off = 0.5
			"ward-quarter":
				# A pattern ward as Spellforge has it, as program runs had it before ADR-0016: off-pattern bolts do a quarter.
				config.pattern_off = raw.balance.pattern_off_multiplier


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


func play_run(paradigm: String, base: String, selected_focus := "first") -> Dictionary:
	var seed := seed_for(paradigm, base)
	var options := {
		"seed": seed, "language": LANGUAGE, "difficulty": difficulty, "playstyle": "program", "sandbox": false
	}
	var state := Shardrun.start(catalog, options)
	var report := {
		"paradigm": paradigm,
		"seed": seed,
		"focus": "",
		"fights": [],
		"refusals": [],
		"rooms": [],
		"issue_rooms": [],
		"picks": [],
		"registries": [],
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
			var script_command := _script_command(state, fight)
			if not script_command.is_empty():
				var script_id: String = (state.belt as Array)[int(script_command.index)]
				state = _apply(state, script_command, report)
				(fight.script_uses as Array).append(script_id)
				if state.status != "battle":
					fight.won = state.status != "lost"
					fight.integrity_after = int(state.integrity)
					(report.fights as Array).append(fight)
					fight = {}
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
		if state.status == "shop":
			_track_registry(state, report)
		var command := _next_command(state, paradigm, report, selected_focus)
		if command.is_empty():
			break
		state = _apply(state, command, report)
	if not fight.is_empty():
		fight.won = false
		fight.integrity_after = int(state.integrity)
		if "incomplete" not in fight.notes:
			(fight.notes as Array).append("incomplete")
		(report.fights as Array).append(fight)
	report.status = state.status
	report.layer = int(state.layer) + 1
	report.integrity = int(state.integrity)
	report.integrity_max = int(state.integrity_max)
	report.deck = state.deck
	report.relics = state.relics
	report.focus = String(state.get("focus", ""))
	report.capacity = int(state.spells[0].capacity)
	report.fights_won = (report.fights as Array).filter(func(f: Dictionary) -> bool: return f.won).size()
	report.stats = state.stats
	report.cycles_earned = int(state.get("cycles_earned", 0))
	report.cycles_spent = int(state.get("cycles_spent", 0))
	report.cycles = int(state.get("cycles", 0))
	report.script_uses = (report.fights as Array).reduce(
		func(total: int, item: Dictionary) -> int: return total + (item.script_uses as Array).size(), 0
	)
	report.script_uses_per_fight = float(report.script_uses) / maxf(1.0, (report.fights as Array).size())
	report.law_active_turns = (report.fights as Array).reduce(
		func(total: int, item: Dictionary) -> int:
			return total + (item.turns as Array).filter(func(turn: Dictionary) -> bool: return turn.law_active).size(),
		0
	)
	var turns := 0
	for item: Dictionary in report.fights:
		turns += (item.turns as Array).size()
	report.law_activation_rate = float(report.law_active_turns) / maxf(1.0, turns)
	report.registry_purchases = (report.registries as Array).reduce(
		func(total: int, item: Dictionary) -> int: return total + int(item.purchases), 0
	)
	report.purchases_per_registry = float(report.registry_purchases) / maxf(1.0, (report.registries as Array).size())
	var layer_issue_counts := {}
	for issue_layer: int in report.issue_rooms:
		layer_issue_counts[issue_layer] = int(layer_issue_counts.get(issue_layer, 0)) + 1
	report.issues_by_layer = layer_issue_counts
	var own_pool: Array = ProgramDraft.paradigm_of(catalog, paradigm).get("pool", [])
	var neutral_pool: Array = ProgramRules.config_of(catalog).get("neutral", [])
	var own_count := 0
	var neutral_count := 0
	var other_count := 0
	for id: String in state.deck:
		if id in own_pool:
			own_count += 1
		elif id in neutral_pool:
			neutral_count += 1
		else:
			other_count += 1
	var deck_size := maxf(1.0, state.deck.size())
	report.deck_share = {
		"own": own_count / deck_size,
		"neutral": neutral_count / deck_size,
		"other": other_count / deck_size,
	}
	return report


func _apply(state: Dictionary, command: Dictionary, report: Dictionary) -> Dictionary:
	var shop_room := String((state.get("shop", {}) as Dictionary).get("room", "")) if state.status == "shop" else ""
	var result := Shardrun.step(state, command, catalog)
	if not result.ok:
		(report.refusals as Array).append({"command": command, "error": result.error})
		if state.status == "map":
			return state
		var fallback := Shardrun.step(state, {"type": "abandon"}, catalog)
		return fallback.state if fallback.ok else state
	if command.type == "buy" and shop_room != "":
		for visit: Dictionary in report.registries:
			if visit.room == shop_room:
				visit.purchases = int(visit.purchases) + 1
				visit.cycles_spent += int(state.get("cycles", 0)) - int(result.state.get("cycles", 0))
				break
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
		"script_uses": [],
		"notes": [],
		"won": false,
	}


# --- Combat -----------------------------------------------------------------------------------------------------------


func _best_turn(state: Dictionary) -> Dictionary:
	var battle: Dictionary = state.battle
	var spell: Dictionary = state.spells[0]
	var pool: Array = (battle.hand as Array).duplicate()
	var sequences := _sequences(pool, int(spell.capacity), int(battle.mana))
	if policy == "smart":
		sequences = _sample_sequences(sequences)
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
		"law_active": _law_activated(state, ids, best.outcome, final),
	}
	return {"state": final.state, "record": record}


## True when the sequence plays cards in the order they were dealt (a "no thought" program with the same cards).
func _is_dealt_order(seq: Array) -> bool:
	for k in range(1, seq.size()):
		if int(seq[k]) < int(seq[k - 1]):
			return false
	return true


## Keep a deterministic, spread-out candidate set so larger hands do not turn every probe seed into an unbounded search.
## Empty, single-card and longest dealt-order programs are always represented.
func _sample_sequences(sequences: Array) -> Array:
	if sequences.size() <= MAX_SEQUENCE_EVALUATIONS:
		return sequences
	var sampled: Array = []
	var seen := {}
	for seq: Array in sequences:
		if seq.size() <= 1:
			sampled.append(seq)
			seen[",".join(seq.map(func(i: int) -> String: return str(i)))] = true
	var dealt_order: Array = []
	for seq: Array in sequences:
		if seq.size() > dealt_order.size() and _is_dealt_order(seq):
			dealt_order = seq
	if not dealt_order.is_empty():
		var dealt_key := ",".join(dealt_order.map(func(i: int) -> String: return str(i)))
		if not seen.has(dealt_key):
			sampled.append(dealt_order)
			seen[dealt_key] = true
	for sample_index in MAX_SEQUENCE_EVALUATIONS:
		if sampled.size() >= MAX_SEQUENCE_EVALUATIONS:
			break
		var index := roundi(float(sample_index) * float(sequences.size() - 1) / float(MAX_SEQUENCE_EVALUATIONS - 1))
		var seq: Array = sequences[index]
		var key := ",".join(seq.map(func(i: int) -> String: return str(i)))
		if not seen.has(key):
			sampled.append(seq)
			seen[key] = true
	return sampled


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
	var spell_runs := SpellRuns.new(catalog)
	var input: Dictionary
	if state.has("focus"):
		input = spell_runs.input_for(state)
	else:
		# The immutable pre-update baseline predates stateful program execution and focuses. Preserve its original input
		# contract so the same sampled policy can be paired against both content revisions.
		var config := ProgramRules.config_of(catalog)
		input = {
			"bolts": (config.seed as Array).duplicate(true),
			"battle": ShardrunRules.shard_battle(state, state.battle),
			"limit": int(config.max_bolts),
			"trace_limit": 1,
		}
	var job_input := input.duplicate(true)
	var hooks: Array = []
	for hook: Dictionary in input.get("hooks", []):
		var hooked := hook.duplicate(true)
		hooked.card = catalog.shards.get(hook.card, {})
		hooks.append(hooked)
	job_input.hooks = hooks
	var programs: Array[Dictionary] = []
	var outcomes := {}
	for seq: Array in sequences:
		var ids: Array = seq.map(func(i: int) -> String: return pool[i])
		var key := ",".join(ids)
		if ids.is_empty():
			outcomes[key] = {"ok": true, "bolts": (input.bolts as Array).duplicate(true), "work": []}
			continue
		var shards: Array[Dictionary] = []
		for id: String in ids:
			shards.append(catalog.shards[id])
		programs.append({"id": key, "shards": shards})
	if programs.is_empty():
		return outcomes
	var runs := SpellHarness.run(LANGUAGE, programs, job_input, limits)
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


func _next_command(state: Dictionary, paradigm: String, report: Dictionary, selected_focus := "first") -> Dictionary:
	match state.status:
		"draft":
			var draft: Dictionary = state.draft
			if String(state.get("paradigm", "")) == "":
				return {"type": "pick-paradigm", "paradigm_id": paradigm}
			if not (draft.get("focus_offers", []) as Array).is_empty():
				var focus_id := (
					selected_focus if selected_focus in draft.focus_offers else String(draft.focus_offers[0])
				)
				return {"type": "pick-focus", "focus_id": focus_id}
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
			if reward.has("script"):
				var full: bool = (state.get("belt", []) as Array).size() >= _script_belt_size(state)
				return {"type": "take-script", "drop_index": 0} if full else {"type": "take-script"}
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
		"shop":
			return _shop_command(state)
		"issue":
			return _issue_command(state)
	return {}


func _script_command(state: Dictionary, fight: Dictionary) -> Dictionary:
	if int(state.battle.turn) > 1 or not (fight.script_uses as Array).is_empty():
		return {}
	var belt: Array = state.get("belt", [])
	if belt.is_empty():
		return {}
	var target := ""
	var living: Array = (state.battle.foes as Array).filter(func(foe: Dictionary) -> bool: return int(foe.hp) > 0)
	if not living.is_empty():
		living.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.hp) < int(b.hp))
		target = String(living[0].uid)
	var best_index := -1
	var best_score := -INF
	for i in belt.size():
		var item: Dictionary = catalog.programs.scripts.get(String(belt[i]), {})
		if item.is_empty():
			continue
		var effect: Dictionary = item.effect
		var score := _script_score(effect, state, living)
		if score > best_score:
			best_score = score
			best_index = i
	if best_index < 0:
		return {}
	var selected: Dictionary = catalog.programs.scripts[String(belt[best_index])]
	return {"type": "use-script", "index": best_index, "foe": target if selected.target == "foe" else ""}


func _script_score(effect: Dictionary, state: Dictionary, living: Array) -> float:
	match String(effect.kind):
		"foe-damage":
			return 100.0 + float(effect.amount) if not living.is_empty() else -INF
		"double-next":
			return 90.0
		"free-program":
			return 80.0
		"work-divide":
			return 70.0
		"nice":
			return 60.0
		"free-card":
			return 50.0
		"draw":
			return 45.0
		"gc":
			return 40.0
		"foe-half", "trait-off":
			return 35.0 if not living.is_empty() else -INF
		"revert":
			return 30.0 if int(state.battle.get("hurt_last", 0)) > 0 else -INF
		"heal":
			return 20.0 if int(state.integrity) < int(state.integrity_max) else -INF
		"stash-hand", "reveal-intents":
			return -INF
	return 0.0


func _shop_command(state: Dictionary) -> Dictionary:
	for shelf: String in ["relics", "scripts", "cards"]:
		var items: Array = state.shop.get(shelf, [])
		for index in items.size():
			var item: Dictionary = items[index]
			if item.get("sold", false):
				continue
			if _shop_price(state, shelf, item) > int(state.get("cycles", 0)):
				continue
			if (
				shelf == "scripts"
				and (state.get("belt", []) as Array).size() >= _script_belt_size(state)
			):
				continue
			return {"type": "buy", "shelf": shelf, "index": index}
	return {"type": "leave-shop"}


func _script_belt_size(state: Dictionary) -> int:
	return int(_script_call("program_scripts.gd", "belt_size", [state, catalog], 0))


func _shop_price(state: Dictionary, shelf: String, item: Dictionary) -> int:
	return int(_script_call("program_shop.gd", "price_of", [state, shelf, item, catalog], 0))


func _issue_definition(state: Dictionary) -> Dictionary:
	return _script_call("program_issues.gd", "definition", [state, catalog], {})


func _issue_can_choose(state: Dictionary, choice: Dictionary) -> bool:
	return bool(_script_call("program_issues.gd", "can_choose", [state, choice], false))


## New probe helpers are loaded by path so the immutable pre-update checkout can run the same probe without those classes.
func _script_call(file: String, method: String, arguments: Array, fallback: Variant) -> Variant:
	var resource := load("res://core/programs/" + file) as Script
	return fallback if resource == null else resource.callv(method, arguments)


func _issue_command(state: Dictionary) -> Dictionary:
	var issue: Dictionary = state.issue
	match String(issue.stage):
		"choose":
			var choices: Array = _issue_definition(state).get("choices", [])
			for index in choices.size():
				if (choices[index].effects as Array).is_empty():
					return {"type": "issue-choose", "index": index}
			for index in choices.size():
				if _issue_can_choose(state, choices[index]):
					return {"type": "issue-choose", "index": index}
			return {"type": "issue-choose", "index": 0}
		"pick":
			var count := (
				1 if issue.pick.purpose == "keep" else mini(int(issue.pick.count), (issue.pick.options as Array).size())
			)
			return {"type": "issue-pick", "card_ids": (issue.pick.options as Array).slice(0, count)}
		"paradigm":
			return {"type": "issue-paradigm", "paradigm_id": issue.paradigms[0]}
		"offer":
			return {"type": "issue-take", "card_id": issue.offer.cards[0]}
		"focus":
			return {"type": "issue-focus", "focus_id": issue.focuses[0]}
		"result":
			return {"type": "issue-leave"}
	return {"type": "issue-leave"}


func _track_registry(state: Dictionary, report: Dictionary) -> void:
	var room := String(state.shop.room)
	for visit: Dictionary in report.registries:
		if visit.room == room:
			return
	var visit := {
		"room": room,
		"layer": int(state.layer) + 1,
		"cycles_at_entry": int(state.get("cycles", 0)),
		"purchases": 0,
		"cycles_spent": 0,
	}
	(report.registries as Array).append(visit)
	if report.registries.size() == 1:
		report.cycles_at_first_registry = int(state.get("cycles", 0))


func _law_activated(before: Dictionary, ids: Array, outcome: Dictionary, simulated: Dictionary) -> bool:
	var laws: Array = (before.get("relics", []) as Array).filter(
		func(id: String) -> bool:
			return String((catalog.relics.get(id, {}) as Dictionary).get("tier", "")) == "paradigm"
	)
	if laws.is_empty():
		return false
	var law := String(laws[0])
	var battle: Dictionary = before.battle
	match law:
		"the-table":
			return int(battle.turn) >= 3 and (battle.get("dp", []) as Array).size() >= 2
		"the-index":
			return ProgramRules.seed(before, catalog).size() > (ProgramRules.config_of(catalog).seed as Array).size()
		"local-optimum":
			var previous_kills: Dictionary = battle.get("kills", {})
			var next_battle: Dictionary = simulated.state.get("battle", {})
			if not next_battle.is_empty():
				var next_kills: Dictionary = next_battle.get("kills", {})
				for foe_id: String in next_kills:
					if (
						(next_kills[foe_id] as Dictionary).get("initiative", false)
						and not (previous_kills.get(foe_id, {}) as Dictionary).get("initiative", false)
					):
						return true
				return false
			var receipt: Dictionary = simulated.state.get("reward", {}).get("receipt", {})
			var receipt_lines: Array = receipt.get("lines", [])
			var new_bonuses: int = receipt_lines.filter(
				func(line: Dictionary) -> bool: return line.get("label", "") == "Initiative"
			).size()
			var prior_kills: Array = previous_kills.values()
			var previous_bonuses: int = prior_kills.filter(
				func(kill: Dictionary) -> bool: return kill.get("initiative", false)
			).size()
			return new_bonuses > previous_bonuses
		"throw-hardware-at-it":
			return (
				int(simulated.work) >= 256
				and (outcome.get("bolts", []) as Array).any(
					func(bolt: Dictionary) -> bool: return not bolt.get("block", false) and not bolt.get("stash", false)
				)
			)
		"recurse":
			for index in ids.size():
				if (
					(catalog.shards.get(ids[index], {}) as Dictionary).get("splits", false)
					and index < ids.size() - 1
				):
					return true
	return false


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
		["fight", "treasure", "shop", "issue", "elite", "forge", "rest", "boss"]
		if healthy
		else ["rest", "treasure", "shop", "issue", "forge", "fight", "elite", "boss"]
	)
	rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return order.find(a.kind) < order.find(b.kind))
	(report.rooms as Array).append("%d:%s" % [int(state.layer) + 1, rooms[0].kind])
	if rooms[0].kind == "issue":
		(report.issue_rooms as Array).append(int(state.layer) + 1)
	return {"type": "enter", "node_id": rooms[0].id}
