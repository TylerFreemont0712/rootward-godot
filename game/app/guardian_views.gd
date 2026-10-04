class_name GuardianViews
extends RefCounted
## The guardian pool in words (docs/NewEnemies.md, ADR-0026): what a guardian will do next, what its trait means, and
## the state it shows over its head (its guard this turn, its cache, the damage pending, its frames...). Read by
## ShardrunViews and the foe cards; nothing here decides anything.


## A pool intent in words, or "" for an ordinary one (ShardrunViews words those). States come first: a stunned or
## recompiling guardian does nothing, whatever its intent.
static func intent_text(foe: Dictionary, intent: Dictionary) -> String:
	if foe.get("stunned", false):
		return Text.t("Stunned")
	if foe.get("recompiling", false):
		return Text.t("Recompiling")
	var striking: bool = intent.kind in ["strike", "multi", "loop", "count", "throw"]
	if (foe.get("trait", {}) as Dictionary).get("kind") == ProgramGuardians.PAGED and not foe.get("resident", false):
		if striking:
			return Text.t("Swapped out")
	var enrage := float((foe.get("trait", {}) as Dictionary).get("enrage", 1.0)) if foe.get("enraged", false) else 1.0
	var text := ""
	match intent.kind:
		"strike":
			if enrage != 1.0:
				text = Text.f(
					"Strike for %d (enraged)",
					[floori(int(intent.power) * (2 if foe.get("stoked", false) else 1) * enrage)]
				)
		"multi":
			if enrage != 1.0:
				text = Text.f(
					"Strike %d times for %d (enraged)", [int(intent.times), floori(int(intent.power) * enrage)]
				)
		"loop":
			text = Text.f("Loop %d × %d", [int(foe.get("loop", intent.start)), int(intent.power)])
		"throw":
			text = Text.f("Throw %d (catch: %d block)", [throw_power(foe, intent), throw_power(foe, intent)])
		"summon":
			text = Text.t("Allocate a block")
		"realloc":
			text = Text.f("Heal %d per block", [int(intent.amount)])
		"mend-swapped":
			text = Text.f("Mend %d (pages out)", [int(intent.amount)])
		"count":
			var power := count_power(foe, intent)
			text = Text.f("Strike for %d", [power]) if power < int(intent.wrap) else Text.t("Overflows: nothing")
		"mutate":
			text = Text.f("Mutate %d cards", [int(intent.count)])
		"idle":
			text = Text.t("Allocated")
	return named(intent, text) if text != "" else ""


## Ordinary intents with a name ("Bite") are worded by ShardrunViews and named here.
static func named(intent: Dictionary, text: String) -> String:
	var name := Text.t(String(intent.get("name", "")))
	return "%s · %s" % [name, text] if name != "" else text


static func throw_power(foe: Dictionary, intent: Dictionary) -> int:
	return int(intent.power) + int(foe.get("trace", 0))


static func count_power(foe: Dictionary, intent: Dictionary) -> int:
	return int(intent.power) * (1 << int(foe.get("counted", 0)))


## The damage a pool intent will deal if nothing stops it, or -1 when it is an ordinary one.
static func incoming(foe: Dictionary, intent: Dictionary) -> int:
	if foe.get("stunned", false) or foe.get("recompiling", false):
		return 0
	if (foe.get("trait", {}) as Dictionary).get("kind") == ProgramGuardians.PAGED and not foe.get("resident", false):
		return 0
	var enrage := float((foe.get("trait", {}) as Dictionary).get("enrage", 1.0)) if foe.get("enraged", false) else 1.0
	match intent.kind:
		"strike":
			return floori(int(intent.power) * (2 if foe.get("stoked", false) else 1) * enrage)
		"multi":
			return floori(int(intent.power) * enrage) * int(intent.times)
		"loop":
			return int(intent.power) * int(foe.get("loop", intent.start))
		"throw":
			return throw_power(foe, intent)
		"count":
			var power := count_power(foe, intent)
			return power if power < int(intent.wrap) else 0
		"summon", "realloc", "mend-swapped", "mutate", "idle":
			return 0
	return -1


## A pool trait's name and what it does, or {}.
static func trait_view(foe: Dictionary) -> Dictionary:
	var foe_trait: Dictionary = foe.get("trait", {})
	match foe_trait.get("kind", ""):
		"loop-guard":
			return {
				"name": "while True",
				"text":
				Text.t(
					"Land a volley that meets its guard and the loop breaks: +50%, it is stunned, the count resets."
				),
			}
		"stack-trace":
			return {
				"name": "raise",
				"text":
				Text.t("Block at least a throw's power to catch it: it bounces back at 150%. Uncaught, throws grow."),
			}
		"short-circuit":
			return {
				"name": Text.t("Short circuit"),
				"text":
				Text.t(
					"The first bolt at it must meet its guard. Below it, the rest never land; at or above, it doubles."
				),
			}
		"unreachable":
			return {
				"name": Text.t("Dead code"),
				"text": Text.t("Cards at or after its return slot do not run (and still cost mana).")
			}
		"lru-cache":
			return {
				"name": Text.t("LRU cache"),
				"text": Text.t("A bolt whose power is cached deals nothing. New powers hurt in full.")
			}
		"allocator":
			return {
				"name": "malloc",
				"text":
				Text.t(
					"Each block shields her 3 a turn; at 5 blocks, Out of Memory. Breaking a block gives you 3 block."
				),
			}
		"heap-block":
			return {"name": "free()", "text": Text.t("Break it to free it: 3 block for you.")}
		ProgramGuardians.PAGED:
			return {
				"name": Text.t("Paged"),
				"text":
				Text.t(
					"Only the resident page takes hits and strikes. A bolt at another is a page fault and swaps it in."
				),
			}
		"lazy":
			return {
				"name": Text.t("Lazy"),
				"text": Text.t("Hits pile up as pending. A bolt of 15 or more forces it all at +25%.")
			}
		"call-stack":
			return {
				"name": "LIFO",
				"text":
				Text.t("Only the top frame takes damage; the rest of a bolt is lost. Left alone, it pushes a frame."),
			}
		"int8":
			return {
				"name": "int8",
				"text": Text.t("Damage over 127 wraps around: 128 is -128, and negative damage heals it.")
			}
		"profiler":
			return {
				"name": Text.t("Profiler"),
				"text": Text.t("Damage scales with your program's slowest class: fast code, more.")
			}
		"livelock":
			return {
				"name": Text.t("Livelock"),
				"text": Text.t("Every hit swaps the twins. When one falls, the other enrages.")
			}
		"mutator":
			return {
				"name": Text.t("Mutation"),
				"text": Text.t("It edits your cards. Land 25 in one program to kill the mutants in it.")
			}
		"certificate":
			return {
				"name": Text.t("Subset sum"),
				"text":
				Text.t("Bolts that add up to exactly its target deal double and stun it. Without one, all are halved."),
			}
		"oracle":
			return {
				"name": Text.t("Oracle"),
				"text":
				Text.t("If its prediction about your program is right, it takes nothing and half is reflected."),
			}
		"compiler":
			return {
				"name": Text.t("Compiler"),
				"text": Text.t("Three phases: the guardians you beat, then itself, self-hosting.")
			}
	return {}


