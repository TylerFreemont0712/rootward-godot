class_name TaskCheck
extends RefCounted
## What every task in content must hold (Concept/v0.4/02, section 9), as one helper each task's own test calls:
##
##   assert_array(TaskCheck.problems("volume")).is_empty()
##
## In both languages: the task loads with no content errors; the reference program (test/fixtures/tasks/<id>.py,
## .js) passes every stage; the starter fails stage 1; the Builder's start fails stage 1; each stage's block answer
## (<id>.blocks.json) passes that stage; each stage has three hints; and no hint, goal, starter, glossary example or
## advice holds the reference's longest line (a crude "hints, not answers" check). Every problem is a sentence.

const FIXTURES := "res://test/fixtures/tasks/"


static func problems(id: String) -> Array[String]:
	var found: Array[String] = []
	var loaded := OverworldContent.load_world()
	for diagnostic: Dictionary in loaded.diagnostics:
		if diagnostic.severity == "error" and String(diagnostic.get("file", "")).contains("tasks/%s." % id):
			found.append(ContentLoader.describe(diagnostic))
	var task: Dictionary = loaded.catalog.tasks.get(id, {})
	if task.is_empty():
		found.append("task %s does not load" % id)
		return found
	for language: String in Tasks.LANGUAGES:
		found.append_array(language_problems(task, language))
	found.append_array(answer_problems(task))
	for s in Tasks.stage_count(task):
		if Tasks.hints(task, s).size() < 3:
			found.append("%s stage %d has fewer than three hints" % [id, s + 1])
	return found


static func language_problems(task: Dictionary, language: String) -> Array[String]:
	var found: Array[String] = []
	var id := String(task.id)
	var last := Tasks.stage_count(task) - 1
	var reference := reference_of(id, language)
	if reference == "":
		found.append("%s has no %s reference in %s" % [id, language, FIXTURES])
	else:
		var checked := TaskRun.check(task, last, language, reference)
		if not bool(checked.ok):
			found.append("%s's %s reference fails: %s" % [id, language, _why(task, last, checked, language)])
	var starter := String((task.get("code", {}) as Dictionary).get(language, ""))
	if bool(TaskRun.check(task, 0, language, starter).ok):
		found.append("%s's %s starter already passes stage 1" % [id, language])
	if task.get("blocks") is Dictionary:
		var start := Tasks.source(task, Tasks.fresh_blocks(task), language)
		if bool(TaskRun.check(task, 0, language, start).ok):
			found.append("%s's %s blocks pass stage 1 as they start" % [id, language])
		var answers := block_answers(id)
		if answers.size() != Tasks.stage_count(task):
			found.append("%s.blocks.json has %d answers for %d stages" % [id, answers.size(), Tasks.stage_count(task)])
		for s in mini(answers.size(), Tasks.stage_count(task)):
			var source := Tasks.source(task, answers[s], language)
			var checked := TaskRun.check(task, s, language, source)
			if not bool(checked.ok):
				found.append("%s's %s block answer for stage %d fails: %s\n%s" % [id, language, s + 1, _why(task, s, checked, language), source])
	return found


## No text the player reads holds the reference's longest line (spaces ignored).
static func answer_problems(task: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var id := String(task.id)
	for language: String in Tasks.LANGUAGES:
		var longest := ""
		for line in reference_of(id, language).split("\n"):
			var bare := line.strip_edges()
			# The function's own first line is in every starter; the answer is in its body.
			if bare.begins_with("def ") or bare.begins_with("function "):
				continue
			if bare.length() > longest.length() and not bare in ["}", "};"]:
				longest = bare
		if longest.length() < 8:
			continue
		var squeezed := longest.replace(" ", "")
		for text in readable_texts(task, language):
			if text.replace(" ", "").contains(squeezed):
				found.append('%s shows the %s answer line "%s" in: %s' % [id, language, longest, text.left(80)])
	return found


## Everything of a task the player reads in `language`: goals, hints, advice, the glossary, the starter.
static func readable_texts(task: Dictionary, language: String) -> Array[String]:
	var out: Array[String] = [String((task.get("code", {}) as Dictionary).get(language, ""))]
	for s in Tasks.stage_count(task):
		var stage := Tasks.stage(task, s)
		out.append(String(stage.get("goal", "")))
		out.append_array(Tasks.hints(task, s))
		var glossary := Tasks.glossary(task, s)
		for word: Variant in (glossary.words as Dictionary).get(language, []):
			out.append(String((word as Dictionary).get("example", "")))
		for param: Variant in glossary.params:
			out.append(String((param as Dictionary).get("example", "")))
		if glossary.gives is Dictionary:
			out.append(String((glossary.gives as Dictionary).get("example", "")))
	for said: Variant in (task.get("advice", {}) as Dictionary).values():
		out.append(String(said))
	return out


static func reference_of(id: String, language: String) -> String:
	var path := FIXTURES + id + (".py" if language == Tasks.PYTHON else ".js")
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


static func block_answers(id: String) -> Array:
	var path := FIXTURES + id + ".blocks.json"
	if not FileAccess.file_exists(path):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (data as Dictionary).get("stages", []) if data is Dictionary else []


static func _why(task: Dictionary, stage: int, checked: Dictionary, language: String) -> String:
	var said := Tasks.advice(task, stage, checked, language)
	return "%s %s %s" % [said.reason, said.text, JSON.stringify(said.case)]
