class_name GuardianLanding
extends RefCounted
## The guardian pool as a program lands (docs/NewEnemies.md, ADR-0026). ProgramRules.resolve calls in at four points:
## `plan` before the first bolt flies (a loop's guard, Karp's certificate and the Oracle's prediction are judged on the
## whole volley), `bolt` for each bolt at a foe (a page fault, a cache hit, a short circuit, a factor), `body` for the
## damage a lazy, stacked or 8-bit foe takes its own way, and `finish` after the last. `plan` carries what one landing
## learned from bolt to bolt; its `notes` are what the code panel tells the player before they run.

const TICK := "✓"
const CROSS := "✗"


## What each guardian makes of this volley before any bolt lands. `bonus` is the power relics add to every bolt.
static func plan(landing: Array[Dictionary], alive: Array, context: Dictionary, bonus: int) -> Dictionary:
	var out := {"foes": {}, "notes": [] as Array[String], "dealt": {}, "reflected": {}}
	for foe: Dictionary in alive:
		var foe_trait: Dictionary = foe.get("trait", {})
		var entry := {}
		match foe_trait.get("kind", ""):
			"loop-guard":
				var guard: Dictionary = foe.get("guard", {})
				entry.broken = guard_met(guard, landing, bonus)
				var verdict := (
					(
						"%s met: the loop breaks, +%d%% and it is stunned"
						% [TICK, roundi((float(foe_trait.bonus) - 1.0) * 100)]
					)
					if entry.broken
					else "%s not met: it goes round again" % CROSS
				)
				out.notes.append("↻ %s: `%s` %s." % [foe.name, guard_code(guard), verdict])
			"certificate":
				var aimed := aimed_at(landing, alive, foe, bonus)
				var powers: Array[int] = []
				for bolt: Dictionary in aimed:
					powers.append(int(bolt.power))
				var subset := subset_sum(powers, int(foe.get("target", 0)))
				var chosen := {}
				for at: int in subset:
					chosen[int(aimed[at].index)] = true
				entry.certificate = chosen
				entry.met = not subset.is_empty()
				if entry.met:
					var sum := " + ".join(
						PackedStringArray(subset.map(func(at: int) -> String: return str(powers[at])))
					)
					out.notes.append(
						(
							"♒ %s's riddle: %s = %d %s certificate: double, and it is stunned."
							% [foe.name, sum, int(foe.target), TICK]
						)
					)
				else:
					out.notes.append(
						(
							"♒ %s's riddle: no bolts at it add up to exactly %d %s its scales halve them."
							% [foe.name, int(foe.get("target", 0)), CROSS]
						)
					)
			"oracle":
				var prediction: Dictionary = foe.get("prediction", {})
				entry.right = prediction_holds(prediction, landing, alive, foe, context)
				var said := "%s predicts %s" % [foe.name, prediction_text(prediction)]
				out.notes.append(
					(
						"👁 %s: right %s it takes nothing, and half is reflected at you." % [said, CROSS]
						if entry.right
						else "👁 %s: wrong %s every bolt lands." % [said, TICK]
					)
				)
			"profiler":
				var speed := String(context.get("speed", "linear"))
				entry.factor = float((foe_trait.factors as Dictionary).get(speed, 1.0))
				out.notes.append(
					(
						"⏱ %s profiles %s: ×%s damage."
						% [foe.name, ProgramRules.TIER_LABELS.get(speed, speed), str(entry.factor)]
					)
				)
			"short-circuit":
				entry.first = true
				entry.open = true
			"livelock":
				if not out.has("swapping"):
					out.swapping = true
					out.notes.append("⇄ Every hit on a twin swaps the twins' places: aim 0 alternates between them.")
		out.foes[foe.uid] = entry
	return out


