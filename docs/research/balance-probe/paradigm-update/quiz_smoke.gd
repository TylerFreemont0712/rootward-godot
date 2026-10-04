extends SceneTree
## Drives the four program quizzes through ProgramIssues and SpellRuns for each supported language.
##   XDG_DATA_HOME=/tmp/rootward-quiz godot --headless --path game -s \
##       "$PWD/docs/research/balance-probe/paradigm-update/quiz_smoke.gd" < /dev/null

const LANGUAGES := ["python", "javascript", "cpp"]
const QUIZZES := {
	"rubber-duck": {"issue": "rubber-duck", "kind": "rubber-duck", "layer": 0},
	"oracle-test-suite": {"issue": "oracle-test-suite", "kind": "oracle", "layer": 1},
	"big-o-quiz": {"issue": "big-o-quiz", "kind": "big-o", "layer": 0},
	"will-it-halt": {"issue": "will-it-halt", "kind": "halt", "layer": 3},
}

var catalog: Dictionary
var runs: SpellRuns
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)
	for language: String in LANGUAGES:
		runs = SpellRuns.new(catalog)
		for quiz_id: String in QUIZZES:
			var settings: Dictionary = QUIZZES[quiz_id]
			var state := _prepared_state(language, int(settings.layer), String(settings.kind))
			var definition: Dictionary = catalog.programs.issues[settings.issue]
			state.issues_seen = (catalog.programs.issues.keys() as Array).filter(
				func(id: String) -> bool: return id != String(settings.issue)
			)
			ProgramIssues.enter(state, {"id": "quiz-smoke-%s-%s" % [language, quiz_id], "kind": "issue"}, catalog)
			if String(state.issue.id) != String(settings.issue):
				_fail("%s/%s: Issue selection produced %s" % [language, quiz_id, state.issue.id])
				continue
			var choice := _quiz_choice(definition, String(settings.kind))
			state = _send(state, {"type": "issue-choose", "index": choice})
			if failed:
				continue
			var quiz: Dictionary = state.issue.quiz
			if not bool(quiz.ready):
				var actual_runs: Array = await runs.quiz_runs(state, quiz.plan)
				var question := ProgramQuiz.build(quiz.plan, actual_runs, state, catalog)
				state = _send(state, {"type": "issue-quiz-ready", "question": question})
				if failed:
					continue
				quiz = state.issue.quiz
			if not quiz.has("answer") or (quiz.options as Array).is_empty():
				_fail("%s/%s: quiz question was not built" % [language, quiz_id])
				continue
			var plan_kind := String(quiz.plan.kind)
			if plan_kind != String(settings.kind):
				_fail("%s/%s: expected %s, got %s" % [language, quiz_id, settings.kind, plan_kind])
				continue
			var version_cards: Array = (quiz.plan.get("versions", []) as Array).map(
				func(version: Dictionary) -> String: return String(version.card)
			)
			if version_cards.is_empty():
				version_cards = quiz.plan.get("cards", [])
			state = _send(state, {"type": "issue-answer", "index": int(quiz.answer)})
			state = _finish_issue(state)
			if failed:
				continue
			if state.status != "map":
				_fail("%s/%s: expected map after answering, got %s" % [language, quiz_id, state.status])
				continue
			print(
				(
					"QUIZ_OK language=%s issue=%s kind=%s cards=%s"
					% [language, quiz_id, plan_kind, ",".join(version_cards)]
				)
			)
	quit(1 if failed else 0)


func _prepared_state(language: String, layer: int, kind: String) -> Dictionary:
	var state := Shardrun.start(
		catalog,
		{
			"seed": "quiz-smoke-%s-%s" % [language, kind],
			"language": language,
			"difficulty": "beginner",
			"playstyle": "program"
		}
	)
	state = _send(state, {"type": "pick-paradigm", "paradigm_id": String(state.draft.offers[0])})
	state = _send(state, {"type": "pick-focus", "focus_id": String(state.draft.focus_offers[0])})
	while state.status == "draft":
		state = _send(state, {"type": "draft-card", "card_id": String(state.draft.pack[0])})
	state.layer = layer
	state.deck = _quiz_deck(language, kind)
	return state


func _quiz_deck(language: String, kind: String) -> Array:
	var candidates: Array[String] = []
	for id: String in ShardrunCatalog.sorted_values(catalog.shards).map(
		func(card: Dictionary) -> String: return String(card.id)
	):
		var card: Dictionary = catalog.shards[id]
		if card.get("role", "") in ["import", "utility", "guard"] or card.get("splits", false):
			continue
		if (card.get("code", {}) as Dictionary).has(language):
			candidates.append(id)
	if kind == "oracle":
		var census: Dictionary = (catalog.programs.mutants as Dictionary).get(language, {})
		for id: String in candidates:
			if (census.get(id, []) as Array).size() >= 2:
				return [id]
		return []
	if kind in ["rubber-duck", "halt"]:
		return ["salvo"] if "salvo" in candidates else candidates.slice(0, 1)
	if kind == "big-o":
		for first in candidates.size():
			for second in range(first + 1, candidates.size()):
				if (
					ProgramQuiz._work(candidates[first], 32, catalog)
					!= ProgramQuiz._work(candidates[second], 32, catalog)
				):
					return [candidates[first], candidates[second]]
	return candidates.slice(0, 2)


func _quiz_choice(definition: Dictionary, kind: String) -> int:
	for index in (definition.choices as Array).size():
		for effect: Dictionary in definition.choices[index].effects:
			if effect.kind == "quiz" and effect.quiz == kind:
				return index
	return -1


func _finish_issue(state: Dictionary) -> Dictionary:
	for _step in 12:
		if state.status != "issue":
			return state
		var issue: Dictionary = state.issue
		match String(issue.stage):
			"pick":
				var count := (
					1
					if issue.pick.purpose == "keep"
					else mini(int(issue.pick.count), (issue.pick.options as Array).size())
				)
				state = _send(state, {"type": "issue-pick", "card_ids": (issue.pick.options as Array).slice(0, count)})
			"paradigm":
				state = _send(state, {"type": "issue-paradigm", "paradigm_id": String(issue.paradigms[0])})
			"offer":
				state = _send(state, {"type": "issue-take", "card_id": String(issue.offer.cards[0])})
			"focus":
				state = _send(state, {"type": "issue-focus", "focus_id": String(issue.focuses[0])})
			"result":
				return _send(state, {"type": "issue-leave"})
			_:
				_fail("unexpected issue stage %s" % issue.stage)
				return state
	return state


func _send(state: Dictionary, command: Dictionary) -> Dictionary:
	var result := Shardrun.step(state, command, catalog)
	if not result.ok:
		_fail("command %s refused: %s" % [command, result.get("error", "")])
		return state
	return result.state


func _fail(message: String) -> void:
	failed = true
	push_error("QUIZ_FAILED " + message)
