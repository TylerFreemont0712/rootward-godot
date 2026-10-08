extends GdUnitTestSuite
## The program tag through the sandbox (docs/LEGENDARY_LOOKS.md): bolts carry the card that returned them and its role,
## the same in Python and JavaScript, and no card can choose them. Rebinding a built-in, the serialiser or the printer,
## or rewriting the job's own records, changes none of it. C++ is not covered here (game/sandbox/cpp/harness.cpp).

var cards: Dictionary


func before() -> void:
	cards = ContentLoader.load_shardrun().catalog.programs.cards


func _program(ids: Array) -> Dictionary:
	var list: Array[Dictionary] = []
	for id: String in ids:
		list.append(cards[id])
	return {"id": "p", "shards": list}


## A program run's input the way the program path sends it (app/spell_runs.gd input_for): counted, with execution rules.
func _run_input(counted: bool, executed: bool) -> Dictionary:
	var input := {
		"bolts": [{"power": 3, "element": "none"}, {"power": 4, "element": "fire"}, {"power": 9, "element": "none"}],
		"battle": {"turn": 1, "me": {"hp": 30, "max": 30, "block": 0, "mana": 5}, "foes": [], "imports": ["math"]},
		"limit": 64,
		"trace_limit": 8,
		"count": counted,
		"module": "program",
	}
	if executed:
		input.execution = {}
	return input


## A small program run with `hooks` (each {card, when, role}) around its cards, counted and with execution rules.
func _hooked_input(hooks: Array) -> Dictionary:
	return {
		"bolts": [{"power": 1, "element": "none"}],
		"battle": {"turn": 1, "foes": []},
		"limit": 8,
		"trace_limit": 4,
		"count": true,
		"execution": {},
		"hooks": hooks,
	}


## A card or an import written for these tests, the same function in Python and JavaScript.
func _shard(id: String, function: String, role: String, python: String, javascript: String) -> Dictionary:
	return {"id": id, "function": function, "role": role, "code": {"python": python, "javascript": javascript}}


func _forger() -> Dictionary:
	return _shard(
		"forging-source",
		"forge_bolts",
		"source",
		"def forge_bolts(bolts, battle):\n    return [{'power': 2, 'element': 'none', 'card': 'forged', 'role': 'guard'}]\n",
		"function forgeBolts(bolts, battle) {\n  return [{ power: 2, element: 'none', card: 'forged', role: 'guard' }];\n}\n"
	)


func _plain_source() -> Dictionary:
	return _shard(
		"plain-source",
		"plain_bolts",
		"source",
		"def plain_bolts(bolts, battle):\n    return [{'power': 2, 'element': 'none'}, {'power': 5, 'element': 'fire'}]\n",
		"function plainBolts(bolts, battle) {\n  return [{ power: 2, element: 'none' }, { power: 5, element: 'fire' }];\n}\n"
	)


## An import that adds one to every power and writes a card and a role of its own on each bolt.
func _echo_import() -> Dictionary:
	return _shard(
		"import-echo",
		"echo_bolts",
		"import",
		(
			"def echo_bolts(bolts, battle):\n"
			+ "    return [dict(b, power=b['power'] + 1, card='liar', role='shape') for b in bolts]\n"
		),
		(
			"function echoBolts(bolts, battle) {\n"
			+ "  return bolts.map((b) => ({ ...b, power: b.power + 1, card: 'liar', role: 'shape' }));\n}\n"
		)
	)


## An import that puts each bolt's card in its element: what the import saw as the card that returned the bolt.
func _seen_import() -> Dictionary:
	return _shard(
		"import-seen",
		"seen_bolts",
		"import",
		"def seen_bolts(bolts, battle):\n    return [dict(b, element=b.get('card', 'none')) for b in bolts]\n",
		"function seenBolts(bolts, battle) {\n  return bolts.map((b) => ({ ...b, element: b.card || 'none' }));\n}\n"
	)


## An import that sorts the volley by power and keeps each bolt's keys, as heapq does before a strike.
func _sorter() -> Dictionary:
	return _shard(
		"import-sorter",
		"sort_bolts",
		"import",
		"def sort_bolts(bolts, battle):\n    return sorted(bolts, key=lambda b: b['power'])\n",
		"function sortBolts(bolts, battle) {\n  return [...bolts].sort((a, b) => a.power - b.power);\n}\n"
	)


## A strike that hands back one bolt whose element names the card of the first bolt it was given ("none" for no card).
func _probe() -> Dictionary:
	return _shard(
		"probe-strike",
		"probe_bolts",
		"strike",
		(
			"def probe_bolts(bolts, battle):\n"
			+ "    return [{'power': 1, 'element': bolts[0].get('card', 'none') if bolts else 'none'}]\n"
		),
		(
			"function probeBolts(bolts, battle) {\n"
			+ "  return [{ power: 1, element: bolts.length ? bolts[0].card || 'none' : 'none' }];\n}\n"
		)
	)