## One bolt at a foe: {skip, factor}. A skipped bolt is logged here and does nothing more.
static func bolt(
	state: Dictionary,
	battle: Dictionary,
	foe: Dictionary,
	the_bolt: Dictionary,
	index: int,
	power: int,
	plan_of: Dictionary,
	shape: Dictionary
) -> Dictionary:
	var foe_trait: Dictionary = foe.get("trait", {})
	var entry: Dictionary = (plan_of.foes as Dictionary).get(foe.uid, {})
	var pass_on := {"skip": false, "factor": 1.0}
	match foe_trait.get("kind", ""):
		"short-circuit":
			if entry.get("first", false):
				entry.first = false
				if power < int(foe.get("guard", 0)):
					entry.open = false
					return pass_on
				return {"skip": false, "factor": float(foe_trait.bonus)}
			if not entry.get("open", true):
				_skip(
					state,
					foe,
					the_bolt,
					shape,
					"short-circuited",
					(
						"%s never evaluates it: the first bolt was under %d, so the rest are short-circuited."
						% [foe.name, int(foe.guard)]
					)
				)
				return {"skip": true, "factor": 0.0}
		ProgramGuardians.PAGED:
			if not foe.get("resident", false):
				ProgramGuardians.swap_in(battle, foe)
				_skip(
					state,
					foe,
					the_bolt,
					shape,
					"page fault",
					"Page fault: %s was not in memory. The bolt swaps it in and does nothing." % foe.name
				)
				return {"skip": true, "factor": 0.0}
		"lru-cache":
			var cache: Array = foe.get("cache", [])
			var room := int(foe_trait.warm_size) if int(foe.hp) * 2 < int(foe.max) else int(foe_trait.size)
			if power in cache:
				cache.erase(power)
				cache.push_front(power)
				_skip(
					state,
					foe,
					the_bolt,
					shape,
					"cache hit",
					"Cache hit: %s already knows %d and does not even look up." % [foe.name, power]
				)
				return {"skip": true, "factor": 0.0}
			cache.push_front(power)
			if cache.size() > room:
				cache.resize(room)
			foe.cache = cache
		"certificate":
			if (entry.get("certificate", {}) as Dictionary).has(index):
				return {"skip": false, "factor": float(foe_trait.bonus)}
			return {"skip": false, "factor": 1.0 if entry.get("met", false) else float(foe_trait.without)}
		"loop-guard":
			return {"skip": false, "factor": float(foe_trait.bonus) if entry.get("broken", false) else 1.0}
		"profiler":
			return {"skip": false, "factor": float(entry.get("factor", 1.0))}
		"oracle":
			if entry.get("right", false):
				var reflected: Dictionary = plan_of.reflected
				reflected[foe.uid] = int(reflected.get(foe.uid, 0)) + power
				_skip(state, foe, the_bolt, shape, "foreseen", "%s foresaw it: the bolt does nothing." % foe.name)
				return {"skip": true, "factor": 0.0}
	return pass_on


static func _skip(
	state: Dictionary, foe: Dictionary, the_bolt: Dictionary, shape: Dictionary, word: String, text: String
) -> void:
	var entry := {"kind": "absorb", "foe": foe.uid, "element": the_bolt.element, "word": word}
	entry.merge(shape)
	entry.text = text
	Shardrun.record(state, entry)


