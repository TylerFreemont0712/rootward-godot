class_name RootCompiler
extends RefCounted
## The Root Compiler, the finale (docs/NewEnemies.md, ADR-0026): three phases, changing at the thresholds of its trait.
## The first two compile in a guardian you beat earlier in this run (the Salvage's, then the Heap's): its trait, where
## one body can carry it, and its intents at the trait's power. The third is its own, self-hosting: its tempo is
## the work your last program did. Between phases it spends a turn recompiling, its shield dropped.

## Traits a single body can carry. The rest need partners (a deadlock, pages, twins), frames, blocks or phases of their
## own, and the compiled guardian brings only its intents.
const COMPILABLE: Array[String] = [
	"thick-hide",
	"pattern-ward",
	"shifting-weakness",
	"nullify-first",
	"loop-guard",
	"stack-trace",
	"short-circuit",
	"unreachable",
	"lru-cache",
	"lazy",
	"int8",
	"profiler",
	"certificate",
	"oracle",
	"quine",
	"mutator",
]
## The layers whose guardians it compiles, in phase order.
const SOURCES: Array[int] = [0, 1]


static func prepare(foe: Dictionary, state: Dictionary, catalog: Dictionary) -> void:
	var own := {"name": foe.name, "trait": {}, "intents": (foe.intents as Array).duplicate(true)}
	var phases: Array = []
	for layer in SOURCES:
		var compiled := _compiled(state, layer, float(foe.trait.power), catalog)
		phases.append(compiled if not compiled.is_empty() else own.duplicate(true))
	phases.append(own)
	for phase: Dictionary in phases:
		ProgramGuardians.embed_minions(phase.intents, state, catalog)
	foe.compiler = {"thresholds": (foe.trait.phases as Array).duplicate(), "phases": phases, "phase": 0}
	_become(foe, phases[0], state, catalog)


## The guardian beaten on `layer` this run, compiled: {name, trait, intents}; {} when none was (a jump in dev mode).
static func _compiled(state: Dictionary, layer: int, power: float, catalog: Dictionary) -> Dictionary:
	for beaten: Dictionary in (state.get("stats", {}) as Dictionary).get("guardians", []):
		if int(beaten.layer) != layer or (beaten.foes as Array).is_empty():
			continue
		var def: Dictionary = catalog.foes.get(beaten.foes[0], {})
		if def.is_empty():
			return {}
		var intents: Array = []
		var tempos: Array = (
			((catalog.get("programs", {}) as Dictionary).get("config", {}) as Dictionary)
			. get("tempo", {})
			. get(def.id, [])
		)
		for index in (def.intents as Array).size():
			var intent: Dictionary = (def.intents[index] as Dictionary).duplicate(true)
			for key: String in ["power", "amount"]:
				if intent.has(key):
					intent[key] = maxi(1, roundi(int(intent[key]) * power))
			if not intent.has("tempo") and not tempos.is_empty():
				intent.tempo = int(tempos[index % tempos.size()])
			intents.append(intent)
		var foe_trait: Dictionary = def.get("trait", {})
		var carried := foe_trait.duplicate(true) if foe_trait.get("kind", "") in COMPILABLE else {}
		return {"name": def.name, "trait": carried, "intents": intents}
	return {}


## The foe takes on a phase: its trait (and that trait's state) and intents, from the top of their cycle.
static func _become(foe: Dictionary, phase: Dictionary, state: Dictionary, catalog: Dictionary) -> void:
	foe.trait = (phase.trait as Dictionary).duplicate(true)
	foe.intents = (phase.intents as Array).duplicate(true)
	foe.intent_index = 0
	foe.compiled = phase.name
	ProgramGuardians.prepare(foe, {"hp": foe.max}, state, catalog)


## After a landing: past a threshold it recompiles into its next phase and loses its next turn doing it.
static func check(state: Dictionary, battle: Dictionary, foe: Dictionary) -> void:
	var compiler: Dictionary = foe.compiler
	var at := int(compiler.phase)
	var thresholds: Array = compiler.thresholds
	if int(foe.hp) <= 0 or at >= thresholds.size() or int(foe.hp) > floori(int(foe.max) * float(thresholds[at])):
		return
	compiler.phase = at + 1
	var phase: Dictionary = compiler.phases[at + 1]
	# Phase changes need no catalog: every phase was compiled when the fight began (summons carry their minion).
	_become(foe, phase, state, {"foes": {}, "programs": {}})
	ProgramGuardians.begin_foe(foe, battle)
	foe.recompiling = true
	foe.shield = 0
	var into := "itself" if at + 1 == thresholds.size() else String(phase.name)
	var text := "%s recompiles into %s. It spends its next turn doing it, shield down." % [foe.name, into]
	Shardrun.record(state, {"kind": "note", "foe": foe.uid, "word": "recompiling", "text": text})
