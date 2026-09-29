class_name ProgramGuardians
extends RefCounted
## The guardian pool's rules (docs/NewEnemies.md, ADR-0026): each guardian's state, what it does at the turn's edges,
## and its new intents. A fight calls in here at fixed points (a foe made, a turn begun or ended, a foe acting); the
## landing's side is GuardianLanding. A foe with none of these traits or intents passes through untouched, so
## Spellforge and the older guardians play exactly as they did.

## Traits whose foes keep no state of their own beyond what `prepare` gives them.
const PAGED := "paged"


## A foe of the pool made ready for a fight: its counters, cache, frames or phases. `def` is its content; `foe` its
## fighting state, already scaled by the layer and the difficulty.
static func prepare(foe: Dictionary, def: Dictionary, state: Dictionary, catalog: Dictionary) -> void:
	var foe_trait: Dictionary = foe.get("trait", {})
	match foe_trait.get("kind", ""):
		"loop-guard":
			foe.loop = loop_start(foe)
		"stack-trace":
			foe.trace = 0
		"lru-cache":
			foe.cache = []
		"lazy":
			foe.pending = 0
		"int8":
			foe.counted = 0
		"allocator":
			foe.allocated = 0
		"call-stack":
			# The frames scale with the foe: a layer's HP factor and the difficulty's, as its HP did.
			var scale := float(foe.max) / maxf(1.0, float(def.hp))
			foe.frames = (foe_trait.frames as Array).map(func(hp: int) -> int: return maxi(1, roundi(hp * scale)))
			foe.push_hp = maxi(1, roundi(int(foe_trait.push) * scale))
			foe.hp = sum_of(foe.frames)
			foe.max = foe.hp
			foe.popped = false
		"compiler":
			RootCompiler.prepare(foe, state, catalog)
	embed_minions(foe.get("intents", []), state, catalog)


## Every summon among `intents` carries the foe it allocates, made now (scaled like its maker), so a summon mid-fight
## needs no catalog.
static func embed_minions(intents: Array, state: Dictionary, catalog: Dictionary) -> void:
	for intent: Dictionary in intents:
		if intent.kind == "summon" and not intent.has("minion"):
			var made := ShardrunBattle.foe_states(state, [intent.foe], "minion", catalog)
			if not made.is_empty():
				intent.minion = made[0]


static func loop_start(foe: Dictionary) -> int:
	for intent: Dictionary in foe.get("intents", []):
		if intent.kind == "loop":
			return int(intent.start)
	return 2


# --- The turn's edges -------------------------------------------------------------------------------------------------


## A turn begins (the first included): this turn's guard, guard value, return slot, target or prediction is chosen
## from the trait's list, pages settle on one resident, and Malloc's blocks shield her.
static func begin_turn(battle: Dictionary) -> void:
	for foe: Dictionary in battle.foes:
		begin_foe(foe, battle)
	settle_pages(battle)


## One foe's part of a turn's beginning (also when the Root Compiler takes on a new trait mid-turn).
static func begin_foe(foe: Dictionary, battle: Dictionary) -> void:
	var turn := int(battle.turn)
	var foe_trait: Dictionary = foe.get("trait", {})
	match foe_trait.get("kind", ""):
		"loop-guard":
			foe.guard = _at(foe_trait.guards, turn)
			foe.broke = false
		"short-circuit":
			foe.guard = int(_at(foe_trait.guards, turn))
		"unreachable":
			foe.return_at = int(_at(foe_trait.returns, turn))
		"certificate":
			foe.target = int(_at(foe_trait.targets, turn))
		"oracle":
			foe.prediction = _at(foe_trait.predictions, turn)
		"allocator":
			var blocks := minions_of(battle, foe).size()
			if blocks > 0 and int(foe.hp) > 0:
				foe.shield = int(foe.shield) + blocks * int(foe_trait.shield_per)


static func _at(cycle: Array, turn: int) -> Variant:
	return cycle[(turn - 1) % cycle.size()]


## A turn ends, after the foes acted: an unbroken loop goes round once more, pending damage decays, a stack that
## lost no frame pushes one (and may overflow), and the page swapped out longest comes back in.
static func end_turn(state: Dictionary, battle: Dictionary) -> void:
	for foe: Dictionary in battle.foes:
		if int(foe.hp) <= 0:
			continue
		var foe_trait: Dictionary = foe.get("trait", {})
		match foe_trait.get("kind", ""):
			"loop-guard":
				if not foe.get("broke", false):
					foe.loop = mini(_loop_max(foe), int(foe.loop) + 1)
					var text := "%s's loop goes around again: %d hits next time." % [foe.name, int(foe.loop)]
					Shardrun.record(state, {"kind": "note", "foe": foe.uid, "text": text})
			"lazy":
				var kept := floori(int(foe.pending) * float(foe_trait.decay))
				if kept < int(foe.pending):
					var text := (
						"%s's unforced thunks are collected: %d pending becomes %d." % [foe.name, foe.pending, kept]
					)
					Shardrun.record(state, {"kind": "note", "foe": foe.uid, "text": text})
				foe.pending = kept
			"call-stack":
				_push_frame(state, battle, foe, foe_trait)
	_swap_in_oldest(state, battle)