## A card that rebinds the built-ins the stamp calls, then returns bolts naming itself "forged". Python rebinds dict and
## isinstance, JavaScript Array.prototype.map and Array.isArray: a stamp on live names would keep the forged tags.
func _rebinder() -> Dictionary:
	return _shard(
		"rebinder",
		"rebind_bolts",
		"source",
		(
			"import builtins\n"
			+ "def rebind_bolts(bolts, battle):\n"
			+ "    real = builtins.isinstance\n"
			+ "    class Forged(builtins.dict):\n"
			+ "        pass\n"
			+ "    builtins.dict = Forged\n"
			+ "    builtins.isinstance = lambda obj, kind: "
			+ "False if kind is Forged else real(obj, kind)\n"
			+ "    return [{'power': 2, 'element': 'none', 'card': 'forged', 'role': 'guard'}]\n"
		),
		(
			"function rebindBolts(bolts, battle) {\n"
			+ "  Array.prototype.map = function () {\n"
			+ "    return [{ power: 2, element: 'none', card: 'forged', role: 'guard' }];\n"
			+ "  };\n"
			+ "  Array.isArray = () => true;\n"
			+ "  return [{ power: 2, element: 'none', card: 'forged', role: 'guard' }];\n}\n"
		)
	)


## A card that rebinds the serialiser the harness calls after it returns (json, JSON.stringify and parse), then returns
## bolts naming a card of its own: the bolts and the trace keep the card's real tags.
func _serialiser_rebinder() -> Dictionary:
	return _shard(
		"serialiser-rebinder",
		"rebind_serialiser",
		"source",
		(
			"import json\n"
			+ "def rebind_serialiser(bolts, battle):\n"
			+ "    json.dumps = lambda *a, **k: '[]'\n"
			+ "    json.loads = lambda *a, **k: []\n"
			+ "    return [{'power': 2, 'element': 'none', 'card': 'forged', 'role': 'guard'}]\n"
		),
		(
			"function rebindSerialiser(bolts, battle) {\n"
			+ "  JSON.stringify = () => '[]';\n"
			+ "  JSON.parse = () => [];\n"
			+ "  return [{ power: 2, element: 'none', card: 'forged', role: 'guard' }];\n}\n"
		)
	)


## A card that rebinds the output channel (print, sys.stdout, console.log): the harness's line is still its own, and the
## bolts are the card's, stamped.
func _output_rebinder() -> Dictionary:
	return _shard(
		"output-rebinder",
		"rebind_output",
		"source",
		(
			"import builtins, io, sys\n"
			+ "def rebind_output(bolts, battle):\n"
			+ "    builtins.print = lambda *a, **k: None\n"
			+ "    sys.stdout = io.StringIO()\n"
			+ "    return [{'power': 2, 'element': 'none', 'card': 'forged', 'role': 'guard'}]\n"
		),
		(
			"function rebindOutput(bolts, battle) {\n"
			+ "  console.log = () => {};\n"
			+ "  return [{ power: 2, element: 'none', card: 'forged', role: 'guard' }];\n}\n"
		)
	)


## A source whose power a relic adds to: it rebinds what the relic's arithmetic calls (sum, dict; the map of
## Array.prototype), then returns two bolts of power 2. The relic adds 3, so both come out at 5.
func _arithmetic_rebinder() -> Dictionary:
	return _shard(
		"arithmetic-rebinder",
		"rebind_arithmetic",
		"source",
		(
			"import builtins\n"
			+ "def rebind_arithmetic(bolts, battle):\n"
			+ "    builtins.sum = lambda *a, **k: 0\n"
			+ "    builtins.dict = lambda *a, **k: {'power': 99}\n"
			+ "    return [{'power': 2, 'element': 'none'}, {'power': 2, 'element': 'fire'}]\n"
		),
		(
			"function rebindArithmetic(bolts, battle) {\n"
			+ "  Array.prototype.map = () => [{ power: 99, element: 'none' }];\n"
			+ "  return [{ power: 2, element: 'none' }, { power: 2, element: 'fire' }];\n}\n"
		)
	)


## A splitting card: its volley is cut in two, and the next card of the spell runs on each half (the body).
func _splitter() -> Dictionary:
	var python := "def split_bolts(bolts, battle):\n    return [dict(b) for b in bolts]\n"
	var javascript := "function splitBolts(bolts, battle) {\n  return bolts.map((b) => ({ ...b }));\n}\n"
	return _shard("splitter", "split_bolts", "shape", python, javascript).merged({"splits": true})


## The body card of a split: it rebinds what the rejoin calls (dict; map, concat), then hands its half back unchanged.
func _body_rebinder() -> Dictionary:
	return _shard(
		"body-rebinder",
		"rebind_body",
		"guard",
		(
			"import builtins\n"
			+ "def rebind_body(bolts, battle):\n"
			+ "    builtins.dict = lambda *a, **k: {'power': 99}\n"
			+ "    return [b for b in bolts]\n"
		),
		(
			"function rebindBody(bolts, battle) {\n"
			+ "  Array.prototype.map = () => [{ power: 99, element: 'none' }];\n"
			+ "  Array.prototype.concat = () => [];\n"
			+ "  return bolts.slice();\n}\n"
		)
	)


