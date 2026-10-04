class_name ProgramMemory
extends RefCounted
## Fight memory is plain saved data. Reading a seed is pure; only playing it spends the indexed bolts.


static func remaining_index(state: Dictionary, catalog: Dictionary) -> Array:
	var bank: Array = ((state.get("battle", {}) as Dictionary).get("index", []) as Array).duplicate(true)
	var m := ProgramRelics.modifiers(state, catalog)
	if m.index:
		bank.resize(maxi(0, bank.size() - int(m.index_seed)))
	return bank


static func begin(state: Dictionary, battle: Dictionary, catalog: Dictionary) -> void:
	var m := ProgramRelics.modifiers(state, catalog)
	if m.index:
		battle.index = remaining_index(state, catalog)
	battle.last_volley = []


static func stash(battle: Dictionary, bolt: Dictionary, power: int, m: Dictionary, explicit := false) -> void:
	if (not m.index and not explicit) or power <= 0:
		return
	var bank: Array = battle.get("index", [])
	var clean := {"power": power, "element": bolt.element}
	var at := 0
	while at < bank.size() and int(bank[at].power) <= power:
		at += 1
	bank.insert(at, clean)
	while bank.size() > int(m.index_size):
		bank.pop_front()
	battle.index = bank


## A card's from_index flag is a request, never permission to invent a bolt or withdraw it twice.
static func withdraw(battle: Dictionary, bolt: Dictionary, _m: Dictionary) -> bool:
	if not bolt.get("from_index", false):
		return true
	var bank: Array = battle.get("index", [])
	for i in bank.size():
		if int(bank[i].power) == int(bolt.power) and bank[i].element == bolt.element:
			bank.remove_at(i)
			battle.index = bank
			return true
	return false


static func hit(battle: Dictionary, foe: Dictionary, bolt: Dictionary, damage: int) -> void:
	if damage <= 0:
		return
	var hits: Dictionary = battle.get("hits", {})
	hits[foe.uid] = int(hits.get(foe.uid, 0)) + 1
	battle.hits = hits
	var volley: Array = battle.get("last_volley", [])
	volley.append(int(bolt.power))
	battle.last_volley = volley


static func row(battle: Dictionary, damage: int, exact_damage: int, m: Dictionary) -> void:
	var rows: Array = battle.get("dp", [])
	rows.append(damage + exact_damage * (int(m.exact_kill_factor) - 1))
	battle.dp = rows


static func initiative_mana(battle: Dictionary, kills: int, m: Dictionary) -> void:
	if kills <= 0 or int(m.kill_initiative_mana) <= 0:
		return
	# This law has its own turn cap. Other mana relics do not consume its allowance.
	var already := int(battle.get("initiative_mana", 0))
	var earned := mini(maxi(0, int(m.kill_initiative_max) - already), kills * int(m.kill_initiative_mana))
	battle.initiative_mana = already + earned
	battle.bonus_mana = int(battle.get("bonus_mana", 0)) + earned
