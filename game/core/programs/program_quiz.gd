class_name ProgramQuiz
extends RefCounted
## The questions of an Issue that reads code (Paradigm Update, B9.4): a card from the player's own deck is run for
## real, and a question is made from what it did. A plan is pure and seeded (which card, which volley); the session
## runs the plan's versions in the sandbox and the answer is built from what came back, so it is right in every
## language, never from a written key. Some kinds need no run at all (a pure plan).
##
##   plan(state, "rubber-duck", catalog)   -> {kind, volley, versions: [{card, op}], pure?}
##   build(plan, runs, state, catalog)     -> {options, answer, explanation, ...}

const KINDS := ["rubber-duck", "oracle", "stack-overflow", "stack-overflow-blind", "big-o", "halt", "off-by-one"]
const BUDGET_VOLLEYS := [8, 16, 32, 64, 96]


## The question to ask: {} when the deck has nothing to ask about.
static func plan(state: Dictionary, kind: String, catalog: Dictionary) -> Dictionary:
	var rng := Rng.create(state.seed, "quiz:%s:%d" % [kind, int(state.revision)])
	var candidates := _candidates(state, catalog)
	if candidates.is_empty():
		return {}
	var language := String(state.language)
	var powers: Array = []
	for i in 4:
		powers.append(2 + floori(rng.next() * 8))
	var base := {"kind": kind, "language": language, "volley": powers}
	var card: String = candidates[floori(rng.next() * candidates.size())]
	match kind:
		"rubber-duck", "off-by-one":
			base.versions = [{"card": card, "op": -1}]
		"oracle":
			var census: Dictionary = (catalog.programs.mutants as Dictionary).get(language, {})
			var withs := candidates.filter(func(id: String) -> bool: return (census.get(id, []) as Array).size() >= 2)
			if withs.is_empty():
				base.kind = "rubber-duck"
				base.versions = [{"card": card, "op": -1}]
			else:
				card = withs[floori(rng.next() * withs.size())]
				base.versions = [{"card": card, "op": -1}]
				for op: int in (census[card] as Array).slice(0, 4):
					(base.versions as Array).append({"card": card, "op": op})
		"stack-overflow", "stack-overflow-blind":
			base.pure = true
			base.card = card
			base.buggy = rng.next() < 0.5
			base.op = floori(rng.next() * ProgramMutants.OPERATORS.size())
		"big-o":
			base.pure = true
			base.n = 20 + floori(rng.next() * 30)
			var other := card
			for attempt in 12:
				other = candidates[floori(rng.next() * candidates.size())]
				if _work(other, int(base.n), catalog) != _work(card, int(base.n), catalog):
					break
			base.cards = [card, other]
		"halt":
			base.n = BUDGET_VOLLEYS[floori(rng.next() * BUDGET_VOLLEYS.size())]
			base.versions = [{"card": card, "op": -1, "n": base.n}]
		_:
			return {}
	return base


## The question, from the plan and what the sandbox returned for its versions (`runs`, in order).
static func build(plan: Dictionary, runs: Array, state: Dictionary, catalog: Dictionary) -> Dictionary:
	var rng := Rng.create(state.seed, "quiz-build:%s:%d" % [plan.kind, int(state.revision)])
	match plan.kind:
		"rubber-duck":
			return _duck(plan, runs, rng, catalog)
		"off-by-one":
			return _count(plan, runs, rng)
		"oracle":
			return _oracle(plan, runs, rng, catalog)
		"stack-overflow":
			return _forum(plan, catalog, false)
		"stack-overflow-blind":
			return _forum(plan, catalog, true)
		"big-o":
			return _big_o(plan, catalog)
		"halt":
			return _halt(plan, runs, state, catalog)
	return {}


## What a run returned, as the powers of its bolts.
static func powers_of(run: Dictionary) -> Array:
	var out: Array = []
	for bolt: Dictionary in run.get("bolts", []):
		out.append(int(bolt.power))
	return out


static func _candidates(state: Dictionary, catalog: Dictionary) -> Array:
	var ids: Array = []
	for id: String in state.deck:
		var card: Dictionary = catalog.shards.get(id, {})
		if card.is_empty() or card.get("role", "") in ["import", "utility", "guard"] or id in ids:
			continue
		if (card.get("code", {}) as Dictionary).has(state.language) and not (card.get("splits", false) as bool):
			ids.append(id)
	ids.sort()
	return ids


static func _duck(plan: Dictionary, runs: Array, rng: Rng, _catalog: Dictionary) -> Dictionary:
	var run: Dictionary = runs[0] if not runs.is_empty() else {}
	var truth := powers_of(run)
	var wrong: Array = []
	var reversed := truth.duplicate()
	reversed.reverse()
	var shifted := truth.map(func(p: int) -> int: return p + 1)
	var dropped := truth.slice(0, maxi(0, truth.size() - 1))
	var padded := truth.duplicate()
	padded.append(int(plan.volley[0]))
	for candidate: Array in [reversed, shifted, dropped, padded]:
		if candidate != truth and not candidate in wrong:
			wrong.append(candidate)
	var options: Array = [truth]
	options.append_array(wrong.slice(0, 3))
	options = rng.shuffled(options)
	return {
		"options": options.map(func(o: Array) -> String: return str(o)),
		"answer": options.find(truth),
		"explanation": "It returned %s." % str(truth),
		"input": plan.volley,
		"card": plan.versions[0].card,
	}