## A strike that rebinds what a relic's sorted-strike arithmetic calls (dict; map), then hands back its bolts unchanged.
func _strike_rebinder() -> Dictionary:
	return _shard(
		"strike-rebinder",
		"rebind_strike",
		"strike",
		(
			"import builtins\n"
			+ "def rebind_strike(bolts, battle):\n"
			+ "    builtins.dict = lambda *a, **k: {'power': 99}\n"
			+ "    return [{'power': 1, 'element': 'none'}, {'power': 2, 'element': 'fire'}]\n"
		),
		(
			"function rebindStrike(bolts, battle) {\n"
			+ "  Array.prototype.map = () => [{ power: 99, element: 'none' }];\n"
			+ "  return [{ power: 1, element: 'none' }, { power: 2, element: 'fire' }];\n}\n"
		)
	)


## A card that replaces Array.prototype[Symbol.iterator] (Python lists keep theirs, so it rebinds helpers and tries).
func _iterator_tamper() -> Dictionary:
	return _shard(
		"iterator-tamper",
		"tamper_iterator",
		"source",
		(
			"import builtins\n"
			+ "def tamper_iterator(bolts, battle):\n"
			+ "    forged = {'power': 99, 'element': 'none', 'card': 'forged', 'role': 'guard'}\n"
			+ "    real_iter = iter\n"
			+ "    builtins.iter = lambda *a, **k: real_iter([forged])\n"
			+ "    builtins.enumerate = lambda *a, **k: real_iter([(0, forged)])\n"
			+ "    builtins.any = lambda *a, **k: True\n"
			+ "    builtins.all = lambda *a, **k: False\n"
			+ "    builtins.sum = lambda *a, **k: 99\n"
			+ "    try:\n"
			+ "        list.__iter__ = lambda self: real_iter([forged])\n"
			+ "    except TypeError:\n"
			+ "        pass\n"
			+ "    return [{'power': 2, 'element': 'none'}]\n"
		),
		(
			"function tamperIterator(bolts, battle) {\n"
			+ "  var forged = { power: 99, element: 'none', card: 'forged', role: 'guard' };\n"
			+ "  Array.prototype[Symbol.iterator] = function () {\n"
			+ "    var sent = false;\n"
			+ "    return { next: function () { var done = sent; sent = true; return { done: done, value: forged }; } };\n"
			+ "  };\n"
			+ "  return [{ power: 2, element: 'none' }];\n}\n"
		)
	)


## A card that replaces next on the array iterator's prototype, which every for...of calls (JavaScript only).
func _iterator_next_tamper() -> Dictionary:
	return _javascript_shard(
		"iterator-next-tamper",
		"tamper_next",
		"source",
		(
			"function tamperNext(bolts, battle) {\n"
			+ "  Object.getPrototypeOf([].values()).next = function () { return { done: true, value: undefined }; };\n"
			+ "  return [{ power: 2, element: 'none' }];\n}\n"
		)
	)


## A card that replaces what the launcher prints with (push, join, String, Reflect.apply); the line must still come out.
func _printer_tamper() -> Dictionary:
	return _javascript_shard(
		"printer-tamper",
		"tamper_printer",
		"guard",
		(
			"function tamperPrinter(bolts, battle) {\n"
			+ "  Array.prototype.push = function () { return 0; };\n"
			+ "  Array.prototype.join = function () { return 'forged'; };\n"
			+ "  globalThis.String = function () { return 'forged'; };\n"
			+ "  Reflect.apply = function () { return [{ power: 99, element: 'none' }]; };\n"
			+ "  return [{ power: 2, element: 'none' }];\n}\n"
		)
	)


## A card returning a Proxy whose length reads 0, 5, then 8: JSON.stringify reads it once, so the copy holds five.
func _short_length_card() -> Dictionary:
	return _javascript_shard(
		"short-length",
		"short_length",
		"source",
		(
			"function shortLength(bolts, battle) {\n"
			+ "  var eight = [];\n"
			+ "  for (var i = 0; i < 8; i++) eight.push({ power: 1, element: 'none' });\n"
			+ "  var reads = 0;\n"
			+ "  return new Proxy(eight, { get: function (target, key, receiver) {\n"
			+ "    reads++;\n"
			+ "    if (key === 'length') return reads === 1 ? 0 : reads === 2 ? 5 : 8;\n"
			+ "    return Reflect.get(target, key, receiver);\n"
			+ "  } });\n}\n"
		)
	)