static func _loop_max(foe: Dictionary) -> int:
	for intent: Dictionary in foe.get("intents", []):
		if intent.kind == "loop":
			return int(intent.max)
	return 8


static func _push_frame(state: Dictionary, battle: Dictionary, foe: Dictionary, foe_trait: Dictionary) -> void:
	if foe.get("popped", false):
		foe.popped = false
		return
	var frames: Array = foe.frames
	frames.append(int(foe.push_hp))
	var text := "%s calls itself again: a new eval() frame (%d deep)." % [foe.name, frames.size()]
	Shardrun.record(state, {"kind": "note", "foe": foe.uid, "text": text})
	if frames.size() >= int(foe_trait.overflow):
		frames.resize(int(foe_trait.reset))
		var overflow := "Stack Overflow! %s's frames spill over and it drops back to %d." % [foe.name, frames.size()]
		Shardrun.record(state, {"kind": "note", "foe": foe.uid, "text": overflow})
		ShardrunBattle.hit_maintainer(state, battle, foe, int(foe_trait.overflow_power))
	foe.hp = sum_of(frames)
	foe.max = maxi(int(foe.max), int(foe.hp))


# --- Acting -----------------------------------------------------------------------------------------------------------


## A foe's turn when the pool changes it: stunned or recompiling (it does nothing), swapped out, enraged, or one of the
## new intents. Returns whether it was handled here; if not, the ordinary intents run.
static func act(
	state: Dictionary, battle: Dictionary, foe: Dictionary, intent: Dictionary, catalog: Dictionary
) -> bool:
	if foe.get("stunned", false):
		foe.stunned = false
		var text := "%s is stunned and loses its turn." % foe.name
		Shardrun.record(state, {"kind": "note", "foe": foe.uid, "word": "stunned", "text": text})
		return true
	if foe.get("recompiling", false):
		foe.recompiling = false
		var text := "%s is recompiling: it does nothing this turn." % foe.name
		Shardrun.record(state, {"kind": "note", "foe": foe.uid, "word": "recompiling", "text": text})
		return true
	var striking: bool = intent.kind in ["strike", "multi", "loop", "count", "throw"]
	var foe_trait: Dictionary = foe.get("trait", {})
	if foe_trait.get("kind") == PAGED and not foe.get("resident", false) and striking:
		var text := "%s is swapped out of memory and cannot strike." % foe.name
		Shardrun.record(state, {"kind": "note", "foe": foe.uid, "text": text})
		return true
	var enraged := float(foe_trait.get("enrage", 1.0)) if foe.get("enraged", false) else 1.0
	match intent.kind:
		"strike":
			if enraged == 1.0:
				return false
			var power := floori(int(intent.power) * (2 if foe.stoked else 1) * enraged)
			foe.stoked = false
			ShardrunBattle.hit_maintainer(state, battle, foe, power)
		"multi":
			if enraged == 1.0:
				return false
			_hits(state, battle, foe, floori(int(intent.power) * enraged), int(intent.times))
		"loop":
			_hits(state, battle, foe, int(intent.power), int(foe.get("loop", intent.start)))
		"throw":
			_throw(state, battle, foe, intent, foe_trait)
		"summon":
			_summon(state, battle, foe, intent, foe_trait)
		"realloc":
			var blocks := minions_of(battle, foe).size()
			var healed := mini(int(foe.max) - int(foe.hp), blocks * int(intent.amount))
			foe.hp += healed
			var text := "%s reallocs: %d HP from %d blocks." % [foe.name, healed, blocks]
			Shardrun.record(state, {"kind": "heal", "foe": foe.uid, "amount": healed, "text": text})
		"mend-swapped":
			for page: Dictionary in _group(battle, foe):
				if page.get("resident", false) or int(page.hp) <= 0:
					continue
				var healed := mini(int(page.max) - int(page.hp), int(intent.amount))
				page.hp += healed
				var text := "%s mends %d while it is swapped out." % [page.name, healed]
				Shardrun.record(state, {"kind": "heal", "foe": page.uid, "amount": healed, "text": text})
		"count":
			var power := int(intent.power) * (1 << int(foe.get("counted", 0)))
			if power >= int(intent.wrap):
				foe.counted = 0
				var text := "Overflow fault: %s's count wraps to %d and it does nothing." % [foe.name, power - 256]
				Shardrun.record(state, {"kind": "note", "foe": foe.uid, "word": "overflow", "text": text})
			else:
				foe.counted = int(foe.get("counted", 0)) + 1
				ShardrunBattle.hit_maintainer(state, battle, foe, power)
		"mutate":
			_mutate(state, battle, foe, int(intent.count), catalog)
		"idle":
			pass
		_:
			return false
	return true


