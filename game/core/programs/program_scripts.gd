class_name ProgramScripts
extends RefCounted
## Scripts, a program run's one-use commands (Paradigm Update, B12): a belt of three, found after fights and sold at the
## Registry, each named after a real command that does roughly that thing. A script is not a card: it costs no mana,
## takes no slot and is used on your turn at any moment before the cast, taking effect at once. What it changes is kept
## in the battle (`battle.nice`, `battle.double_next`, ...) so the preview, which plays a copy, shows it.
## Pure and seeded: a drop and a stock come from the run's seed.

const FIGHT_ONLY := ["fight"]


static func catalog_of(catalog: Dictionary) -> Dictionary:
	return (catalog.programs as Dictionary).get("scripts", {})


static func rules(catalog: Dictionary) -> Dictionary:
	return ProgramRules.config_of(catalog).scripts


static func belt_size(state: Dictionary, catalog: Dictionary) -> int:
	return int(rules(catalog).belt) + int(ProgramRelics.modifiers(state, catalog).belt_extra)


## Puts a script on the belt. False when the belt is full.
static func give(state: Dictionary, id: String, catalog: Dictionary) -> bool:
	var belt: Array = state.get("belt", [])
	if belt.size() >= belt_size(state, catalog) or not catalog_of(catalog).has(id):
		return false
	belt.append(id)
	state.belt = belt
	return true


## Drops the script at `index` from the belt (the player's choice, to make room).
static func drop_at(state: Dictionary, index: int) -> bool:
	var belt: Array = state.get("belt", [])
	if index < 0 or index >= belt.size():
		return false
	belt.remove_at(index)
	return true


## `count` distinct scripts by rarity weights (none the belt holds twice over is excluded only by distinctness here).
static func draft(count: int, rng: Rng, catalog: Dictionary, minimum := "common") -> Array:
	var weights_by: Dictionary = rules(catalog).rarity
	var floor_at := ProgramSchemas.SCRIPT_RARITIES.find(minimum)
	var tiers: Array[String] = []
	var weights: Array[float] = []
	for rarity: String in ProgramSchemas.SCRIPT_RARITIES:
		if ProgramSchemas.SCRIPT_RARITIES.find(rarity) >= floor_at:
			tiers.append(rarity)
			weights.append(float(weights_by.get(rarity, 0.0)))
	var pool := ShardrunCatalog.sorted_values(catalog_of(catalog))
	var chosen: Array = []
	var attempts := 0
	while chosen.size() < count and attempts < 60:
		attempts += 1
		var index := Rng.pick_weighted(weights, rng.next())
		if index < 0:
			break
		var left := pool.filter(
			func(script: Dictionary) -> bool: return script.rarity == tiers[index] and not script.id in chosen
		)
		var pick := floori(rng.next() * left.size())
		if pick < left.size():
			chosen.append((left[pick] as Dictionary).id)
	return chosen


## A script a won fight leaves behind, or "": 30% (more each fight without one), 60% after an elite, always after a
## guardian. Updates the run's pity; the drop goes to the belt when there is room (the screen asks otherwise).
static func fight_drop(state: Dictionary, kind: String, catalog: Dictionary) -> String:
	var chances: Dictionary = rules(catalog).drop
	var chance := float(chances.get(kind, chances.fight))
	if kind == "fight":
		chance += float(state.get("script_pity", 0.0))
	var rng := Rng.create(state.seed, "script-drop:%d:%d" % [state.layer, (state.visited as Array).size()])
	var dropped := kind == "boss" or rng.next() < chance
	if kind == "fight":
		state.script_pity = 0.0 if dropped else float(state.get("script_pity", 0.0)) + float(rules(catalog).step)
	if not dropped:
		return ""
	var found := draft(1, rng, catalog)
	return String(found[0]) if not found.is_empty() else ""