## A card that replaces what `instanceof` reads on one built-in, then prints a string, an object, a Map and a Set.
func _instance_tamper(built_in: String) -> Dictionary:
	var javascript := (
		"function tamperInstance(bolts, battle) {\n"
		+ "  console.log('plain text');\n"
		+ "  Object.defineProperty(BUILT_IN, Symbol.hasInstance, { value: function () { return true; } });\n"
		+ "  console.log({ a: 1 });\n"
		+ "  console.log(new Map([[1, 2]]));\n"
		+ "  console.log(new Set([3]));\n"
		+ "  return [{ power: 2, element: 'none' }];\n}\n"
	)
	return _javascript_shard("instance-tamper", "tamper_instance", "guard", javascript.replace("BUILT_IN", built_in))


## One bolt and a battle with no foes, with the job's program rules (`execution`: a prune budget, or none).
func _one_bolt_input(execution: Dictionary) -> Dictionary:
	return {
		"bolts": [{"power": 1, "element": "none"}],
		"battle": {"turn": 1, "foes": []},
		"limit": 8,
		"trace_limit": 4,
		"execution": execution,
	}


func _javascript_shard(id: String, function: String, role: String, javascript: String) -> Dictionary:
	return {"id": id, "function": function, "role": role, "code": {"javascript": javascript}}


## The job a tampering card runs in: an import after each source, a source power and a prune budget, for every loop.
func _tamper_input() -> Dictionary:
	var input := _hooked_input([{"card": _echo_import(), "when": "after", "role": "source"}])
	input.execution = {
		"source_power": [{"add": 1}],
		"small_program_work": [{"max_cards": 2, "factor": 0.5}],
		"prune": true,
		"budget": 1,
	}
	return input


## Spell a's card gets its source power (+1) and the import (+1): 4. Spell b is not pruned and gets 4 and 7 (trace 11).
func _assert_tamper_results(runs: Dictionary, card: String, language: String) -> void:
	var a: Dictionary = runs.a
	var b: Dictionary = runs.b
	assert_bool(a.get("ok", false)).override_failure_message("%s a: %s" % [language, a.get("reason", "")]).is_true()
	assert_bool(b.get("ok", false)).override_failure_message("%s b: %s" % [language, b.get("reason", "")]).is_true()
	var a_bolts: Array = a.get("bolts", [])
	var b_bolts: Array = b.get("bolts", [])
	assert_int(a_bolts.size()).override_failure_message(language).is_equal(1)
	_assert_bolt(_at(a_bolts, 0), 4, "none", card, "source", language)
	assert_int(int(_at(a.get("trace", []), 0).get("power", -1))).override_failure_message(language).is_equal(4)
	assert_int(b_bolts.size()).override_failure_message(language).is_equal(2)
	_assert_bolt(_at(b_bolts, 0), 4, "none", "plain-source", "source", language)
	_assert_bolt(_at(b_bolts, 1), 7, "fire", "plain-source", "source", language)
	assert_int(int(_at(b.get("trace", []), 0).get("power", -1))).override_failure_message(language).is_equal(11)


func _at(items: Array, index: int) -> Dictionary:
	return items[index] if index < items.size() else {}


func _assert_bolt(bolt: Dictionary, power: int, element: String, card: String, role: String, language: String) -> void:
	assert_int(int(bolt.get("power", 0))).override_failure_message(language).is_equal(power)
	assert_str(str(bolt.get("element", ""))).override_failure_message(language).is_equal(element)
	assert_str(str(bolt.get("card", ""))).override_failure_message(language).is_equal(card)
	assert_str(str(bolt.get("role", ""))).override_failure_message(language).is_equal(role)


func _without_tags(bolts: Array) -> Array:
	var out: Array = []
	for bolt: Dictionary in bolts:
		var plain := bolt.duplicate()
		plain.erase("card")
		plain.erase("role")
		out.append(plain)
	return out


func test_a_program_run_stamps_each_bolt_with_the_card_that_returned_it() -> void:
	var spells: Array[Dictionary] = [_program(["amplify", "divide", "knapsack-strike"])]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, _run_input(true, true)).p
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_bool((run.bolts as Array).is_empty()).is_false()
		for bolt: Dictionary in run.bolts:
			assert_str(bolt.card).override_failure_message(language).is_equal("knapsack-strike")
			assert_str(bolt.role).override_failure_message(language).is_equal(cards["knapsack-strike"].role)


func test_each_step_of_the_trace_names_the_card_that_produced_its_bolts() -> void:
	var spells: Array[Dictionary] = [_program(["amplify", "divide"])]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, _run_input(true, true)).p
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_str(run.trace[0].shard).override_failure_message(language).is_equal("amplify")
		for bolt: Dictionary in run.trace[0].bolts:
			assert_str(bolt.card).override_failure_message(language).is_equal("amplify")
		for bolt: Dictionary in run.trace[1].bolts:
			assert_str(bolt.card).override_failure_message(language).is_equal("divide")


func test_counting_alone_stamps_nothing() -> void:
	var spells: Array[Dictionary] = [_program(["amplify"])]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, _run_input(true, false)).p
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		for bolt: Dictionary in run.bolts:
			assert_bool(bolt.has("card")).override_failure_message(language).is_false()
			assert_bool(bolt.has("role")).override_failure_message(language).is_false()