static func _hits(state: Dictionary, battle: Dictionary, foe: Dictionary, power: int, times: int) -> void:
	var i := 0
	while i < times and int(state.integrity) > 0:
		ShardrunBattle.hit_maintainer(state, battle, foe, power)
		i += 1


## `raise`: caught by block at least its power (the block is spent and it bounces back into the thrower), or it hits
## and the stack trace grows.
static func _throw(
	state: Dictionary, battle: Dictionary, foe: Dictionary, intent: Dictionary, foe_trait: Dictionary
) -> void:
	var power := int(intent.power) + int(foe.get("trace", 0))
	if int(battle.block) >= power:
		battle.block = int(battle.block) - power
		var bounce := mini(int(foe.hp), floori(power * float(foe_trait.get("bounce", 1.5))))
		foe.hp = int(foe.hp) - bounce
		var text := (
			"Caught! Your block handles the %d-power throw, and it bounces back: %s takes %d."
			% [power, foe.name, bounce]
		)
		Shardrun.record(state, {"kind": "note", "foe": foe.uid, "word": "caught", "amount": bounce, "text": text})
		if int(foe.hp) == 0:
			Shardrun.record(state, {"kind": "defeat", "foe": foe.uid, "text": "%s breaks apart." % foe.name})
		return
	ShardrunBattle.hit_maintainer(state, battle, foe, power)
	foe.trace = mini(int(foe_trait.get("max", 8)), int(foe.get("trace", 0)) + int(foe_trait.get("grow", 2)))
	var grown := "Uncaught: the stack trace grows. Its throws hit +%d now." % int(foe.trace)
	Shardrun.record(state, {"kind": "note", "foe": foe.uid, "text": grown})


## `malloc()`: a new block beside its maker (inserted after it, so the foes behind shift along); at the limit, Out of
## Memory: a hit for every block, and every block is freed.
static func _summon(
	state: Dictionary, battle: Dictionary, foe: Dictionary, intent: Dictionary, foe_trait: Dictionary
) -> void:
	if not intent.has("minion"):
		return
	var block: Dictionary = (intent.minion as Dictionary).duplicate(true)
	block.uid = "%s-m%d" % [foe.uid, int(foe.get("allocated", 0))]
	block.owner = foe.uid
	block.intent_index = 0
	foe.allocated = int(foe.get("allocated", 0)) + 1
	var foes: Array = battle.foes
	foes.insert(foes.find(foe) + 1, block)
	var text := "%s allocates a %s." % [foe.name, block.name]
	Shardrun.record(state, {"kind": "summon", "foe": block.uid, "text": text})
	var blocks := minions_of(battle, foe)
	if foe_trait.get("kind") != "allocator" or blocks.size() < int(foe_trait.limit):
		return
	var power := blocks.size() * int(foe_trait.oom_power)
	var oom := "Out of Memory! %s's %d blocks give way." % [foe.name, blocks.size()]
	Shardrun.record(state, {"kind": "note", "foe": foe.uid, "word": "out of memory", "text": oom})
	ShardrunBattle.hit_maintainer(state, battle, foe, power)
	for freed: Dictionary in blocks:
		freed.hp = 0
		Shardrun.record(state, {"kind": "defeat", "foe": freed.uid, "text": "%s is freed." % freed.name})


## The living foes a foe allocated.
static func minions_of(battle: Dictionary, foe: Dictionary) -> Array:
	return (battle.foes as Array).filter(
		func(other: Dictionary) -> bool: return other.get("owner", "") == foe.uid and int(other.hp) > 0
	)


