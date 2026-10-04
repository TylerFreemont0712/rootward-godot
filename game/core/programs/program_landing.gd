class_name ProgramLanding
extends RefCounted
## The program landing shared by cast and preview. Keeps memory and law hooks beside damage resolution.


static func resolve(
	state: Dictionary, battle: Dictionary, bolts: Array[Dictionary], catalog: Dictionary, context := {}
) -> Dictionary:
	var balance: Dictionary = catalog.balance
	var m := ShardrunRules.relic_modifiers(state, catalog)
	var relics := ProgramRelics.modifiers(state, catalog)
	var accepted: Array[Dictionary] = []
	for bolt in bolts:
		if ProgramMemory.withdraw(battle, bolt, relics):
			accepted.append(bolt)
	var landing := ProgramRelics.landing(accepted, relics)
	var program_factor := ProgramRelics.program_factor(landing, context, relics)
	var hottest := ProgramRelics.strongest(landing) if float(relics.strongest_mult) != 1.0 else -1
	var out_sped: Array = context.get("out_sped", [])
	var first := ProgramRules.initiative(state, catalog)
	var alive := (battle.foes as Array).filter(func(foe: Dictionary) -> bool: return int(foe.hp) > 0)
	var targeted := ProgramRules.targets(landing, alive)
	var extra := 0
	for rule: Dictionary in relics.work_power:
		extra += (int(context.get("work", 0)) / int(rule.every)) * int(rule.add)
	if not alive.is_empty() and targeted.size() == alive.size():
		extra += int(relics.full_spread_power)
	for bolt: Dictionary in landing:
		if bolt.get("block", false) or bolt.get("stash", false):
			continue
		bolt.power += extra
		if bolt.get("pivot", false) and float(relics.pivot_factor) != 1.0 and not alive.is_empty():
			var toughest := 0
			for i in alive.size():
				if int(alive[i].hp) > int(alive[toughest].hp):
					toughest = i
			bolt.foe = toughest
			bolt.power = floori(int(bolt.power) * float(relics.pivot_factor))
	targeted = ProgramRules.targets(landing, alive)
	# The guardian pool judges the whole volley before a bolt flies (ADR-0026).
	var attacking: Array[Dictionary] = []
	for bolt in landing:
		if not bolt.get("stash", false):
			attacking.append(bolt)
	var plan := GuardianLanding.plan(attacking, alive, context, int(m.bolt_power))
	var dealt := 0
	var wasted := 0
	var gathered := 0
	var locked := 0
	var fixed := 0
	var exact_damage := 0
	var damage_by_foe := {}
	for index in landing.size():
		var bolt: Dictionary = landing[index]
		var power := int(bolt.power) + int(m.bolt_power)
		if bolt.get("stash", false):
			ProgramMemory.stash(battle, bolt, power, relics, true)
			continue
		var shape := {"bolt": index, "target": "front"}
		if bolt.get("block", false):
			battle.block += power
			gathered += power
			var ward := {
				"kind": "ward", "amount": power, "element": bolt.element, "text": "A ward gathers %d block." % power
			}
			ward.merge(shape)
			Shardrun.record(state, ward)
			continue
		if alive.is_empty():
			ProgramMemory.stash(battle, bolt, power, relics)
			wasted += power
			continue
		var at := int(bolt.get("foe", 0))
		var foe: Dictionary = alive[at] if at < alive.size() else alive[0]
		if int(foe.hp) == 0:
			wasted += power
			ProgramMemory.stash(battle, bolt, power, relics)
			var gone := {"kind": "wasted", "foe": foe.uid, "amount": power, "element": bolt.element}
			gone.merge(shape)
			gone.text = "%d power flies at %s, already down." % [power, foe.name]
			Shardrun.record(state, gone)
			continue
		if bolt.element in foe.weak:
			power += int(relics.weak_flat_bonus)
		var foe_trait: Dictionary = foe.get("trait", {})
		if foe_trait.get("kind") == "nullify-first" and not foe.nullified:
			foe.nullified = true
			var absorb := {"kind": "absorb", "foe": foe.uid, "element": bolt.element}
			absorb.merge(shape)
			absorb.text = "%s swallows the first bolt whole." % foe.name
			Shardrun.record(state, absorb)
			continue
		if ProgramRules.fixed_point(foe, context):
			fixed += 1
			var same := {"kind": "absorb", "foe": foe.uid, "element": bolt.element, "word": "fixed point"}
			same.merge(shape)
			same.text = "%s recognises its own source: the same program cannot hurt it." % foe.name
			Shardrun.record(state, same)
			continue
		if foe_trait.get("kind") == "thick-hide" and power < int(foe_trait.threshold):
			var glance := {"kind": "glance", "foe": foe.uid, "element": bolt.element}
			glance.merge(shape)
			glance.text = "A %d-power bolt glances off %s." % [power, foe.name]
			Shardrun.record(state, glance)
			continue
		var holder := ProgramRules.lock_holder(foe, alive, targeted)
		if not holder.is_empty():
			locked += 1
			var held := {"kind": "locked", "foe": foe.uid, "amount": power, "element": bolt.element}
			held.merge(shape)
			held.text = "%s holds its lock: this program never touches %s." % [foe.name, holder.name]
			Shardrun.record(state, held)
			continue
		var verdict := GuardianLanding.bolt(state, battle, foe, bolt, index, power, plan, shape)
		if verdict.skip:
			continue
		var multiplier: float = m.damage_multiplier * program_factor * float(verdict.factor)
		if index == hottest:
			multiplier *= float(relics.strongest_mult)
		var first_strike: bool = foe.uid in out_sped
		if first_strike:
			multiplier *= first
		if foe_trait.get("kind") == "pattern-ward" and bolt.element != foe.get("pattern"):
			multiplier *= float(ProgramRules.config_of(catalog).get("pattern_off", balance.pattern_off_multiplier))
		# A relic can make every bolt the element a foe is weak to (and then nothing resists it).
		var weak: bool = bolt.element in foe.weak or (relics.all_elements and not (foe.weak as Array).is_empty())
		var resisted: bool = not weak and bolt.element in foe.resist
		if weak:
			multiplier *= float(balance.weak_multiplier) + m.weak_bonus
		elif resisted:
			multiplier *= float(balance.resist_multiplier)
		var damage := floori(power * multiplier)
		var own := GuardianLanding.body(state, foe, damage, power, bolt.element, shape)
		if not own.is_empty():
			dealt += int(own.dealt)
			damage_by_foe[foe.uid] = int(damage_by_foe.get(foe.uid, 0)) + int(own.dealt)
			wasted += int(own.wasted)
			ProgramMemory.hit(battle, foe, bolt, int(own.dealt))
			ProgramMemory.stash(battle, bolt, int(own.wasted), relics)
			if int(foe.hp) == 0 and int(own.wasted) == 0:
				exact_damage += int(damage_by_foe.get(foe.uid, 0))
				battle.block += int(relics.exact_kill_block)
				gathered += int(relics.exact_kill_block)
			GuardianLanding.count(plan, foe, int(own.dealt))
			GuardianLanding.after_hit(battle, alive, foe)
			if int(foe.hp) == 0:
				GuardianLanding.on_defeat(state, battle, foe)
			continue
		var blocked := mini(int(foe.shield), damage)
		foe.shield -= blocked
		damage -= blocked
		var landed := mini(damage, int(foe.hp))
		foe.hp -= landed
		dealt += landed
		damage_by_foe[foe.uid] = int(damage_by_foe.get(foe.uid, 0)) + landed
		ProgramMemory.hit(battle, foe, bolt, landed)
		var hit := {"kind": "hit", "foe": foe.uid, "amount": landed, "element": bolt.element}
		hit.merge(shape)
		if first_strike and first != 1.0:
			hit.initiative = true
		if weak:
			hit.affinity = "weak"
		elif resisted:
			hit.affinity = "resist"
		if blocked > 0:
			hit.blocked = blocked
		if damage > landed:
			hit.overkill = damage - landed
		var shield_note := " (%d into its shield)" % blocked if blocked > 0 else ""
		hit.text = "%s takes %d%s." % [foe.name, landed, shield_note]
		if hit.has("initiative"):
			hit.text = "Initiative: %s takes %d%s." % [foe.name, landed, shield_note]
		Shardrun.record(state, hit)
		GuardianLanding.count(plan, foe, landed)
		if int(foe.hp) == 0:
			if damage == landed:
				exact_damage += int(damage_by_foe.get(foe.uid, 0))
				battle.block += int(relics.exact_kill_block)
				gathered += int(relics.exact_kill_block)
			Shardrun.record(state, {"kind": "defeat", "foe": foe.uid, "text": "%s breaks apart." % foe.name})
			GuardianLanding.on_defeat(state, battle, foe)
		GuardianLanding.after_hit(battle, alive, foe)
		var spill := damage - landed
		if relics.overkill_flows:
			var flowed := ProgramRules._flow(state, alive, foe, spill, bolt.element, shape)
			spill = int(flowed.spill)
			dealt += int(flowed.dealt)
			for uid: String in flowed.damage:
				damage_by_foe[uid] = int(damage_by_foe.get(uid, 0)) + int(flowed.damage[uid])
			for uid: String in flowed.exact:
				exact_damage += int(damage_by_foe.get(uid, 0))
				battle.block += int(relics.exact_kill_block)
				gathered += int(relics.exact_kill_block)
		wasted += spill
		ProgramMemory.stash(battle, bolt, spill, relics)
	if float(relics.wasted_to_block) > 0.0 and wasted > 0:
		var kept := floori(wasted * float(relics.wasted_to_block))
		if kept > 0:
			battle.block += kept
			gathered += kept
			var text := "The unused %d power is kept as block." % kept
			Shardrun.record(state, {"kind": "ward", "amount": kept, "element": "none", "text": text})
	dealt += GuardianLanding.finish(state, battle, plan, context)
	ProgramMemory.row(battle, dealt, exact_damage, relics)
	# Local Optimum counts the foes this program broke before they could act, however they fell (overflow included).
	var initiative_kills := 0
	var acted: Array = battle.get("acted", [])
	for foe: Dictionary in alive:
		if int(foe.hp) == 0 and foe.uid in out_sped and not foe.uid in acted:
			initiative_kills += 1
	ProgramMemory.initiative_mana(battle, initiative_kills, relics)
	var kills := alive.filter(func(foe: Dictionary) -> bool: return int(foe.hp) == 0).size()
	return {
		"dealt": dealt,
		"wasted": wasted,
		"block": gathered,
		"kills": kills,
		"locked": locked,
		"fixed": fixed,
		"notes": plan.notes,
	}