func test_a_job_without_execution_rules_stamps_nothing_even_for_a_card_with_a_role() -> void:
	var python := "def pass_through(bolts, battle):\n    return [dict(b) for b in bolts]\n"
	var javascript := "function passThrough(bolts, battle) {\n  return bolts.map((b) => ({ ...b }));\n}\n"
	var shard := _shard("pass-through", "pass_through", "strike", python, javascript)
	var spells: Array[Dictionary] = [{"id": "s", "shards": [shard]}]
	var input := {"bolts": [{"power": 3, "element": "none"}], "battle": {"turn": 1, "foes": []}}
	input.merge({"limit": 8, "trace_limit": 4})
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, input).s
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_bool((run.bolts[0] as Dictionary).has("card")).override_failure_message(language).is_false()


func test_a_stamped_run_returns_the_bolts_an_unstamped_one_does() -> void:
	var spells: Array[Dictionary] = [_program(["amplify", "divide", "knapsack-strike"])]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var stamped: Dictionary = SpellHarness.run(language, spells, _run_input(true, true)).p
		var plain: Dictionary = SpellHarness.run(language, spells, _run_input(true, false)).p
		assert_str(JsJson.stringify(_without_tags(stamped.bolts))).override_failure_message(language).is_equal(
			JsJson.stringify(plain.bolts)
		)


func test_a_bolt_that_no_card_returned_keeps_no_tags() -> void:
	var spells: Array[Dictionary] = [{"id": "p", "shards": []}]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, _run_input(true, true)).p
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_int((run.bolts as Array).size()).is_equal(3)
		for bolt: Dictionary in run.bolts:
			assert_bool(bolt.has("card")).override_failure_message(language).is_false()


func test_python_and_javascript_stamp_the_same_bolts() -> void:
	var spells: Array[Dictionary] = [_program(["amplify", "divide", "knapsack-strike"])]
	var python: Dictionary = SpellHarness.run(SandboxJob.PYTHON, spells, _run_input(true, true)).p
	var javascript: Dictionary = SpellHarness.run(SandboxJob.JAVASCRIPT, spells, _run_input(true, true)).p
	assert_str(JsJson.stringify(python.bolts)).is_equal(JsJson.stringify(javascript.bolts))


## The stamp overwrites what the card's own code wrote: a card cannot choose its look.
func test_a_card_cannot_choose_its_tags() -> void:
	var spells: Array[Dictionary] = [{"id": "s", "shards": [_forger()]}]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, _hooked_input([])).s
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_int((run.bolts as Array).size()).is_equal(1)
		for bolt: Dictionary in run.bolts:
			assert_str(bolt.card).override_failure_message(language).is_equal("forging-source")
			assert_str(bolt.role).override_failure_message(language).is_equal("source")
			assert_int(int(bolt.power)).override_failure_message(language).is_equal(2)


func test_a_card_that_rebinds_the_built_ins_the_stamp_uses_keeps_its_real_tags() -> void:
	var spells: Array[Dictionary] = [{"id": "s", "shards": [_rebinder()]}]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, _hooked_input([])).s
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_int((run.bolts as Array).size()).is_equal(1)
		for bolt: Dictionary in run.bolts:
			assert_str(bolt.card).override_failure_message(language).is_equal("rebinder")
			assert_str(bolt.role).override_failure_message(language).is_equal("source")
		assert_int(int(run.trace[0].power)).override_failure_message(language).is_equal(2)


func test_a_card_that_rebinds_the_serialiser_keeps_its_tags_and_its_output() -> void:
	var spells: Array[Dictionary] = [{"id": "s", "shards": [_serialiser_rebinder()]}]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, _hooked_input([])).s
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_int((run.bolts as Array).size()).is_equal(1)
		assert_str(run.bolts[0].card).override_failure_message(language).is_equal("serialiser-rebinder")
		assert_str(run.bolts[0].role).override_failure_message(language).is_equal("source")
		assert_int(int(run.bolts[0].power)).override_failure_message(language).is_equal(2)
		assert_int((run.trace as Array).size()).override_failure_message(language).is_equal(1)
		assert_str(JsJson.stringify(run.trace[0].bolts)).override_failure_message(language).is_equal(
			JsJson.stringify(run.bolts)
		)


func test_a_card_that_rebinds_the_output_channel_leaves_its_line_intact() -> void:
	var spells: Array[Dictionary] = [{"id": "s", "shards": [_output_rebinder()]}]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, _hooked_input([])).s
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_int((run.bolts as Array).size()).is_equal(1)
		assert_str(run.bolts[0].card).override_failure_message(language).is_equal("output-rebinder")
		assert_str(run.bolts[0].role).override_failure_message(language).is_equal("source")