## Damage to a foe whose body takes it its own way (lazy, a stack of frames, an 8-bit counter): {dealt, wasted}, logged
## here. {} for every other foe, which the landing hurts as usual.
static func body(
	state: Dictionary, foe: Dictionary, damage: int, power: int, element: String, shape: Dictionary
) -> Dictionary:
	var foe_trait: Dictionary = foe.get("trait", {})
	match foe_trait.get("kind", ""):
		"lazy":
			var blocked := _shield(foe, damage)
			var through := damage - blocked
			if power < int(foe_trait.force):
				foe.pending = int(foe.get("pending", 0)) + through
				_skip(
					state,
					foe,
					{"element": element},
					shape,
					"pending +%d" % through,
					"%s puts it off: %d more pending (%d in all)." % [foe.name, through, int(foe.pending)]
				)
				return {"dealt": 0, "wasted": 0}
			var total := floori((int(foe.get("pending", 0)) + through) * float(foe_trait.bonus))
			foe.pending = 0
			return _land(state, foe, total, blocked, element, shape, "Forced! Everything pending lands at once: ")
		"call-stack":
			var blocked := _shield(foe, damage)
			var frames: Array = foe.frames
			var through := damage - blocked
			var landed := mini(through, int(frames[-1]))
			frames[-1] = int(frames[-1]) - landed
			var popped := int(frames[-1]) == 0
			if popped:
				frames.pop_back()
				foe.popped = true
			var before := int(foe.hp)
			foe.hp = ProgramGuardians.sum_of(frames)
			var hit := {"kind": "hit", "foe": foe.uid, "amount": before - int(foe.hp), "element": element}
			hit.merge(shape)
			if blocked > 0:
				hit.blocked = blocked
			if through > landed:
				hit.overkill = through - landed
			hit.text = "%s's top frame takes %d%s." % [foe.name, landed, ", and is popped" if popped else ""]
			Shardrun.record(state, hit)
			if int(foe.hp) == 0:
				Shardrun.record(state, {"kind": "defeat", "foe": foe.uid, "text": "%s returns from main()." % foe.name})
			return {"dealt": landed, "wasted": through - landed}
		"int8":
			if damage <= 127:
				return {}
			# LEARN: a signed byte holds -128..127. Adding 128, wrapping into 0..255 with posmod and taking 128 away
			# again is exactly what the hardware's two's complement does to a number too big for it.
			var wrapped := posmod(damage + 128, 256) - 128
			if wrapped >= 0:
				return _land(
					state, foe, wrapped, _shield(foe, wrapped), element, shape, "%d wraps to %d: " % [damage, wrapped]
				)
			var healed := mini(int(foe.max) - int(foe.hp), -wrapped)
			foe.hp = int(foe.hp) + healed
			_skip(
				state,
				foe,
				{"element": element},
				shape,
				"%d → %d" % [damage, wrapped],
				"Overflow: %d wraps to %d in a signed byte, and %s heals %d." % [damage, wrapped, foe.name, healed]
			)
			return {"dealt": 0, "wasted": damage}
	return {}


static func _shield(foe: Dictionary, damage: int) -> int:
	var blocked := mini(int(foe.shield), damage)
	foe.shield = int(foe.shield) - blocked
	return blocked


static func _land(
	state: Dictionary, foe: Dictionary, total: int, blocked: int, element: String, shape: Dictionary, lead: String
) -> Dictionary:
	var through := maxi(0, total - blocked)
	var landed := mini(through, int(foe.hp))
	foe.hp = int(foe.hp) - landed
	var hit := {"kind": "hit", "foe": foe.uid, "amount": landed, "element": element}
	hit.merge(shape)
	if blocked > 0:
		hit.blocked = blocked
	if through > landed:
		hit.overkill = through - landed
	hit.text = "%s%s takes %d." % [lead, foe.name, landed]
	Shardrun.record(state, hit)
	if int(foe.hp) == 0:
		Shardrun.record(state, {"kind": "defeat", "foe": foe.uid, "text": "%s breaks apart." % foe.name})
	return {"dealt": landed, "wasted": through - landed}


## Counts what a program dealt to a foe, for the Mutator's tests.
static func count(plan_of: Dictionary, foe: Dictionary, dealt: int) -> void:
	var dealt_to: Dictionary = plan_of.dealt
	dealt_to[foe.uid] = int(dealt_to.get(foe.uid, 0)) + dealt