## Uses the script at `index`, aimed at the foe `target` when it needs one. {} when it worked, else {code, message}.
static func use(state: Dictionary, index: int, target: String, catalog: Dictionary) -> Dictionary:
	var belt: Array = state.get("belt", [])
	if index < 0 or index >= belt.size():
		return _no("no-script", "There is no script in that slot.")
	var script: Dictionary = catalog_of(catalog).get(belt[index], {})
	if script.is_empty():
		return _no("unknown-script", "That script is not known.")
	var fight: bool = state.status == "battle" and state.has("battle")
	if script.when == "fight" and not fight:
		return _no("not-in-battle", "%s can only be used in a fight." % script.name)
	if script.when == "anywhere" and state.status in ["won", "lost", "abandoned", "draft"]:
		return _no("not-now", "%s cannot be used now." % script.name)
	var foe: Dictionary = {}
	if script.target == "foe":
		var foes: Array = state.battle.foes if fight else []
		for candidate: Dictionary in foes:
			if candidate.uid == target and int(candidate.hp) > 0:
				foe = candidate
		if foe.is_empty():
			return _no("needs-target", "%s needs a foe to aim at." % script.name)
	var spent: Dictionary = script.effect
	var note := _effect(state, spent, foe, catalog)
	if note.has("code"):
		return note
	belt.remove_at(index)
	state.belt = belt
	Shardrun.record(state, {"kind": "note", "text": "%s: %s" % [script.name, String(note.get("text", ""))]})
	if fight and ProgramRelics.modifiers(state, catalog).script_refund and not state.battle.get("refunded", false):
		state.battle.refunded = true
		state.battle.refund = script.id
	return {}


## The effect of one script. Returns {text} when it worked, {code, message} when it could not.
static func _effect(state: Dictionary, effect: Dictionary, foe: Dictionary, catalog: Dictionary) -> Dictionary:
	var battle: Dictionary = state.get("battle", {})
	match effect.kind:
		"heal":
			var healed := mini(int(state.integrity_max) - int(state.integrity), int(effect.amount))
			state.integrity += healed
			return {"text": "you recover %d Integrity." % healed}
		"hand-card":
			var id := String(effect.card)
			(battle.hand as Array).append(id)
			battle.free_cards = (battle.get("free_cards", []) as Array) + [id]
			return {"text": "%s joins your hand, free this turn." % _name(id, catalog)}
		"reveal-intents":
			for each: Dictionary in battle.foes:
				if int(each.hp) > 0:
					Shardrun.record(state, {"kind": "note", "text": "%s: %s" % [each.name, _next_two(each)]})
			return {"text": "every foe's next two moves are in the log."}
		"foe-half":
			foe.ulimit = true
			return {"text": "%s's next attack deals half." % foe.name}
		"draw":
			ShardrunBattle.draw(state, battle, int(effect.count), catalog)
			return {"text": "you draw %d cards." % int(effect.count)}
		"free-card":
			return _free_card(state, battle, catalog)
		"revert":
			var undone := mini(int(effect.max), int(battle.get("hurt_last", 0)))
			state.integrity = mini(int(state.integrity_max), int(state.integrity) + undone)
			battle.hurt_last = 0
			return {"text": "last turn's damage is undone: %d Integrity." % undone}
		"nice":
			battle.nice = true
			return {"text": "this turn your program counts as no work."}
		"foe-damage":
			return _strike(state, battle, foe, int(effect.amount), catalog)
		"trait-off":
			if foe.has("trait"):
				foe.trait_saved = foe.trait
				foe.erase("trait")
			return {"text": "%s's trait is off until your next turn." % foe.name}
		"double-next":
			battle.double_next = true
			return {"text": "your next program deals double."}
		"free-program":
			battle.free_program = true
			return {"text": "your next program costs no mana."}
		"gc":
			return _collect(state, battle)
		"stash-hand":
			battle.stashed = (battle.hand as Array).duplicate()
			battle.hand = []
			return {"text": "your hand is set aside until next turn."}
		"work-divide":
			battle.jobs = int(effect.divisor)
			return {"text": "this turn your program's work is divided by %d." % int(effect.divisor)}
		"shed-curses":
			battle.no_curses = true
			return {"text": "your curses are off for this fight."}
	return _no("unknown-effect", "That script does nothing.")