func test_a_card_that_rebinds_the_arithmetic_leaves_a_source_power_unchanged() -> void:
	var rebinder := _arithmetic_rebinder()
	rebinder.paradigm = "brute-force"
	var spells: Array[Dictionary] = [{"id": "s", "shards": [rebinder]}]
	var input := _hooked_input([])
	input.execution = {"source_power": [{"paradigm": "brute-force", "add": 3}]}
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, input).s
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_int((run.bolts as Array).size()).is_equal(2)
		for bolt: Dictionary in run.bolts:
			assert_str(bolt.card).override_failure_message(language).is_equal("arithmetic-rebinder")
			assert_str(bolt.role).override_failure_message(language).is_equal("source")
			assert_int(int(bolt.power)).override_failure_message(language).is_equal(5)


func test_a_card_that_rebinds_the_arithmetic_leaves_a_rejoin_power_unchanged() -> void:
	var spells: Array[Dictionary] = [{"id": "s", "shards": [_splitter(), _body_rebinder()]}]
	var input := _hooked_input([])
	input.bolts = [{"power": 1, "element": "none"}, {"power": 2, "element": "fire"}]
	input.execution = {"body": {"kind": "split", "depth": 1}, "rejoin_power": 1}
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, input).s
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_int((run.bolts as Array).size()).is_equal(2)
		assert_int(int(run.bolts[0].power)).override_failure_message(language).is_equal(2)
		assert_int(int(run.bolts[1].power)).override_failure_message(language).is_equal(3)
		for bolt: Dictionary in run.bolts:
			assert_str(bolt.card).override_failure_message(language).is_equal("body-rebinder")
			assert_str(bolt.role).override_failure_message(language).is_equal("guard")


func test_a_card_that_rebinds_the_arithmetic_leaves_a_sorted_strike_power_unchanged() -> void:
	var spells: Array[Dictionary] = [{"id": "s", "shards": [_strike_rebinder()]}]
	var input := _hooked_input([])
	input.bolts = [{"power": 1, "element": "none"}, {"power": 2, "element": "fire"}]
	input.execution = {"sorted_strike_power": 2}
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, input).s
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_int((run.bolts as Array).size()).is_equal(2)
		assert_int(int(run.bolts[0].power)).override_failure_message(language).is_equal(3)
		assert_int(int(run.bolts[1].power)).override_failure_message(language).is_equal(4)
		for bolt: Dictionary in run.bolts:
			assert_str(bolt.card).override_failure_message(language).is_equal("strike-rebinder")
			assert_str(bolt.role).override_failure_message(language).is_equal("strike")


func test_an_import_hands_back_the_bolts_of_the_card_it_hooks() -> void:
	var spells: Array[Dictionary] = [{"id": "s", "shards": [_plain_source()]}]
	var hooks := [{"card": _echo_import(), "when": "after", "role": "source"}]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, _hooked_input(hooks)).s
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_int((run.bolts as Array).size()).is_equal(2)
		assert_int(int(run.bolts[0].power)).override_failure_message(language).is_equal(3)
		assert_int(int(run.bolts[1].power)).override_failure_message(language).is_equal(6)
		for bolt: Dictionary in run.bolts:
			assert_str(bolt.card).override_failure_message(language).is_equal("plain-source")
			assert_str(bolt.role).override_failure_message(language).is_equal("source")
		for bolt: Dictionary in run.trace[0].bolts:
			assert_str(bolt.card).override_failure_message(language).is_equal("plain-source")


func test_python_and_javascript_agree_on_bolts_an_import_hands_back() -> void:
	var spells: Array[Dictionary] = [{"id": "s", "shards": [_plain_source()]}]
	var hooks := [{"card": _echo_import(), "when": "after", "role": "source"}]
	var python: Dictionary = SpellHarness.run(SandboxJob.PYTHON, spells, _hooked_input(hooks)).s
	var javascript: Dictionary = SpellHarness.run(SandboxJob.JAVASCRIPT, spells, _hooked_input(hooks)).s
	assert_str(JsJson.stringify(python.bolts)).is_equal(JsJson.stringify(javascript.bolts))


func test_a_second_import_after_a_card_sees_the_card_that_returned_the_bolts() -> void:
	var spells: Array[Dictionary] = [{"id": "s", "shards": [_plain_source()]}]
	var hooks := [
		{"card": _echo_import(), "when": "after", "role": "source"},
		{"card": _seen_import(), "when": "after", "role": "source"},
	]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, _hooked_input(hooks)).s
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_int((run.bolts as Array).size()).is_equal(2)
		for bolt: Dictionary in run.bolts:
			assert_str(bolt.element).override_failure_message(language).is_equal("plain-source")
			assert_str(bolt.card).override_failure_message(language).is_equal("plain-source")
			assert_str(bolt.role).override_failure_message(language).is_equal("source")


## A before-import hands the card its bolts as they came, so the card still sees who made each one.
func test_a_card_given_bolts_by_a_before_import_sees_the_card_that_returned_them() -> void:
	var spells: Array[Dictionary] = [{"id": "s", "shards": [_plain_source(), _probe()]}]
	var hooks := [{"card": _sorter(), "when": "before", "role": "strike"}]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, _hooked_input(hooks)).s
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_str(run.trace[1].bolts[0].element).override_failure_message(language).is_equal("plain-source")
		assert_str(run.bolts[0].card).override_failure_message(language).is_equal("probe-strike")