## What a guardian shows over its head this turn: [{text, tone, tip}], tone one of warn, teal, shard, faint, fire.
static func chips(foe: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var foe_trait: Dictionary = foe.get("trait", {})
	if foe.get("stunned", false):
		out.append({"text": Text.t("stunned"), "tone": "teal", "tip": Text.t("It loses its next turn.")})
	if foe.has("compiler"):
		var compiler: Dictionary = foe.compiler
		(
			out
			. append(
				{
					"text": Text.f("phase %d/3", [int(compiler.phase) + 1]),
					"tone": "shard",
					"tip": Text.f("Compiled as %s.", [Text.t(String(foe.get("compiled", foe.name)))]),
				}
			)
		)
	match foe_trait.get("kind", ""):
		"loop-guard":
			var guard: Dictionary = foe.get("guard", {})
			out.append(
				{"text": GuardianLanding.guard_code(guard), "tone": "warn", "tip": Text.t("Meet it to break the loop.")}
			)
			out.append(
				{
					"text": Text.f("loop ×%d", [int(foe.get("loop", 2))]),
					"tone": "fire",
					"tip": Text.t("Hits in its next Loop.")
				}
			)
		"stack-trace":
			if int(foe.get("trace", 0)) > 0:
				out.append(
					{
						"text": Text.f("trace +%d", [int(foe.trace)]),
						"tone": "fire",
						"tip": Text.t("Added to every throw.")
					}
				)
		"short-circuit":
			var guard := int(foe.get("guard", 0))
			out.append(
				{
					"text": Text.f("first ≥ %d", [guard]),
					"tone": "warn",
					"tip": Text.f("Lead with a bolt of %d or more.", [guard])
				}
			)
		"unreachable":
			(
				out
				. append(
					{
						"text": Text.f("return @ slot %d", [int(foe.get("return_at", 5))]),
						"tone": "warn",
						"tip": Text.t("Cards in this slot and after are dead code this turn."),
					}
				)
			)
		"lru-cache":
			var cache: Array = foe.get("cache", [])
			var shown := " ".join(PackedStringArray(cache.map(func(power: int) -> String: return str(power))))
			(
				out
				. append(
					{
						"text": Text.f("cache: %s", [shown if shown != "" else Text.t("empty")]),
						"tone": "shard",
						"tip": Text.t("Bolts of these powers deal nothing."),
					}
				)
			)
		ProgramGuardians.PAGED:
			if foe.get("resident", false):
				out.append(
					{"text": Text.t("resident"), "tone": "teal", "tip": Text.t("In memory: bolts at this page land.")}
				)
			else:
				out.append(
					{"text": Text.t("swapped out"), "tone": "faint", "tip": Text.t("A bolt here is a page fault.")}
				)
		"lazy":
			if int(foe.get("pending", 0)) > 0:
				(
					out
					. append(
						{
							"text": Text.f("pending %d", [int(foe.pending)]),
							"tone": "fire",
							"tip": Text.t("Forced by a bolt of 15+, at +25%. Halves at the end of the turn."),
						}
					)
				)
		"call-stack":
			var frames: Array = foe.get("frames", [])
			if not frames.is_empty():
				(
					out
					. append(
						{
							"text": Text.f("%d frames · top %d", [frames.size(), int(frames[-1])]),
							"tone": "warn",
							"tip":
							Text.f("Frames, bottom to top: %s.", [", ".join(PackedStringArray(frames.map(str)))]),
						}
					)
				)
		"livelock":
			if foe.get("enraged", false):
				out.append({"text": Text.t("enraged"), "tone": "fire", "tip": Text.t("Its strikes hit 50% harder.")})
		"certificate":
			(
				out
				. append(
					{
						"text": Text.f("target %d", [int(foe.get("target", 0))]),
						"tone": "warn",
						"tip": Text.t("Bolts at it that add up to exactly this deal double."),
					}
				)
			)
		"oracle":
			(
				out
				. append(
					{
						"text":
						Text.f(
							"predicts: %s", [Text.sentence(GuardianLanding.prediction_text(foe.get("prediction", {})))]
						),
						"tone": "warn",
						"tip": Text.t("Run a program without this property."),
					}
				)
			)
	return out