static func _free_card(state: Dictionary, battle: Dictionary, catalog: Dictionary) -> Dictionary:
	var pool := ShardrunCatalog.sorted_values(catalog.shards).filter(
		func(card: Dictionary) -> bool:
			return card.get("draftable", true) and card.get("paradigm", "") == state.get("paradigm", "")
	)
	if pool.is_empty():
		return _no("nothing-to-install", "There is no package of your paradigm to install.")
	var rng := Rng.create(state.seed, "script-pip:%d:%d" % [int(state.revision), int(battle.turn)])
	var card: Dictionary = pool[floori(rng.next() * pool.size())]
	(battle.hand as Array).append(card.id)
	battle.free_cards = (battle.get("free_cards", []) as Array) + [card.id]
	return {"text": "%s is installed in your hand, free this turn." % card.name}


## 25 damage and the like: straight to a foe's HP, shield and all.
static func _strike(
	state: Dictionary, battle: Dictionary, foe: Dictionary, amount: int, catalog: Dictionary
) -> Dictionary:
	var landed := mini(amount, int(foe.hp))
	foe.hp -= landed
	Shardrun.record(
		state, {"kind": "hit", "foe": foe.uid, "amount": landed, "text": "%s takes %d." % [foe.name, landed]}
	)
	if int(foe.hp) == 0:
		Shardrun.record(state, {"kind": "defeat", "foe": foe.uid, "text": "%s breaks apart." % foe.name})
		if (battle.foes as Array).all(func(each: Dictionary) -> bool: return int(each.hp) == 0):
			ShardrunBattle.win(state, battle, catalog)
	return {"text": "%s takes %d." % [foe.name, landed]}


## gc.collect(): what it frees depends on what your paradigm keeps (the Index, the Table), else block.
static func _collect(state: Dictionary, battle: Dictionary) -> Dictionary:
	var index: Array = battle.get("index", [])
	var rows: Array = battle.get("dp", [])
	if state.get("paradigm", "") == "search-index" and not index.is_empty():
		battle.gc_seed = index.duplicate(true)
		battle.index = []
		return {"text": "the Index is emptied into your next program's seed."}
	if state.get("paradigm", "") == "dynamic" and not rows.is_empty():
		var best := 0
		for row: int in rows:
			best = maxi(best, row)
		rows.append(best)
		battle.dp = rows
		return {"text": "a free row of %d joins the Table." % best}
	battle.block += 10
	return {"text": "10 block."}


static func _name(card_id: String, catalog: Dictionary) -> String:
	return String((catalog.shards.get(card_id, {}) as Dictionary).get("name", card_id))


static func _next_two(foe: Dictionary) -> String:
	var intents: Array = foe.intents
	var words: Array[String] = []
	for step in 2:
		var intent: Dictionary = intents[(int(foe.intent_index) + step) % intents.size()]
		words.append(_intent_word(intent))
	return "%s, then %s" % words


static func _intent_word(intent: Dictionary) -> String:
	match intent.kind:
		"strike":
			return "strikes for %d" % int(intent.power)
		"multi":
			return "strikes %d times for %d" % [int(intent.times), int(intent.power)]
		"shield":
			return "raises a %d shield" % int(intent.amount)
		"heal":
			return "mends %d" % int(intent.amount)
	return String(intent.kind)


static func _no(code: String, message: String) -> Dictionary:
	return {"code": code, "message": message}


# --- The battle's side of a script (called from the rules that read these flags) -----------------------------------


## A new turn: this turn's scripts wear off, traits come back, a stashed hand returns on top of the new one.
static func new_turn(battle: Dictionary) -> void:
	for flag: String in ["nice", "jobs", "free_cards"]:
		battle.erase(flag)
	battle.hurt_last = int(battle.get("hurt_turn", 0))
	battle.hurt_turn = 0
	for foe: Dictionary in battle.foes:
		if foe.has("trait_saved"):
			foe.trait = foe.trait_saved
			foe.erase("trait_saved")


## The hand a stashed one rejoins, after the new turn's draw.
static func restore_hand(battle: Dictionary) -> void:
	if battle.has("stashed"):
		var hand: Array = (battle.stashed as Array).duplicate()
		hand.append_array(battle.hand)
		battle.hand = hand
		battle.erase("stashed")