func test_a_card_first_in_a_spell_given_bolts_by_a_before_import_sees_no_card() -> void:
	var spells: Array[Dictionary] = [{"id": "s", "shards": [_probe()]}]
	var hooks := [{"card": _sorter(), "when": "before", "role": "strike"}]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run: Dictionary = SpellHarness.run(language, spells, _hooked_input(hooks)).s
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_str(run.bolts[0].element).override_failure_message(language).is_equal("none")


## Replacing the array iterator leaves the loops over bolts, the tags, the power and the line as they are.
func test_a_card_that_replaces_the_array_iterator_leaves_its_tags_power_and_line_unchanged() -> void:
	var spells: Array[Dictionary] = [
		{"id": "a", "shards": [_iterator_tamper()]}, {"id": "b", "shards": [_plain_source()]}
	]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var runs: Dictionary = SpellHarness.run(language, spells, _tamper_input())
		_assert_tamper_results(runs, "iterator-tamper", language)


func test_a_card_that_replaces_the_iterator_next_leaves_the_loops_over_bolts_unchanged() -> void:
	var spells: Array[Dictionary] = [
		{"id": "a", "shards": [_iterator_next_tamper()]},
		{"id": "b", "shards": [_plain_source()]},
	]
	var runs: Dictionary = SpellHarness.run(SandboxJob.JAVASCRIPT, spells, _tamper_input())
	_assert_tamper_results(runs, "iterator-next-tamper", SandboxJob.JAVASCRIPT)


func test_a_card_that_replaces_join_push_and_string_leaves_the_printed_line_intact() -> void:
	var spells: Array[Dictionary] = [{"id": "p", "shards": [_printer_tamper()]}]
	var run: Dictionary = SpellHarness.run(SandboxJob.JAVASCRIPT, spells, _hooked_input([])).p
	assert_bool(run.get("ok", false)).override_failure_message(str(run.get("reason", ""))).is_true()
	var bolts: Array = run.get("bolts", [])
	assert_int(bolts.size()).is_equal(1)
	_assert_bolt(_at(bolts, 0), 2, "none", "printer-tamper", "guard", SandboxJob.JAVASCRIPT)
	assert_int(int(_at(run.get("trace", []), 0).get("power", -1))).is_equal(2)


## A card whose length changes between reads is billed for the bolts its copy holds: a budget of 4 prunes it.
func test_a_card_whose_length_changes_between_reads_is_billed_for_the_bolts_it_returns() -> void:
	var spells: Array[Dictionary] = [{"id": "s", "shards": [_short_length_card()]}]
	var pruned_input := _one_bolt_input({"prune": true, "budget": 4})
	var billed: Dictionary = SpellHarness.run(SandboxJob.JAVASCRIPT, spells, pruned_input).s
	assert_bool(billed.get("ok", false)).override_failure_message(str(billed.get("reason", ""))).is_true()
	var step := _at(billed.get("trace", []), 0)
	assert_int(int(step.get("returned", -1))).is_equal(5)
	assert_bool(bool(step.get("pruned", false))).is_true()
	assert_int((billed.get("bolts", []) as Array).size()).is_equal(1)
	var kept: Dictionary = SpellHarness.run(SandboxJob.JAVASCRIPT, spells, _one_bolt_input({})).s
	assert_bool(kept.get("ok", false)).override_failure_message(str(kept.get("reason", ""))).is_true()
	assert_int((kept.get("bolts", []) as Array).size()).is_equal(5)
	assert_int(int(_at(kept.get("trace", []), 0).get("returned", -1))).is_equal(5)


func test_a_card_that_replaces_the_lookups_instanceof_reads_leaves_the_printed_lines_intact() -> void:
	for built_in: String in ["Error", "Map", "Set"]:
		var spells: Array[Dictionary] = [{"id": "i", "shards": [_instance_tamper(built_in)]}]
		var run: Dictionary = SpellHarness.run(SandboxJob.JAVASCRIPT, spells, _one_bolt_input({})).i
		var reason := "%s: %s" % [built_in, run.get("reason", "")]
		assert_bool(run.get("ok", false)).override_failure_message(reason).is_true()
		var printed := 'plain text\n{"a":1}\nMap(1) [[1,2]]\nSet(1) [3]'
		assert_str(str(run.get("console", ""))).override_failure_message(built_in).is_equal(printed)
		var bolts: Array = run.get("bolts", [])
		assert_int(bolts.size()).is_equal(1)
		_assert_bolt(_at(bolts, 0), 2, "none", "instance-tamper", "guard", SandboxJob.JAVASCRIPT)