## After a hit: the Livelock Twins trade places, in the landing's list of targets and in the fight's.
static func after_hit(battle: Dictionary, alive: Array, foe: Dictionary) -> void:
	var foe_trait: Dictionary = foe.get("trait", {})
	if foe_trait.get("kind") != "livelock":
		return
	for other: Dictionary in alive:
		if other.id == foe_trait.partner and int(other.hp) > 0 and int(foe.hp) > 0:
			_swap(alive, foe, other)
			_swap(battle.foes, foe, other)
			return


static func _swap(list: Array, a: Dictionary, b: Dictionary) -> void:
	var i := list.find(a)
	var j := list.find(b)
	if i >= 0 and j >= 0:
		list[i] = b
		list[j] = a


## A foe of the pool falls: Malloc's blocks are freed with her, a block you broke is `free()` (block for you), a twin's
## partner enrages, and a page that falls hands residency on.
static func on_defeat(state: Dictionary, battle: Dictionary, foe: Dictionary) -> void:
	var foe_trait: Dictionary = foe.get("trait", {})
	match foe_trait.get("kind", ""):
		"allocator":
			for block: Dictionary in ProgramGuardians.minions_of(battle, foe):
				block.hp = 0
				Shardrun.record(
					state, {"kind": "defeat", "foe": block.uid, "text": "%s is freed with her." % block.name}
				)
		"heap-block":
			var amount := int(foe_trait.free_block)
			battle.block = int(battle.block) + amount
			var text := "free(): the block's memory comes back to you as %d block." % amount
			Shardrun.record(state, {"kind": "ward", "amount": amount, "element": "none", "text": text})
		"livelock":
			for other: Dictionary in battle.foes:
				if other.id == foe_trait.partner and int(other.hp) > 0 and not other.get("enraged", false):
					other.enraged = true
					var text := (
						"%s stops yielding: its strikes hit %d%% harder."
						% [other.name, roundi((float(foe_trait.enrage) - 1.0) * 100)]
					)
					Shardrun.record(state, {"kind": "note", "foe": other.uid, "word": "enraged", "text": text})
		ProgramGuardians.PAGED:
			if foe.get("resident", false):
				foe.resident = false
				ProgramGuardians.settle_pages(battle)


## After the last bolt: a broken loop resets and stuns, a certificate stuns, a right prediction reflects, the Mutator's
## tests kill the mutants that ran, and the Root Compiler changes phase.
static func finish(state: Dictionary, battle: Dictionary, plan_of: Dictionary, context: Dictionary) -> void:
	var reflected: Dictionary = plan_of.reflected
	for foe: Dictionary in battle.foes:
		var entry: Dictionary = (plan_of.foes as Dictionary).get(foe.uid, {})
		var foe_trait: Dictionary = foe.get("trait", {})
		match foe_trait.get("kind", ""):
			"loop-guard":
				if entry.get("broken", false) and int(foe.hp) > 0:
					foe.loop = ProgramGuardians.loop_start(foe)
					foe.stunned = true
					foe.broke = true
					var text := "`%s`: the loop breaks. %s is stunned." % [guard_code(foe.get("guard", {})), foe.name]
					Shardrun.record(state, {"kind": "note", "foe": foe.uid, "word": "break", "text": text})
			"certificate":
				if entry.get("met", false) and int(foe.hp) > 0:
					foe.stunned = true
					var text := "Certificate checked: %s is stunned." % foe.name
					Shardrun.record(state, {"kind": "note", "foe": foe.uid, "word": "verified", "text": text})
			"oracle":
				var power := floori(int(reflected.get(foe.uid, 0)) * float(foe_trait.reflect))
				if power > 0:
					var text := "%s was right about your program: %d is reflected." % [foe.name, power]
					Shardrun.record(state, {"kind": "note", "foe": foe.uid, "text": text})
					ShardrunBattle.hit_maintainer(state, battle, foe, power)
			"mutator":
				if int((plan_of.dealt as Dictionary).get(foe.uid, 0)) >= int(foe_trait.kill_at):
					_kill_mutants(state, battle, foe, foe_trait, context.get("cards", []))
		if foe.has("compiler"):
			RootCompiler.check(state, battle, foe)


