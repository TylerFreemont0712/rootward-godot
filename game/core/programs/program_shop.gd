class_name ProgramShop
extends RefCounted
## The Registry, a program run's shop (Paradigm Update, B7), kept by Semver the owl: cards (two of your paradigm, one
## neutral, one of another paradigm, one of any), relics, scripts, and three services (`uninstall`, `refactor`,
## `pip install`). Prices are cycles. The stock is drawn from the run's seed and the room, so it is the same on every
## visit and after every load; a bought item leaves its shelf and nothing restocks.
##
## The shop is plain data on the run (`state.shop`): {room, cards: [{id, price, sale?, sold?}], relics: [...],
## scripts: [...], pip?: {paradigm, cards}}. Commands (ShardrunCommands): buy {shelf, index}, shop-service {kind,
## card_id?, paradigm?}, pip-take {card_id}, leave-shop.


static func rules(catalog: Dictionary) -> Dictionary:
	return ProgramRules.config_of(catalog).registry


## Walks into a Registry: the stock is made now and the run waits in it.
static func enter(state: Dictionary, node: Dictionary, catalog: Dictionary) -> void:
	var m := ProgramRelics.modifiers(state, catalog)
	state.shop = stock(state, String(node.id), catalog)
	state.status = "shop"
	Shardrun.record(
		state, {"kind": "enter", "text": "The Registry: drawers of signed packages, and a small brass owl."}
	)
	var toll := int(m.get("registry_toll", 0))
	if toll > 0:
		state.integrity_max = maxi(1, int(state.integrity_max) - toll)
		state.integrity = mini(int(state.integrity), int(state.integrity_max))
		Shardrun.record(
			state, {"kind": "curse", "amount": toll, "text": "Venture capital takes %d max Integrity." % toll}
		)
	var interest := float(m.get("interest", 0.0))
	if interest > 0.0:
		var gained := mini(int(m.get("interest_max", 0)), floori(int(state.get("cycles", 0)) * interest))
		ProgramCycles.earn(state, gained)
		if gained > 0:
			Shardrun.record(state, {"kind": "note", "amount": gained, "text": "Interest pays %d cycles." % gained})


## The shelves of the Registry in room `room_id`.
static func stock(state: Dictionary, room_id: String, catalog: Dictionary) -> Dictionary:
	var r := rules(catalog)
	var m := ProgramRelics.modifiers(state, catalog)
	var rng := Rng.create(state.seed, "registry:%s" % room_id)
	var pool := ShardrunCatalog.sorted_values(catalog.shards).filter(
		func(card: Dictionary) -> bool: return card.get("draftable", true)
	)
	var cards: Array = _cards(state, pool, int(r.cards) + int(m.shop_cards), r, rng)
	var sale := floori(rng.next() * cards.size())
	for index in cards.size():
		if index == sale:
			cards[index].sale = true
			cards[index].price = maxi(1, floori(int(cards[index].price) * float(r.sale)))
	var relics: Array = []
	for id: String in ProgramLoot.draw(state, r.relic_tiers, int(r.relics) + int(m.shop_relics), rng, catalog):
		var tier: String = catalog.relics[id].tier
		relics.append({"id": id, "price": _wander(int(r.relic_price[tier]), float(r.jitter), rng)})
	var scripts: Array = []
	for id: String in ProgramScripts.draft(int(ProgramRules.config_of(catalog).registry.scripts), rng, catalog):
		scripts.append({"id": id, "price": _wander(int(catalog.programs.scripts[id].price), float(r.jitter), rng)})
	return {"room": room_id, "cards": cards, "relics": relics, "scripts": scripts}


## What an item costs this run: its price less the discounts of the relics, never below 1 (0 when a coupon makes the
## sale card free).
static func price_of(state: Dictionary, shelf: String, item: Dictionary, catalog: Dictionary) -> int:
	var m := ProgramRelics.modifiers(state, catalog)
	var price := int(item.price)
	if item.get("sale", false) and m.get("sale_free", false):
		return 0
	var cut := float(m.shop_discount)
	if shelf == "scripts":
		cut += float(m.script_discount)
	if (
		shelf == "relics"
		and m.get("lockfile", false)
		and not (state.get("lockfile_layers", []) as Array).has(state.layer)
	):
		cut = maxf(cut, 0.5)
	return maxi(1, floori(price * (1.0 - cut)))


