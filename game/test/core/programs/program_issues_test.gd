extends GdUnitTestSuite
## Issues (ProgramIssues, ProgramQuiz): every issue's every choice can be played to its end, and the effects that wait
## (pending, boons, bounties) do what they say.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


func _run_state(layer := 0) -> Dictionary:
	var options := {"seed": "issues", "language": "python", "difficulty": "beginner", "playstyle": "program"}
	var state := Shardrun.start(catalog, options)
	state.erase("draft")
	state.paradigm = "greedy"
	state.focus = "heap"
	state.relics = ["local-optimum", "focus-heap"]
	state.deck = [
		"salvo",
		"salvo",
		"fork",
		"amplify",
		"ward",
		"ward",
		"round-robin",
		"kindle",
		"sweep",
		"take-max",
		"greedy-assign",
		"huffman",
		"top-k",
		"merge-sort",
		"binary-execute",
		"pairwise"
	]
	state.cycles = 500
	state.layer = layer
	return state


func _open(state: Dictionary, id: String) -> Dictionary:
	state.status = "issue"
	state.issue = {"id": id, "stage": "choose", "lines": [], "number": 7}
	return state


func _send(state: Dictionary, command: Dictionary) -> Dictionary:
	var result := Shardrun.step(state, command, catalog)
	assert_bool(result.ok).override_failure_message("%s: %s" % [command, result.get("error", "")]).is_true()
	return result.state if result.ok else state


## Plays an issue's choice to its end the way a patient player would: the first card, the first paradigm, the first
## answer. Returns the state after the issue is left.
func _drive(state: Dictionary, choice: int) -> Dictionary:
	state = _send(state, {"type": "issue-choose", "index": choice})
	for turn in 12:
		if state.status != "issue":
			return state
		var issue: Dictionary = state.issue
		match issue.stage:
			"pick":
				var count := mini(int(issue.pick.count), (issue.pick.options as Array).size())
				if issue.pick.purpose == "keep":
					count = 1
				state = _send(state, {"type": "issue-pick", "card_ids": (issue.pick.options as Array).slice(0, count)})
			"paradigm":
				state = _send(state, {"type": "issue-paradigm", "paradigm_id": issue.paradigms[0]})
			"offer":
				state = _send(state, {"type": "issue-take", "card_id": issue.offer.cards[0]})
			"focus":
				state = _send(state, {"type": "issue-focus", "focus_id": issue.focuses[0]})
			"quiz":
				if not issue.quiz.ready:
					var runs: Array = []
					for version: Dictionary in issue.quiz.plan.get("versions", []):
						runs.append(
							{
								"ok": true,
								"bolts": [{"power": 3 + runs.size(), "element": "none"}],
								"work": 0,
								"trace": []
							}
						)
					var question := ProgramQuiz.build(issue.quiz.plan, runs, state, catalog)
					state = _send(state, {"type": "issue-quiz-ready", "question": question})
				else:
					state = _send(state, {"type": "issue-answer", "index": 0})
			"result":
				return _send(state, {"type": "issue-leave"})
			_:
				fail("stuck in stage %s" % issue.stage)
				return state
	fail("the issue never finished")
	return state


func test_the_content_has_thirty_issues_sixteen_scripts_and_the_new_relics() -> void:
	assert_int((catalog.programs.issues as Dictionary).size()).is_equal(30)
	assert_int((catalog.programs.scripts as Dictionary).size()).is_equal(16)
	for id: String in ["package-lock", "snapshot", "tech-debt", "shell-history", "dotfiles", "big-data"]:
		assert_bool(catalog.relics.has(id)).override_failure_message(id).is_true()


func test_every_choice_of_every_issue_plays_to_its_end() -> void:
	for id: String in catalog.programs.issues:
		var issue: Dictionary = catalog.programs.issues[id]
		for choice in (issue.choices as Array).size():
			var state := _open(_run_state(int(issue.layers[0]) if not (issue.layers as Array).is_empty() else 0), id)
			var done := _drive(state, choice)
			var wanted := "battle" if String(id) == "hackathon" and choice == 0 else "map"
			(
				assert_str(done.status)
				. override_failure_message("%s choice %d ended in %s" % [id, choice, done.status])
				. is_equal(wanted)
			)
			assert_bool(done.has("issue")).is_false()


func test_a_choice_that_costs_cycles_is_refused_when_you_cannot_pay() -> void:
	var state := _open(_run_state(), "merge-conflict")
	state.cycles = 10
	var result := Shardrun.step(state, {"type": "issue-choose", "index": 1}, catalog)
	assert_bool(result.ok).is_false()