static func _count(plan: Dictionary, runs: Array, rng: Rng) -> Dictionary:
	var run: Dictionary = runs[0] if not runs.is_empty() else {}
	var truth := (run.get("bolts", []) as Array).size()
	var options: Array = [truth]
	for delta: int in [-1, 1, 2, -2, 3]:
		if truth + delta >= 0 and not (truth + delta) in options and options.size() < 4:
			options.append(truth + delta)
	options = rng.shuffled(options)
	return {
		"options": options.map(func(o: int) -> String: return str(o)),
		"answer": options.find(truth),
		"explanation": "It returned %d bolts." % truth,
		"input": plan.volley,
		"card": plan.versions[0].card,
	}


## The real card and two mutants that do not return what it returns, in a shuffled order; the one that passes the
## test (the real card's own output) is the answer.
static func _oracle(plan: Dictionary, runs: Array, rng: Rng, catalog: Dictionary) -> Dictionary:
	if runs.size() < 2:
		return _duck(plan, runs, rng, catalog)
	var truth := powers_of(runs[0])
	var chosen: Array = [{"op": -1, "powers": truth}]
	for i in range(1, runs.size()):
		if powers_of(runs[i]) != truth and chosen.size() < 3:
			chosen.append({"op": int(plan.versions[i].op), "powers": powers_of(runs[i])})
	if chosen.size() < 2:
		return _duck(plan, runs, rng, catalog)
	chosen = rng.shuffled(chosen)
	var card: Dictionary = catalog.shards[plan.versions[0].card]
	var codes: Array = []
	var answer := -1
	for i in chosen.size():
		var code: String = card.code[plan.language]
		if int(chosen[i].op) >= 0:
			code = String(ProgramMutants.mutate(code, String(plan.language), int(chosen[i].op)).get("code", code))
		else:
			answer = i
		codes.append(code)
	return {
		"options": codes.map(func(_c: String) -> String: return "version"),
		"versions": codes,
		"answer": answer,
		"expected": truth,
		"explanation": "The real card returns %s." % str(truth),
		"input": plan.volley,
		"card": plan.versions[0].card,
	}


## An answer from a forum: the real card's code, or (half the time) the card with one edit. Copying a buggy one is the
## mistake; the diff of the edit shows when the answer is read first.
static func _forum(plan: Dictionary, catalog: Dictionary, blind: bool) -> Dictionary:
	var card: Dictionary = catalog.shards[plan.card]
	var code: String = card.code[plan.language]
	var edit := ProgramMutants.mutate(code, String(plan.language), int(plan.op))
	var shown := String(edit.get("code", code)) if plan.buggy and not edit.is_empty() else code
	var buggy: bool = shown != code
	return {
		# Read first, you may walk away; copied blind, there is only the copy, and a buggy one is the mistake.
		"options": ["copy"] if blind else ["copy", "walk-away"],
		"answer": (-1 if buggy else 0) if blind else (1 if buggy else 0),
		"decision": true,
		"code": "" if blind else shown,
		"diff":
		(
			{}
			if blind or not buggy
			else {
				"before": String(edit.get("before", "")),
				"after": String(edit.get("after", "")),
				"line": int(edit.get("line", 0))
			}
		),
		"buggy": buggy,
		"card": plan.card,
		"explanation":
		"That answer had a bug on line %d." % (int(edit.get("line", 0)) + 1) if buggy else "The answer was fine.",
	}


static func _work(card_id: String, n: int, catalog: Dictionary) -> int:
	var card: Dictionary = catalog.shards[card_id]
	return ProgramRules.work_units(
		String(card.get("complexity", "linear")), n, int(card.get("cap_n", 0)), int(card.get("height", 8))
	)


static func _big_o(plan: Dictionary, catalog: Dictionary) -> Dictionary:
	var a := _work(plan.cards[0], int(plan.n), catalog)
	var b := _work(plan.cards[1], int(plan.n), catalog)
	var answer := 2 if a == b else (0 if a < b else 1)
	return {
		"options": [plan.cards[0], plan.cards[1], "same"],
		"answer": answer,
		"explanation": "On %d bolts they do %d and %d operations." % [int(plan.n), a, b],
		"n": plan.n,
		"cards": plan.cards,
	}


static func _halt(plan: Dictionary, runs: Array, state: Dictionary, catalog: Dictionary) -> Dictionary:
	var card_id: String = plan.versions[0].card
	var n := int(plan.n)
	var work := _work(card_id, n, catalog)
	if not runs.is_empty() and runs[0].get("ok", false):
		var steps: Array = runs[0].get("trace", [])
		work = ProgramRules.total_work(ProgramRules.stages(state, steps, catalog))
	var budget := ProgramRules.budget(state, catalog)
	var finishes := work <= budget
	return {
		"options": ["finishes", "times-out"],
		"answer": 0 if finishes else 1,
		"explanation": "It did %d operations against a budget of %d." % [work, budget],
		"card": card_id,
		"n": n,
		"budget": budget,
	}