static func _kill_mutants(
	state: Dictionary, battle: Dictionary, foe: Dictionary, foe_trait: Dictionary, cards: Array
) -> void:
	var mutants: Dictionary = battle.get("mutants", {})
	for id: String in cards:
		if not mutants.has(id) or int(foe.hp) <= 0:
			continue
		mutants.erase(id)
		var damage := mini(int(foe.hp), int(foe_trait.kill_damage))
		foe.hp = int(foe.hp) - damage
		var text := "Your tests catch the mutant %s: it is restored, and %s takes %d." % [id, foe.name, damage]
		Shardrun.record(state, {"kind": "hit", "foe": foe.uid, "amount": damage, "element": "none", "text": text})
		if int(foe.hp) == 0:
			Shardrun.record(state, {"kind": "defeat", "foe": foe.uid, "text": "%s breaks apart." % foe.name})


# --- Judging a volley -------------------------------------------------------------------------------------------------


## Whether a volley meets a loop's `break` guard.
static func guard_met(guard: Dictionary, landing: Array[Dictionary], bonus := 0) -> bool:
	var powers: Array[int] = []
	for the_bolt in landing:
		powers.append(int(the_bolt.power) + bonus)
	match guard.get("check", ""):
		"count":
			return powers.size() == int(guard.value) if guard.op == "==" else powers.size() >= int(guard.value)
		"sorted":
			for i in range(1, powers.size()):
				if powers[i] < powers[i - 1]:
					return false
			return true
		"element":
			return landing.any(func(the_bolt: Dictionary) -> bool: return the_bolt.element == guard.element)
		"max-power":
			return not powers.is_empty() and powers.max() >= int(guard.value)
		"sum-power":
			return ProgramGuardians.sum_of(powers) >= int(guard.value)
	return false


## A guard as the line of code the player reads.
static func guard_code(guard: Dictionary) -> String:
	match guard.get("check", ""):
		"count":
			return "if len(volley) %s %d: break" % [guard.op, int(guard.value)]
		"sorted":
			return "if volley == sorted(volley): break"
		"element":
			return 'if any(b.element == "%s" for b in volley): break' % guard.element
		"max-power":
			return "if max(powers) >= %d: break" % int(guard.value)
		"sum-power":
			return "if sum(powers) >= %d: break" % int(guard.value)
	return "while True"