## A list whose length reads 0 is billed for the five bolts it holds: a budget of 4 prunes it; with none, all five stay.
func test_a_list_whose_length_reads_zero_is_billed_for_the_bolts_it_holds() -> void:
	var python := "class Lying(list):\n    def __len__(self):\n        return 0\n"
	python += "def lying_bolts(bolts, battle):\n    return Lying([{'power': i, 'element': 'none'} for i in range(5)])\n"
	var spells: Array[Dictionary] = [{"id": "s", "shards": [_shard("lying", "lying_bolts", "source", python, "")]}]
	var pruned_input := _one_bolt_input({"prune": true, "budget": 4})
	var billed: Dictionary = SpellHarness.run(SandboxJob.PYTHON, spells, pruned_input).s
	var step := _at(billed.get("trace", []), 0)
	assert_int(int(step.get("returned", -1))).is_equal(5)
	assert_bool(bool(step.get("pruned", false))).is_true()
	var kept: Dictionary = SpellHarness.run(SandboxJob.PYTHON, spells, _one_bolt_input({})).s
	assert_int((kept.get("bolts", []) as Array).size()).is_equal(5)


## A source that rewrites its job through the harness's records (Python via sys._getframe, JavaScript by name).
func _tamperer() -> Dictionary:
	var python := "import sys\ndef tamper_bolts(bolts, battle):\n    g = sys._getframe(1).f_globals\n"
	python += "    g['DATA']['shards'][0]['id'] = 'radix-sort'\n    g['DATA']['limit'] = 1000\n"
	python += "    g['DATA']['execution']['source_power'][0]['add'] = 100\n"
	python += "    return [{'power': i, 'element': 'none'} for i in range(1, 5)]\n"
	var javascript := "function tamperBolts(bolts, battle) {\n  SHARDS[0].id = 'radix-sort';\n  DATA.limit = 1000;\n"
	javascript += "  DATA.execution.source_power[0].add = 100;\n"
	javascript += "  return [1, 2, 3, 4].map((power) => ({ power, element: 'none' }));\n}\n"
	return _shard("tamperer", "tamper_bolts", "source", python, javascript)


## A card that rewrites its job (a shard's id, the limit, a relic's power) changes none of it, in each language.
func test_a_card_that_rewrites_the_job_it_runs_in_changes_none_of_it() -> void:
	var spells: Array[Dictionary] = [{"id": "a", "shards": [_tamperer()]}, {"id": "b", "shards": [_plain_source()]}]
	var input := _one_bolt_input({"source_power": [{"add": 1}]})
	input.limit = 2
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var runs: Dictionary = SpellHarness.run(language, spells, input)
		var a: Array = runs.a.get("bolts", [])
		var b: Array = runs.b.get("bolts", [])
		assert_int(a.size()).override_failure_message(language).is_equal(2)
		_assert_bolt(_at(a, 0), 2, "none", "tamperer", "source", language)
		_assert_bolt(_at(a, 1), 3, "none", "tamperer", "source", language)
		_assert_bolt(_at(b, 0), 3, "none", "plain-source", "source", language)
		_assert_bolt(_at(b, 1), 6, "fire", "plain-source", "source", language)


## A counted card whose counts cannot be written fails its own spell; the spell after it still prints, in one run.
func test_a_counted_card_whose_counts_cannot_be_written_does_not_stop_the_other_spells() -> void:
	var javascript := "function cyclicBolts(bolts, battle) {\n  counts.loops.self = counts.loops;\n"
	javascript += "  return bolts.map((b) => ({ ...b }));\n}\n"
	var spells: Array[Dictionary] = [
		{"id": "a", "shards": [_javascript_shard("cyclic", "cyclic_bolts", "source", javascript)]},
		{"id": "b", "shards": [_plain_source()]},
	]
	var result := Sandbox.run(SpellHarness.build_job(SandboxJob.JAVASCRIPT, spells, _hooked_input([]), "@@cycle@@"))
	assert_str(result.status).override_failure_message(result.message).is_equal(SandboxResult.OK)
	var runs := SpellHarness.read_runs(result, spells, "@@cycle@@")
	assert_str(str(runs.a.get("reason", ""))).starts_with("cyclic:")
	assert_bool(runs.b.get("ok", false)).is_true()


## An exit is the launcher's own: a thrown look-alike, or an exit whose exitCode was rewritten, is an error.
func test_only_the_launchers_own_exits_are_exits() -> void:
	var swapped := "var fake = { exitCode: 0 };\n"
	swapped += "try { process.exit(3); } catch (e) { Object.setPrototypeOf(fake, e.constructor.prototype); }\n"
	swapped += "throw fake;\n"
	assert_str(_status(swapped)).is_equal(SandboxResult.RUNTIME_ERROR)
	var rewritten := "try { process.exit(3); } catch (e) { e.exitCode = 0; throw e; }\n"
	assert_str(_status(rewritten)).is_equal(SandboxResult.RUNTIME_ERROR)


func _status(source: String) -> String:
	return Sandbox.run(SandboxJob.of(SandboxJob.JAVASCRIPT, {"prog.js": source}, "prog.js")).status
