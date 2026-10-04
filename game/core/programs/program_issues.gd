class_name ProgramIssues
extends RefCounted
## Issues, a program run's events (Paradigm Update, B9): a room that poses a problem on a tracker and offers a few
## choices, each a list of effects. An effect that needs the player to decide something (which card, which paradigm)
## stops the list in a *stage* and carries the rest in `state.issue.rest`; the command that answers it runs the rest.
## Everything is drawn from the run's seed and the room, so reloading cannot reroll an issue.
##
## The issue is plain data on the run: state.issue = {id, stage, lines, choice?, rest?, pick?, offer?, paradigms?,
## focuses?, quiz?}. Commands: issue-choose {index}, issue-pick {card_ids}, issue-paradigm {paradigm_id}, issue-take
## {card_id | null}, issue-focus {focus_id}, issue-quiz-ready {...}, issue-answer {index}, issue-leave.
##
## Stages: "choose" (the choices), "pick" (cards of the deck), "paradigm", "offer" (cards to take), "focus", "quiz",
## and "result" (what happened, with a Continue).

const BASICS := ["salvo", "fork", "amplify", "ward", "round-robin", "kindle"]


static func issues_of(catalog: Dictionary) -> Dictionary:
	return (catalog.programs as Dictionary).get("issues", {})


## Walks into an Issue room: one issue for this layer, by weight, not yet met in this run.
static func enter(state: Dictionary, node: Dictionary, catalog: Dictionary) -> void:
	var seen: Array = state.get("issues_seen", [])
	var pool := ShardrunCatalog.sorted_values(issues_of(catalog)).filter(
		func(issue: Dictionary) -> bool: return (issue.layers as Array).is_empty() or int(state.layer) in issue.layers
	)
	var fresh := pool.filter(func(issue: Dictionary) -> bool: return not issue.id in seen)
	if fresh.is_empty():
		seen = []
		fresh = pool
	if fresh.is_empty():
		Shardrun.after_room(state, catalog)
		return
	var rng := Rng.create(state.seed, "issue:%s" % node.id)
	var weights: Array[float] = []
	for issue: Dictionary in fresh:
		weights.append(float(issue.weight))
	var issue: Dictionary = fresh[maxi(0, Rng.pick_weighted(weights, rng.next()))]
	seen.append(issue.id)
	state.issues_seen = seen
	state.issue = {"id": issue.id, "stage": "choose", "lines": [], "number": 100 + floori(rng.next() * 900)}
	state.status = "issue"
	Shardrun.record(state, {"kind": "enter", "text": "An open issue: %s" % issue.name})