func test_the_coffee_machine_heals_a_quarter() -> void:
	var state := _open(_run_state(), "coffee-machine")
	state.integrity = 10
	state = _drive(state, 0)
	assert_int(int(state.integrity)).is_greater(10)


func test_a_pending_gift_pays_out_two_rooms_later() -> void:
	var state := _open(_run_state(), "open-source-maintainer")
	var relics := (state.relics as Array).size()
	state = _drive(state, 0)
	assert_int(int(state.cycles)).is_equal(450)
	assert_int((state.pending as Array).size()).is_equal(1)
	ProgramIssues.tick(state, catalog)
	assert_int((state.relics as Array).size()).is_equal(relics)
	ProgramIssues.tick(state, catalog)
	assert_int((state.relics as Array).size()).is_equal(relics + 1)
	assert_array(state.pending).is_empty()


func test_a_boon_helps_three_fights_and_then_is_gone() -> void:
	var state := _open(_run_state(), "daily-standup")
	state = _drive(state, 0)
	assert_int((state.boons as Array).size()).is_equal(1)
	var battle := {"mana": 3, "block": 0}
	ProgramIssues.on_battle_start(state, battle)
	assert_int(int(battle.mana)).is_equal(4)
	for n in 3:
		ProgramIssues.on_win(state)
	assert_array(state.boons).is_empty()


func test_the_intern_puts_a_fourth_card_in_the_next_rewards() -> void:
	var state := _open(_run_state(), "the-intern")
	state = _drive(state, 0)
	state.layer = 1
	assert_int(ProgramRewards.draft_cards(state, "fight", catalog).size()).is_equal(4)


func test_a_bounty_pays_when_the_fight_is_won_in_one_program() -> void:
	var state := _open(_run_state(), "bug-bounty")
	state = _drive(state, 0)
	assert_int(int(state.bounty.reward)).is_equal(100)
	var battle := {"casts": 1, "foes": [], "kind": "fight", "integrity_start": int(state.integrity)}
	ProgramIssues.on_battle_start(state, battle)
	assert_bool(state.has("bounty")).is_false()
	var receipt := ProgramCycles.settle(state, battle, catalog)
	var pays: Array = receipt.lines.filter(func(line: Dictionary) -> bool: return line.label == "bounty")
	assert_int(pays.size()).is_equal(1)


func test_paradigm_shift_swaps_your_focus_relic() -> void:
	var state := _open(_run_state(1), "paradigm-shift")
	state = _drive(state, 0)
	assert_str(state.focus).is_not_equal("heap")
	assert_array(state.relics).not_contains(["focus-heap"])


func test_a_forum_answer_is_buggy_about_half_the_time_and_the_diff_names_the_line() -> void:
	var buggy := 0
	for n in 60:
		var state := _run_state()
		state.revision = n
		var plan := ProgramQuiz.plan(state, "stack-overflow", catalog)
		var built := ProgramQuiz.build(plan, [], state, catalog)
		if built.buggy:
			buggy += 1
			assert_str(built.diff.before).is_not_equal(built.diff.after)
	assert_int(buggy).is_between(15, 45)


func test_a_big_o_question_has_one_right_answer() -> void:
	var state := _run_state()
	var plan := ProgramQuiz.plan(state, "big-o", catalog)
	var built := ProgramQuiz.build(plan, [], state, catalog)
	assert_int((built.options as Array).size()).is_equal(3)
	assert_int(int(built.answer)).is_between(0, 2)


func test_will_it_halt_uses_the_trace_instead_of_the_numeric_work_total() -> void:
	var state := _run_state()
	var plan := ProgramQuiz.plan(state, "halt", catalog)
	var built := ProgramQuiz.build(
		plan, [{"ok": true, "bolts": [], "work": ProgramRules.budget(state, catalog) + 1, "trace": []}], state, catalog
	)
	assert_str(String(built.explanation)).contains(
		"It did 0 operations against a budget of %d." % ProgramRules.budget(state, catalog)
	)


func test_the_rubber_duck_relic_waives_a_wrong_answers_stake() -> void:
	var state := _open(_run_state(), "big-o-quiz")
	state.relics.append("rubber-duck")
	state = _send(state, {"type": "issue-choose", "index": 0})
	var cycles := int(state.cycles)
	var wrong := 0 if int(state.issue.quiz.answer) != 0 else 1
	state = _send(state, {"type": "issue-answer", "index": wrong})
	assert_int(int(state.cycles)).is_equal(cycles)