## What a service costs now: `uninstall` rises each time it is used in the run.
static func service_price(state: Dictionary, kind: String, catalog: Dictionary) -> int:
	var r := rules(catalog)
	var m := ProgramRelics.modifiers(state, catalog)
	match kind:
		"uninstall":
			return int(r.uninstall.price) + int(r.uninstall.step) * int(state.get("uninstalls", 0))
		"refactor":
			if m.get("free_refactor", false) and not (state.get("free_refactor_layers", []) as Array).has(state.layer):
				return 0
			return int(r.refactor)
		"pip-install":
			return int(r.pip_install.price)
		"repay":
			return 150
	return 0


## Applies a shop command. {} when it worked, else {code, message}.
static func apply(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if next.status != "shop" or not next.has("shop"):
		return _no("no-shop", "There is no Registry here.")
	match command.type:
		"buy":
			return _buy(next, command, catalog)
		"shop-service":
			return _service(next, command, catalog)
		"pip-take":
			return _pip_take(next, command, catalog)
		"leave-shop":
			next.erase("shop")
			Shardrun.record(next, {"kind": "note", "text": "Semver stamps your visit: v1.0.0. You move on."})
			Shardrun.after_room(next, catalog)
			return {}
	return _no("unknown-command", "The Registry does not know that.")


static func _buy(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var shelf := String(command.get("shelf", ""))
	var shop: Dictionary = next.shop
	if not shop.has(shelf) or shelf == "room":
		return _no("no-shelf", "There is no such shelf.")
	var index := int(command.get("index", -1))
	var items: Array = shop[shelf]
	if index < 0 or index >= items.size() or items[index].get("sold", false):
		return _no("not-for-sale", "That is not for sale.")
	var item: Dictionary = items[index]
	var price := price_of(next, shelf, item, catalog)
	if int(next.get("cycles", 0)) < price:
		return _no("too-expensive", "That costs %d cycles and you have %d." % [price, int(next.get("cycles", 0))])
	match shelf:
		"cards":
			(next.deck as Array).append(item.id)
			next.stats.shards += 1
		"relics":
			Shardrun.gain_relic(next, catalog.relics[item.id], catalog)
			if ProgramRelics.modifiers(next, catalog).get("lockfile", false):
				var layers: Array = next.get("lockfile_layers", [])
				layers.append(next.layer)
				next.lockfile_layers = layers
		"scripts":
			if not ProgramScripts.give(next, String(item.id), catalog):
				return _no("belt-full", "Your belt is full: drop a script first.")
	ProgramCycles.spend(next, price)
	item.sold = true
	var name := String(_name_of(shelf, String(item.id), catalog))
	Shardrun.record(next, {"kind": "reward", "amount": price, "text": "You buy %s for %d cycles." % [name, price]})
	return {}


static func _service(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var kind := String(command.get("kind", ""))
	var price := service_price(next, kind, catalog)
	if int(next.get("cycles", 0)) < price:
		return _no("too-expensive", "That costs %d cycles and you have %d." % [price, int(next.get("cycles", 0))])
	var card_id := String(command.get("card_id", ""))
	match kind:
		"uninstall":
			var index := (next.deck as Array).find(card_id)
			if index < 0:
				return _no("not-owned", "That card is not in your deck.")
			var smallest := int(catalog.balance.deck.min_cards)
			if (next.deck as Array).size() <= smallest:
				return _no("deck-too-small", "A deck cannot be pruned below %d cards." % smallest)
			(next.deck as Array).remove_at(index)
			next.uninstalls = int(next.get("uninstalls", 0)) + 1
			Shardrun.record(
				next,
				{
					"kind": "forge",
					"text":
					(
						"pip uninstall %s: %d cards remain."
						% [_name_of("cards", card_id, catalog), (next.deck as Array).size()]
					)
				}
			)
		"refactor":
			var forge: Dictionary = (catalog.shards.get(card_id, {}) as Dictionary).get("forge", {})
			var index := (next.deck as Array).find(card_id)
			if index < 0 or not forge.has("into"):
				return _no("cannot-refactor", "That card cannot be refactored.")
			next.deck[index] = forge.into
			if price == 0 and ProgramRelics.modifiers(next, catalog).get("free_refactor", false):
				var layers: Array = next.get("free_refactor_layers", [])
				layers.append(next.layer)
				next.free_refactor_layers = layers
			Shardrun.record(
				next,
				{
					"kind": "forge",
					"text":
					(
						"You refactor %s into %s."
						% [_name_of("cards", card_id, catalog), _name_of("cards", forge.into, catalog)]
					)
				}
			)
		"pip-install":
			var paradigm := String(command.get("paradigm", ""))
			var offered := _pip_offer(next, paradigm, catalog)
			if offered.is_empty():
				return _no("no-packages", "There are no packages of that paradigm.")
			(next.shop as Dictionary).pip = {"paradigm": paradigm, "cards": offered}
			Shardrun.record(
				next, {"kind": "note", "text": "pip install --index %s: three packages are offered." % paradigm}
			)
		"repay":
			var debt := (next.relics as Array).find("tech-debt")
			if debt < 0:
				return _no("no-debt", "You owe nothing.")
			(next.relics as Array).remove_at(debt)
			Shardrun.record(next, {"kind": "note", "text": "Your technical debt is repaid."})
		_:
			return _no("unknown-service", "The Registry offers no such service.")
	ProgramCycles.spend(next, price)
	return {}


## The cards `pip install <paradigm>` shows: three of that paradigm's, distinct, drawn from the seed, the room and how
## many times it has been used.
static func _pip_offer(state: Dictionary, paradigm: String, catalog: Dictionary) -> Array:
	var pool := ShardrunCatalog.sorted_values(catalog.shards).filter(
		func(card: Dictionary) -> bool: return card.get("draftable", true) and card.get("paradigm", "") == paradigm
	)
	var rng := Rng.create(
		state.seed,
		(
			"pip:%s:%d"
			% [(state.shop as Dictionary).room, int(state.get("uninstalls", 0)) + int(state.get("cycles_spent", 0))]
		)
	)
	var ids: Array = rng.shuffled(pool.map(func(card: Dictionary) -> String: return card.id))
	return ids.slice(0, int(rules(catalog).pip_install.choices))


static func _pip_take(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var pip: Dictionary = (next.shop as Dictionary).get("pip", {})
	var card_id := String(command.get("card_id", ""))
	if pip.is_empty() or not card_id in pip.cards:
		return _no("not-offered", "That package was not offered.")
	(next.deck as Array).append(card_id)
	next.stats.shards += 1
	(next.shop as Dictionary).erase("pip")
	Shardrun.record(next, {"kind": "reward", "text": "%s joins your deck." % _name_of("cards", card_id, catalog)})
	return {}


## Five cards: two of your paradigm (the second from your focus when it has cards), a neutral, one of another
## paradigm, one of any group; distinct, rarities by the shop's weights.
static func _cards(state: Dictionary, pool: Array, count: int, r: Dictionary, rng: Rng) -> Array:
	var weights: Array[float] = []
	for rarity: String in ProgramRewards.RARITIES:
		weights.append(float(r.card_rarity.get(rarity, 0.0)))
	var plan: Array[String] = [ProgramRewards.OWN, "focus", ProgramRewards.NEUTRAL, ProgramRewards.OTHER]
	var shares := {ProgramRewards.OWN: 0.5, ProgramRewards.NEUTRAL: 0.3, ProgramRewards.OTHER: 0.2}
	var chosen: Array = []
	var items: Array = []
	for slot in count:
		var group: String = plan[slot] if slot < plan.size() else ""
		var id := ""
		for attempt in 12:
			var rarity := ProgramRewards._roll_rarity(weights, rng)
			var from := group
			if group == "":
				from = ProgramRewards._roll_group(pool, state, chosen, rarity, shares, rng)
			elif group == "focus":
				from = ProgramRewards.OWN
			if from == "":
				continue
			var left := ProgramRewards._left(pool, state, chosen, rarity, from)
			if group == "focus" and String(state.get("focus", "")) != "":
				left = left.filter(func(card: Dictionary) -> bool: return ProgramRewards._is_focus(card, state))
			if left.is_empty():
				continue
			id = String((left[floori(rng.next() * left.size())] as Dictionary).id)
			break
		if id == "":
			# Whatever is left, so a thin pool still fills the shelf.
			var any := ProgramRewards._left(pool, state, chosen, "common", ProgramRewards.NEUTRAL)
			if any.is_empty():
				continue
			id = String((any[0] as Dictionary).id)
		chosen.append(id)
		var card: Dictionary = {}
		for candidate: Dictionary in pool:
			if candidate.id == id:
				card = candidate
		items.append({"id": id, "price": _wander(int(r.card_price[card.rarity]), float(r.jitter), rng)})
	return items


## A price moved by up to ±`jitter` and rounded to a multiple of 5, so a shop is not a price list.
static func _wander(price: int, jitter: float, rng: Rng) -> int:
	var moved := price * (1.0 + jitter * (rng.next() * 2.0 - 1.0))
	return maxi(5, roundi(moved / 5.0) * 5)


static func _name_of(shelf: String, id: String, catalog: Dictionary) -> String:
	var source: Dictionary = (
		catalog.relics if shelf == "relics" else (catalog.programs.scripts if shelf == "scripts" else catalog.shards)
	)
	return String((source.get(id, {}) as Dictionary).get("name", id))


static func _no(code: String, message: String) -> Dictionary:
	return {"code": code, "message": message}