## Applies an issue command. {} when it worked, else {code, message}.
static func apply(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if next.status != "issue" or not next.has("issue"):
		return _no("no-issue", "There is no open issue.")
	var issue: Dictionary = next.issue
	match command.type:
		"issue-choose":
			return _choose(next, int(command.get("index", -1)), catalog)
		"issue-pick":
			return _pick(next, command, catalog)
		"issue-paradigm":
			return _paradigm(next, String(command.get("paradigm_id", "")), catalog)
		"issue-take":
			return _take(next, command.get("card_id"), catalog)
		"issue-focus":
			return _focus(next, String(command.get("focus_id", "")), catalog)
		"issue-quiz-ready":
			return _quiz_ready(next, command)
		"issue-answer":
			return _answer(next, int(command.get("index", -1)), catalog)
		"issue-leave":
			if issue.stage != "result":
				return _no("not-finished", "The issue is not settled yet.")
			next.erase("issue")
			Shardrun.after_room(next, catalog)
			return {}
	return _no("unknown-command", "That is not something an issue understands.")


static func definition(state: Dictionary, catalog: Dictionary) -> Dictionary:
	return issues_of(catalog).get(String((state.get("issue", {}) as Dictionary).get("id", "")), {})


## Whether a choice can be made now: a cost it names must be one the run can pay.
static func can_choose(state: Dictionary, choice: Dictionary) -> bool:
	var needs: Dictionary = choice.get("needs", {})
	return int(state.get("cycles", 0)) >= int(needs.get("cycles", 0))


# --- Choosing and running effects ---------------------------------------------------------------------------------------


static func _choose(next: Dictionary, index: int, catalog: Dictionary) -> Dictionary:
	var issue: Dictionary = next.issue
	if issue.stage != "choose":
		return _no("not-choosing", "There is nothing to choose now.")
	var choices: Array = definition(next, catalog).choices
	if index < 0 or index >= choices.size():
		return _no("no-choice", "There is no such choice.")
	var choice: Dictionary = choices[index]
	if not can_choose(next, choice):
		return _no("cannot-afford", "You cannot afford that.")
	issue.choice = index
	_run(next, choice.effects, catalog)
	return {}


## Runs `effects` in order. One that needs the player stops here, with the rest kept for when they answer.
static func _run(state: Dictionary, effects: Array, catalog: Dictionary) -> void:
	for i in effects.size():
		var rest: Array = effects.slice(i + 1)
		if _effect(state, effects[i], rest, catalog):
			return
	_settle(state)


static func _settle(state: Dictionary) -> void:
	var issue: Dictionary = state.issue
	issue.stage = "result"
	for key: String in ["pick", "offer", "paradigms", "focuses", "quiz", "rest"]:
		issue.erase(key)


## One effect. True when it opened a stage (and has taken `rest` with it), false when it was done on the spot.
static func _effect(state: Dictionary, effect: Dictionary, rest: Array, catalog: Dictionary) -> bool:
	var issue: Dictionary = state.issue
	var rng := Rng.create(
		state.seed, "issue-effect:%s:%d:%d" % [issue.id, int(state.revision), (issue.lines as Array).size()]
	)
	match effect.kind:
		"gain-cycles":
			ProgramCycles.earn(state, int(effect.amount))
			_say(state, "You gain %d cycles." % int(effect.amount))
		"lose-cycles":
			var paid := mini(int(state.get("cycles", 0)), int(effect.amount))
			ProgramCycles.spend(state, paid)
			_say(state, "You lose %d cycles." % paid)
		"lose-integrity":
			state.integrity = maxi(1, int(state.integrity) - int(effect.amount))
			_say(state, "You lose %d Integrity." % int(effect.amount))
		"heal":
			var healed := mini(int(state.integrity_max) - int(state.integrity), int(effect.amount))
			state.integrity += healed
			_say(state, "You recover %d Integrity." % healed)
		"heal-fraction":
			var amount := Shardrun.heal_amount(state, float(effect.fraction))
			state.integrity += amount
			_say(state, "You recover %d Integrity." % amount)
		"max-integrity":
			state.integrity_max = maxi(1, int(state.integrity_max) + int(effect.amount))
			state.integrity = clampi(int(state.integrity) + maxi(0, int(effect.amount)), 1, int(state.integrity_max))
			_say(state, "Your maximum Integrity becomes %d." % int(state.integrity_max))
		"gain-script":
			for found: String in ProgramScripts.draft(int(effect.count), rng, catalog, String(effect.rarity)):
				if ProgramScripts.give(state, found, catalog):
					_say(state, "You take %s." % catalog.programs.scripts[found].name)
				else:
					_say(state, "Your belt is full: %s is left behind." % catalog.programs.scripts[found].name)
		"gain-relic":
			_gain_relic(state, effect, rng, catalog)
		"gain-relic-id":
			var relic: Dictionary = catalog.relics.get(String(effect.relic), {})
			if not relic.is_empty() and not relic.id in state.relics:
				Shardrun.gain_relic(state, relic, catalog)
				_say(state, "You take %s." % relic.name)
		"gain-curse":
			var curses := Shardrun.curses_left(state, catalog)
			if not curses.is_empty():
				var curse: Dictionary = curses[floori(rng.next() * curses.size())]
				Shardrun.gain_relic(state, curse, catalog)
				_say(state, "You are cursed with %s." % curse.name)
		"add-random-card":
			var found := _random_card(state, effect, rng, catalog)
			if found != "":
				(state.deck as Array).append(found)
				_say(state, "%s joins your deck." % _name(found, catalog))
		"copy-quiz-card":
			var copied := String((issue.get("quiz", {}) as Dictionary).get("card", ""))
			if copied != "":
				(state.deck as Array).append(copied)
				_say(state, "%s joins your deck." % _name(copied, catalog))
		"upgrade-random":
			_upgrade_random(state, int(effect.count), rng, catalog)
		"transform-random":
			_transform_random(state, int(effect.count), rng, catalog)
		"transform-commons":
			_transform_commons(state, int(effect.lose_max), rng, catalog)
		"pending":
			var waiting: Array = _waiting(state)
			# The issue's own room counts down once as it is left, so "in N rooms" starts one higher.
			waiting.append({"rooms": int(effect.rooms) + 1, "effects": effect.effects, "from": issue.id})
			state.pending = waiting
			_say(state, "It will pay off in %d rooms." % int(effect.rooms))
		"boon":
			var boons: Array = state.get("boons", [])
			boons.append({"kind": effect.boon, "fights": int(effect.fights)})
			state.boons = boons
			_say(state, "For the next %d fights: %s." % [int(effect.fights), _boon_text(String(effect.boon))])
		"bounty":
			state.bounty = {"kind": effect.bounty, "reward": int(effect.reward)}
			_say(state, "The next fight carries a bounty of %d cycles." % int(effect.reward))
		"fight":
			_start_fight(state, catalog)
			return true
		"pick":
			return _open_pick(state, effect, rest, catalog)
		"offer":
			return _open_offer(state, effect, rest, catalog)
		"swap-focus":
			return _open_focus(state, rest, catalog)
		"quiz":
			return _open_quiz(state, effect, rest, catalog)
	return false


static func _say(state: Dictionary, text: String) -> void:
	((state.issue as Dictionary).lines as Array).append(text)
	Shardrun.record(state, {"kind": "note", "text": text})


static func _boon_text(boon: String) -> String:
	match boon:
		"mana":
			return "+1 mana on the first turn"
		"draw":
			return "draw 1 more on the first turn"
		"block":
			return "start with 5 block"
		"intern":
			return "a fourth card in every card reward"
	return boon


static func _name(card_id: String, catalog: Dictionary) -> String:
	return String((catalog.shards.get(card_id, {}) as Dictionary).get("name", card_id))


# --- Cards: random ones and picked ones --------------------------------------------------------------------------------


static func _gain_relic(state: Dictionary, effect: Dictionary, rng: Rng, catalog: Dictionary) -> void:
	if rng.next() < float(effect.curse_chance):
		var curses := Shardrun.curses_left(state, catalog)
		if not curses.is_empty():
			var curse: Dictionary = curses[floori(rng.next() * curses.size())]
			Shardrun.gain_relic(state, curse, catalog)
			_say(state, "You open it: %s, a curse." % curse.name)
			return
	var tier := String(effect.tier)
	var table := {tier: 1.0} if tier != "any" else {"common": 40.0, "uncommon": 34.0, "rare": 20.0, "epic": 5.0}
	if tier == "rare-plus":
		table = {"rare": 70.0, "epic": 25.0, "legendary": 5.0}
	var found := ProgramLoot.draw(state, table, 1, rng, catalog)
	if found.is_empty():
		_say(state, "It holds nothing you can use.")
		return
	Shardrun.gain_relic(state, catalog.relics[found[0]], catalog)
	_say(state, "You find %s." % catalog.relics[found[0]].name)


## A random draftable card of `scope` (own paradigm, neutral, another paradigm, or any), refactored when asked.
static func _random_card(state: Dictionary, effect: Dictionary, rng: Rng, catalog: Dictionary) -> String:
	var scope := String(effect.scope)
	var rare := String(effect.get("rarity", "any")) == "rare"
	var pool := ShardrunCatalog.sorted_values(catalog.shards).filter(
		func(card: Dictionary) -> bool:
			if not card.get("draftable", true) or (rare and card.rarity != "rare"):
				return false
			var group := ProgramRewards._group_of(card, state)
			return scope == "any" or group == scope
	)
	if pool.is_empty():
		return ""
	var card: Dictionary = pool[floori(rng.next() * pool.size())]
	var id := String(card.id)
	if bool(effect.get("refactored", false)) and (card.get("forge", {}) as Dictionary).has("into"):
		id = String(card.forge.into)
	return id


## Cards in the deck that have a refactor, one entry per copy, in deck order.
static func _upgradable(state: Dictionary, catalog: Dictionary) -> Array:
	return (state.deck as Array).filter(
		func(id: String) -> bool:
			return ((catalog.shards.get(id, {}) as Dictionary).get("forge", {}) as Dictionary).has("into")
	)


static func _upgrade_random(state: Dictionary, count: int, rng: Rng, catalog: Dictionary) -> void:
	for n in count:
		var options := _upgradable(state, catalog)
		if options.is_empty():
			return
		var id: String = options[floori(rng.next() * options.size())]
		var at := (state.deck as Array).find(id)
		state.deck[at] = catalog.shards[id].forge.into
		_say(state, "%s is refactored into %s." % [_name(id, catalog), _name(state.deck[at], catalog)])


## A card becomes another of the same paradigm and role (a different one when there is one).
static func _transformed(id: String, rng: Rng, catalog: Dictionary) -> String:
	var card: Dictionary = catalog.shards.get(id, {})
	var pool := ShardrunCatalog.sorted_values(catalog.shards).filter(
		func(other: Dictionary) -> bool:
			return (
				other.get("draftable", true)
				and other.id != card.get("id", "")
				and other.get("paradigm", "") == card.get("paradigm", "")
				and other.get("role", "") == card.get("role", "")
			)
	)
	return id if pool.is_empty() else String((pool[floori(rng.next() * pool.size())] as Dictionary).id)


static func _transform_random(state: Dictionary, count: int, rng: Rng, catalog: Dictionary) -> void:
	var own := (state.deck as Array).filter(
		func(id: String) -> bool:
			return (catalog.shards.get(id, {}) as Dictionary).get("paradigm", "") == state.get("paradigm", "")
	)
	for n in mini(count, own.size()):
		var id: String = own[floori(rng.next() * own.size())]
		var at := (state.deck as Array).find(id)
		var into := _transformed(id, rng, catalog)
		state.deck[at] = into
		own.erase(id)
		_say(state, "%s becomes %s." % [_name(id, catalog), _name(into, catalog)])


## Rewrite it in Rust: every common card becomes an uncommon one of its paradigm, at a price in maximum Integrity.
static func _transform_commons(state: Dictionary, lose_each: int, rng: Rng, catalog: Dictionary) -> void:
	var changed := 0
	for at in (state.deck as Array).size():
		var card: Dictionary = catalog.shards.get(state.deck[at], {})
		if card.get("rarity", "") != "common":
			continue
		var pool := ShardrunCatalog.sorted_values(catalog.shards).filter(
			func(other: Dictionary) -> bool:
				return (
					other.get("draftable", true)
					and other.rarity == "uncommon"
					and other.get("paradigm", "") == card.get("paradigm", "")
				)
		)
		if pool.is_empty():
			continue
		state.deck[at] = (pool[floori(rng.next() * pool.size())] as Dictionary).id
		changed += 1
	state.integrity_max = maxi(10, int(state.integrity_max) - lose_each * changed)
	state.integrity = mini(int(state.integrity), int(state.integrity_max))
	_say(state, "%d cards are rewritten. Your maximum Integrity becomes %d." % [changed, int(state.integrity_max)])


# --- Picking cards from the deck --------------------------------------------------------------------------------------


static func _open_pick(state: Dictionary, effect: Dictionary, rest: Array, catalog: Dictionary) -> bool:
	var purpose := String(effect.purpose)
	var options: Array = _pick_options(state, purpose, catalog)
	var issue: Dictionary = state.issue
	var count := int(effect.count)
	if options.is_empty() or (purpose == "keep" and options.size() < 2):
		_say(state, "There is nothing here that fits.")
		return false
	if purpose == "keep":
		var rng := Rng.create(state.seed, "issue-keep:%s:%d" % [issue.id, int(state.revision)])
		var pair: Array = rng.shuffled(options).slice(0, 2)
		options = pair
	issue.stage = "pick"
	issue.pick = {"purpose": purpose, "count": count, "options": options, "then": effect.then}
	issue.rest = rest
	return true


## The distinct cards of the deck that `purpose` could act on.
static func _pick_options(state: Dictionary, purpose: String, catalog: Dictionary) -> Array:
	var out: Array = []
	var smallest := int(catalog.balance.deck.min_cards)
	for id: String in state.deck:
		if id in out:
			continue
		var card: Dictionary = catalog.shards.get(id, {})
		match purpose:
			"upgrade":
				if (card.get("forge", {}) as Dictionary).has("into"):
					out.append(id)
			"transform":
				if _transformed(id, Rng.create("x", "x"), catalog) != id:
					out.append(id)
			"remove-basic":
				if id in BASICS:
					out.append(id)
			"remove", "trade":
				if (state.deck as Array).size() > smallest:
					out.append(id)
			_:
				out.append(id)
	return out


static func _pick(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var issue: Dictionary = next.issue
	if issue.stage != "pick":
		return _no("not-picking", "There is nothing to pick.")
	var pick: Dictionary = issue.pick
	var ids: Array = command.get("card_ids", [])
	var purpose := String(pick.purpose)
	var needed := int(pick.count)
	var minimum := 0 if purpose == "remove-basic" else needed
	if purpose == "keep":
		needed = 1
		minimum = 1
	if ids.size() < minimum or ids.size() > needed:
		return _no("wrong-count", "Pick %d card(s)." % needed)
	for id: String in ids:
		if not id in pick.options:
			return _no("not-offered", "That card cannot be picked.")
	var rng := Rng.create(next.seed, "issue-pick:%s:%d" % [issue.id, int(next.revision)])
	for id: String in ids:
		var at := (next.deck as Array).find(id)
		if at < 0:
			return _no("not-owned", "That card is not in your deck.")
		match purpose:
			"remove", "remove-basic", "trade":
				(next.deck as Array).remove_at(at)
				_say(next, "%s is removed." % _name(id, catalog))
			"upgrade":
				next.deck[at] = catalog.shards[id].forge.into
				_say(next, "%s is refactored into %s." % [_name(id, catalog), _name(next.deck[at], catalog)])
			"transform":
				next.deck[at] = _transformed(id, rng, catalog)
				_say(next, "%s becomes %s." % [_name(id, catalog), _name(next.deck[at], catalog)])
			"duplicate":
				(next.deck as Array).append(id)
				_say(next, "%s is copied." % _name(id, catalog))
			"keep":
				for other: String in pick.options:
					if other != id:
						(next.deck as Array).remove_at((next.deck as Array).find(other))
						_say(next, "You keep %s and lose %s." % [_name(id, catalog), _name(other, catalog)])
	var after: Array = (pick.then as Array).duplicate()
	after.append_array(issue.rest)
	_run(next, after, catalog)
	return {}


# --- Offers: three cards, take one ------------------------------------------------------------------------------------


static func _open_offer(state: Dictionary, effect: Dictionary, rest: Array, catalog: Dictionary) -> bool:
	var issue: Dictionary = state.issue
	issue.rest = rest
	if String(effect.scope) == "chosen":
		var ids: Array = (ProgramRules.config_of(catalog).paradigms as Array).map(
			func(p: Dictionary) -> String: return p.id
		)
		issue.stage = "paradigm"
		issue.paradigms = ids
		issue.offer = {"refactored": bool(effect.refactored), "count": int(effect.count)}
		return true
	var cards := _offer_cards(state, String(effect.scope), "", int(effect.count), catalog)
	if cards.is_empty():
		_say(state, "There is nothing on offer.")
		return false
	issue.stage = "offer"
	issue.offer = {"cards": cards, "refactored": bool(effect.refactored)}
	return true


static func _paradigm(next: Dictionary, paradigm_id: String, catalog: Dictionary) -> Dictionary:
	var issue: Dictionary = next.issue
	if issue.stage != "paradigm" or not paradigm_id in issue.paradigms:
		return _no("not-choosing", "There is no paradigm to choose now.")
	var offer: Dictionary = issue.offer
	var cards := _offer_cards(next, "chosen", paradigm_id, int(offer.count), catalog)
	issue.stage = "offer"
	issue.offer = {"cards": cards, "refactored": offer.refactored, "paradigm": paradigm_id}
	issue.erase("paradigms")
	return {}


## `count` distinct draftable cards of the scope, seeded: own, neutral, other (a paradigm other than yours), any, or a
## paradigm named.
static func _offer_cards(state: Dictionary, scope: String, paradigm: String, count: int, catalog: Dictionary) -> Array:
	var pool := ShardrunCatalog.sorted_values(catalog.shards).filter(
		func(card: Dictionary) -> bool:
			if not card.get("draftable", true):
				return false
			if scope == "chosen":
				return card.get("paradigm", "") == paradigm
			return scope == "any" or ProgramRewards._group_of(card, state) == scope
	)
	var rng := Rng.create(state.seed, "issue-offer:%s:%d:%s" % [state.issue.id, int(state.revision), paradigm])
	var ids: Array = rng.shuffled(pool.map(func(card: Dictionary) -> String: return card.id))
	return ids.slice(0, count)


static func _take(next: Dictionary, card_id: Variant, catalog: Dictionary) -> Dictionary:
	var issue: Dictionary = next.issue
	if issue.stage != "offer":
		return _no("not-offering", "Nothing is on offer.")
	if card_id != null:
		if not String(card_id) in issue.offer.cards:
			return _no("not-offered", "That card was not offered.")
		var id := String(card_id)
		if bool(issue.offer.refactored) and (catalog.shards[id].get("forge", {}) as Dictionary).has("into"):
			id = String(catalog.shards[id].forge.into)
		(next.deck as Array).append(id)
		_say(next, "%s joins your deck." % _name(id, catalog))
	else:
		_say(next, "You take nothing.")
	_run(next, issue.rest, catalog)
	return {}


# --- A different focus ------------------------------------------------------------------------------------------------


static func _open_focus(state: Dictionary, rest: Array, catalog: Dictionary) -> bool:
	var paradigm := ProgramDraft.paradigm_of(catalog, String(state.get("paradigm", "")))
	var others: Array = []
	for focus: Dictionary in paradigm.get("focuses", []):
		if focus.id != state.get("focus", ""):
			others.append(focus.id)
	if others.is_empty():
		_say(state, "There is no other focus to take up.")
		return false
	var issue: Dictionary = state.issue
	issue.stage = "focus"
	issue.focuses = others
	issue.rest = rest
	return true


static func _focus(next: Dictionary, focus_id: String, catalog: Dictionary) -> Dictionary:
	var issue: Dictionary = next.issue
	if issue.stage != "focus" or not focus_id in issue.focuses:
		return _no("not-choosing", "There is no focus to choose now.")
	var paradigm := ProgramDraft.paradigm_of(catalog, String(next.paradigm))
	for focus: Dictionary in paradigm.focuses:
		if focus.id == next.focus:
			(next.relics as Array).erase(focus.relic)
	for focus: Dictionary in paradigm.focuses:
		if focus.id == focus_id:
			Shardrun.gain_relic(next, catalog.relics[focus.relic], catalog)
	next.focus = focus_id
	_say(next, "Your focus is now %s. The signature card you had stays." % focus_id)
	_run(next, issue.rest, catalog)
	return {}


# --- Fights an issue starts ---------------------------------------------------------------------------------------------


static func _start_fight(state: Dictionary, catalog: Dictionary) -> void:
	var layer := ShardrunRules.layer_of(state, catalog)
	var node := {"id": "issue-fight-%s" % state.issue.id, "kind": "elite"}
	var foes := ShardrunRules.encounter_for(String(state.seed), node, layer)
	state.erase("issue")
	ShardrunBattle.start(state, node, "elite", catalog)
	Shardrun.record(state, {"kind": "note", "text": "You take the elite on: %s." % ", ".join(foes)})


# --- Quizzes: a bet on reading code -----------------------------------------------------------------------------------


static func _open_quiz(state: Dictionary, effect: Dictionary, rest: Array, catalog: Dictionary) -> bool:
	var issue: Dictionary = state.issue
	var plan := ProgramQuiz.plan(state, String(effect.quiz), catalog)
	if plan.is_empty():
		_say(state, "Nothing in your deck makes a good question. The issue is closed.")
		return false
	issue.stage = "quiz"
	issue.quiz = {"plan": plan, "ready": false, "right": effect.right, "wrong": effect.wrong}
	issue.rest = rest
	if plan.get("pure", false):
		issue.quiz.merge(ProgramQuiz.build(plan, [], state, catalog))
		issue.quiz.ready = true
	return true


## The session ran the plan's versions in the sandbox and sends what they returned; the question is built from it.
static func _quiz_ready(next: Dictionary, command: Dictionary) -> Dictionary:
	var issue: Dictionary = next.issue
	if issue.stage != "quiz" or issue.quiz.ready:
		return _no("not-quizzing", "There is no question waiting.")
	var quiz: Dictionary = issue.quiz
	var built: Dictionary = command.get("question", {})
	if not built.has("options") or not built.has("answer"):
		return _no("bad-question", "The question is not well formed.")
	quiz.merge(built)
	quiz.ready = true
	return {}


static func _answer(next: Dictionary, index: int, catalog: Dictionary) -> Dictionary:
	var issue: Dictionary = next.issue
	if issue.stage != "quiz" or not issue.quiz.ready:
		return _no("not-quizzing", "There is no question to answer.")
	var quiz: Dictionary = issue.quiz
	if index < 0 or index >= (quiz.options as Array).size():
		return _no("no-choice", "There is no such answer.")
	var right: bool = index == int(quiz.answer)
	# A choice about a forum answer is what you did with it: walking away costs and earns nothing.
	if quiz.get("decision", false) and quiz.options[index] == "walk-away":
		_say(next, "You walk away. %s" % String(quiz.get("explanation", "")))
		_run(next, issue.rest, catalog)
		return {}
	var duck: bool = ProgramRelics.modifiers(next, catalog).get("waive_stakes", false)
	_say(next, "Right." if right else "Not quite. %s" % String(quiz.get("explanation", "")))
	var effects: Array = quiz.right if right else quiz.wrong
	if not right and duck:
		effects = []
		_say(next, "The rubber duck takes the blame: no stake is paid.")
	var rest: Array = issue.rest
	var after: Array = effects.duplicate()
	after.append_array(rest)
	_run(next, after, catalog)
	return {}


# --- Time passing: pending effects, boons, bounties ----------------------------------------------------------------------


## A room is done: what was set to happen "in N rooms" counts down, and pays out when it reaches 0.
static func tick(state: Dictionary, catalog: Dictionary) -> void:
	var waiting: Array = _waiting(state)
	if waiting.is_empty():
		return
	var still: Array = []
	for item: Dictionary in waiting:
		item.rooms = int(item.rooms) - 1
		if int(item.rooms) > 0:
			still.append(item)
			continue
		var holder := {"id": String(item.from), "stage": "result", "lines": []}
		var kept: Variant = state.get("issue")
		state.issue = holder
		for effect: Dictionary in item.effects:
			_effect(state, effect, [], catalog)
		Shardrun.record(state, {"kind": "reward", "text": "A pending issue pays out: %s" % " ".join(holder.lines)})
		if kept == null:
			state.erase("issue")
		else:
			state.issue = kept
	state.pending = still


## A fight begins: boons and a bounty take hold.
static func on_battle_start(state: Dictionary, battle: Dictionary) -> void:
	for boon: Dictionary in state.get("boons", []):
		match boon.kind:
			"mana":
				battle.mana += 1
			"draw":
				battle.bonus_draw_now = int(battle.get("bonus_draw_now", 0)) + 1
			"block":
				battle.block += 5
	if state.has("bounty"):
		battle.bounty = state.bounty
		state.erase("bounty")


## A fight is won: boons count down.
static func on_win(state: Dictionary) -> void:
	var left: Array = []
	for boon: Dictionary in state.get("boons", []):
		boon.fights = int(boon.fights) - 1
		if int(boon.fights) > 0:
			left.append(boon)
	state.boons = left


## The pending effects, whatever shape an older save kept them in.
static func _waiting(state: Dictionary) -> Array:
	var kept: Variant = state.get("pending", [])
	return (kept as Array).duplicate() if kept is Array else []


static func _no(code: String, message: String) -> Dictionary:
	return {"code": code, "message": message}