## `mutate`: `count` cards of the deck that the next hand will hold (the hand, then the top of the draw pile) become
## mutants for the fight. Each card is mutated once; the operator is drawn from the run's seed.
static func _mutate(state: Dictionary, battle: Dictionary, foe: Dictionary, count: int, catalog: Dictionary) -> void:
	if not battle.has("mutants"):
		battle.mutants = {}
	var mutants: Dictionary = battle.mutants
	var candidates: Array = []
	for id: String in (battle.get("hand", []) as Array) + (battle.get("draw", []) as Array).slice(0, 6):
		if mutants.has(id) or id in candidates:
			continue
		if not safe_mutants(id, state.language, catalog).is_empty():
			candidates.append(id)
	var rng := Rng.create(state.seed, "mutate:%s:%d" % [foe.uid, int(battle.turn)])
	var made: Array[String] = []
	while made.size() < count and not candidates.is_empty():
		var id: String = candidates.pop_at(floori(rng.next() * candidates.size()))
		var safe := safe_mutants(id, state.language, catalog)
		var op := int(safe[floori(rng.next() * safe.size())])
		var card: Dictionary = catalog.shards[id]
		var mutant := ProgramMutants.mutate(String(card.code[state.language]), state.language, op)
		mutants[id] = {"op": int(mutant.op), "name": mutant.name}
		made.append(String(card.get("name", id)))
	if made.is_empty():
		Shardrun.record(state, {"kind": "note", "foe": foe.uid, "text": "%s finds nothing left to mutate." % foe.name})
		return
	var text := "%s mutates %s: they run as changed until a program kills them." % [foe.name, " and ".join(made)]
	Shardrun.record(state, {"kind": "note", "foe": foe.uid, "word": "mutate", "text": text})


## The operators a card may be mutated by in `language`: the census's (programs/mutants.jsonc), the mutants known to
## still run. A card the census does not list has none.
static func safe_mutants(id: String, language: String, catalog: Dictionary) -> Array:
	var census: Dictionary = ((catalog.get("programs", {}) as Dictionary).get("mutants", {}) as Dictionary).get(
		language, {}
	)
	return census.get(id, [])


# --- Pages ------------------------------------------------------------------------------------------------------------


## The living foes of a paged foe's group, itself included.
static func _group(battle: Dictionary, foe: Dictionary) -> Array:
	var group: String = (foe.get("trait", {}) as Dictionary).get("group", "")
	return (battle.foes as Array).filter(
		func(other: Dictionary) -> bool:
			return (other.get("trait", {}) as Dictionary).get("group", "") == group and int(other.hp) > 0
	)


## Every group of pages with exactly one resident: the first living page, when none is.
static func settle_pages(battle: Dictionary) -> void:
	for foe: Dictionary in battle.foes:
		if (foe.get("trait", {}) as Dictionary).get("kind") != PAGED or int(foe.hp) <= 0:
			continue
		var group := _group(battle, foe)
		if not group.any(func(page: Dictionary) -> bool: return page.get("resident", false)):
			(group[0] as Dictionary).resident = true


## Makes `page` the resident one of its group, swapping out the one that was.
static func swap_in(battle: Dictionary, page: Dictionary) -> void:
	for other: Dictionary in _group(battle, page):
		if other.get("resident", false) and other != page:
			other.resident = false
			other.out_since = int(battle.turn)
	page.resident = true


static func _swap_in_oldest(state: Dictionary, battle: Dictionary) -> void:
	var seen := {}
	for foe: Dictionary in battle.foes:
		var foe_trait: Dictionary = foe.get("trait", {})
		if foe_trait.get("kind") != PAGED or int(foe.hp) <= 0 or seen.has(foe_trait.group):
			continue
		seen[foe_trait.group] = true
		var oldest: Dictionary = {}
		for page: Dictionary in _group(battle, foe):
			if page.get("resident", false):
				continue
			if oldest.is_empty() or int(page.get("out_since", 0)) < int(oldest.get("out_since", 0)):
				oldest = page
		if not oldest.is_empty():
			swap_in(battle, oldest)
			Shardrun.record(state, {"kind": "note", "foe": oldest.uid, "text": "%s is swapped in." % oldest.name})


# --- What the program meets -------------------------------------------------------------------------------------------


## The first step of a program that is dead code this turn (a living Unreachable's `return`, slots counted from 1), or
## -1 when every step runs.
static func dead_from(battle: Dictionary) -> int:
	var cut := -1
	for foe: Dictionary in battle.get("foes", []):
		if int(foe.hp) > 0 and (foe.get("trait", {}) as Dictionary).get("kind") == "unreachable":
			var at := int(foe.get("return_at", 99)) - 1
			cut = at if cut < 0 else mini(cut, at)
	return cut


## A card's code as it runs in this fight: its mutant's while the Mutator's edit stands, else its own.
static func code_of(card: Dictionary, language: String, battle: Dictionary) -> String:
	var code := String((card.get("code", {}) as Dictionary).get(language, ""))
	var mutant: Dictionary = (battle.get("mutants", {}) as Dictionary).get(card.get("id", ""), {})
	if mutant.is_empty():
		return code
	var mutated := ProgramMutants.mutate(code, language, int(mutant.op))
	return String(mutated.get("code", code))


static func sum_of(values: Array) -> int:
	var total := 0
	for value: int in values:
		total += value
	return total