## The attacking bolts a volley aims at one foe, as the landing would pick them: [{index, power}].
static func aimed_at(landing: Array[Dictionary], alive: Array, foe: Dictionary, bonus := 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in landing.size():
		var the_bolt: Dictionary = landing[index]
		if the_bolt.get("block", false) or alive.is_empty():
			continue
		var at := int(the_bolt.get("foe", 0))
		var target: Dictionary = alive[at] if at < alive.size() else alive[0]
		if target.uid == foe.uid:
			out.append({"index": index, "power": int(the_bolt.power) + bonus})
	return out


## Positions of some of `values` that add up to exactly `target`, or [] when none do.
## LEARN: subset sum is NP-complete: no known way finds an answer fast for every input. But a table of which totals are
## reachable (for each value, every total it can extend) is only values × target steps, and checking an answer someone
## hands you is one addition per part. That gap, hard to find and easy to check, is what NP means.
static func subset_sum(values: Array[int], target: int) -> Array[int]:
	if target <= 0:
		return []
	# came[total] = [the value's position, the total before it], for the first way each total was reached.
	var came := {0: []}
	for position in values.size():
		var value := values[position]
		if value <= 0:
			continue
		for total: int in came.keys():
			var next := total + value
			if next <= target and not came.has(next):
				came[next] = [position, total]
	if not came.has(target):
		return []
	var picked: Array[int] = []
	var at := target
	while at > 0:
		var step: Array = came[at]
		picked.push_front(int(step[0]))
		at = int(step[1])
	return picked


## Whether the Halting Oracle's prediction is true of this program.
static func prediction_holds(
	prediction: Dictionary, landing: Array[Dictionary], alive: Array, foe: Dictionary, context: Dictionary
) -> bool:
	var attacking := landing.filter(func(the_bolt: Dictionary) -> bool: return not the_bolt.get("block", false))
	match prediction.get("check", ""):
		"bolts-under":
			return attacking.size() < int(prediction.value)
		"slower-than":
			var order := ProgramRules.TIER_ORDER
			return order.find(String(context.get("speed", "linear"))) > order.find(String(prediction["class"]))
		"aimed-at-me":
			return not attacking.is_empty() and aimed_at(landing, alive, foe).size() == attacking.size()
		"has-element":
			return attacking.any(func(the_bolt: Dictionary) -> bool: return the_bolt.element == prediction.element)
	return false


static func prediction_text(prediction: Dictionary) -> String:
	match prediction.get("check", ""):
		"bolts-under":
			return "fewer than %d bolts" % int(prediction.value)
		"slower-than":
			return "slower than %s" % ProgramRules.TIER_LABELS.get(prediction["class"], prediction["class"])
		"aimed-at-me":
			return "every bolt aimed at it"
		"has-element":
			return "a %s bolt" % prediction.element
	return "nothing"


# --- Before a program runs --------------------------------------------------------------------------------------------


## What the code panel says about the guardians before a program runs, beyond what its landing showed: the dead code
## after a `return`, a throw to catch, the mutants in the program, the hot path. `after` is the battle once the program
## has landed (its block included).
static func telegraph(
	before: Dictionary, after: Dictionary, card_ids: Array, stage_list: Array[Dictionary], catalog: Dictionary
) -> Array[String]:
	var notes: Array[String] = []
	var cut := ProgramGuardians.dead_from(before)
	var steps := ProgramDeck.steps(card_ids, catalog)
	if cut >= 0 and cut < steps.size():
		notes.append(
			(
				"⚰ return at slot %d: %d of your cards are dead code. They do not run, and still cost mana."
				% [cut + 1, steps.size() - cut]
			)
		)
	elif cut >= 0:
		notes.append("⚰ A return is buried at slot %d: only slots 1 to %d run this turn." % [cut + 1, cut])
	for foe: Dictionary in after.get("foes", []):
		var intents: Array = foe.get("intents", [])
		if int(foe.hp) <= 0 or intents.is_empty():
			continue
		var intent: Dictionary = intents[int(foe.intent_index) % intents.size()]
		if intent.kind == "throw":
			var power := int(intent.power) + int(foe.get("trace", 0))
			var block := int(after.get("block", 0))
			notes.append(
				(
					"🛡 %s throws %d: your %d block will catch it and bounce it back." % [foe.name, power, block]
					if block >= power
					else "⚠ %s throws %d: with %d block it will not be caught." % [foe.name, power, block]
				)
			)
		if (foe.get("trait", {}) as Dictionary).get("kind") == "profiler" and not stage_list.is_empty():
			var hot: Dictionary = stage_list[0]
			for stage: Dictionary in stage_list:
				if int(stage.work) > int(hot.work):
					hot = stage
			var name := String((catalog.shards.get(hot.card, {}) as Dictionary).get("name", hot.card))
			notes.append(
				(
					"🔥 Hot path: %s (%d ops, %s)."
					% [name, int(hot.work), ProgramRules.TIER_LABELS.get(hot.complexity, hot.complexity)]
				)
			)
	var mutants: Dictionary = before.get("mutants", {})
	for id: String in card_ids:
		if mutants.has(id):
			var name := String((catalog.shards.get(id, {}) as Dictionary).get("name", id))
			notes.append("🧬 %s is a mutant (%s). Land 25 on the Mutator to kill it." % [name, mutants[id].name])
	return notes
