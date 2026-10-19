class_name TaskResults
extends VBoxContainer
## What a task's check found (Concept/v0.4, the editor), one row per case of the open stage and those before it:
##
##   ✓  shortcut("escape")   →  "menu"    pressing Esc
##   ✗  shortcut("i")        →  None      pressing I
##   Still works:
##   ✓  ...
##
## A mark (a green tick or a red cross, drawn as LessonResults draws them), the call as code, an arrow and the answer
## the function gave back (or the error), and the case's own words in small muted text. The cases of earlier stages sit
## together under a small "Still works:" heading. A problem with the whole run (the code cannot load, it ran too long)
## is one row with its line.
##
##   results.wait(task, stage, "python")                  # before the first check: the cases, not yet marked
##   results.show_run(task, stage, "python", checked)     # checked: Tasks.check's result with `results` (TaskEditor.run_check)

const ROW_FILL := Color(0.07, 0.05, 0.04, 0.55)
const CALL_WIDTH := 430.0
const ANSWER_WIDTH := 330.0
const BAD := Color("#f08a7e")

var _heading: Label


func _init() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading = Ui.label("", "Muted")
	add_child(_heading)


## Before the first check: one muted line, then the calls the check will make, each with an empty ring.
func wait(task: Dictionary, stage: int, language: String) -> void:
	_clear()
	_heading.text = TaskWords.waiting()
	for case_data: Dictionary in Tasks.check_cases(task, stage):
		if int(case_data.stage) == stage:
			add_child(_row(_ring(), _call(task, case_data, language), "", LessonCode.TEXT_COLOUR, Text.t(String(case_data.get("say", ""))), 1.0))


## The rows of a check. `checked` is Tasks.check's result, with `results` (the harness's answers, one per case) beside it.
func show_run(task: Dictionary, stage: int, language: String, checked: Dictionary) -> void:
	_clear()
	_heading.text = ""
	var problem: Dictionary = checked.get("problem", {})
	if not problem.is_empty():
		_heading.text = Text.t("Tried your code:")
		var line := int(problem.get("line", 0))
		# The sandbox's own message ends with where it was ("(task.py, line 2)"); the line is said first instead.
		var said := RegEx.create_from_string("\\s*\\(task\\.(py|js)[^)]*\\)").sub(String(problem.get("message", "")), "", true)
		if line > 0:
			said = Text.f("Line %d: %s", [line, said]) if said != "" else Text.f("Line %d", [line])
		var label := Ui.label(Text.f("Your code: %s", [said]) if said != "" else Text.t("Your code"))
		label.add_theme_color_override("font_color", BAD)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(_row(LessonResults.mark(false), label, "", BAD, "", 1.0))
		return
	var cases := Tasks.check_cases(task, stage)
	var verdicts: Array = checked.get("cases", [])
	var answers: Array = checked.get("results", [])
	_heading.text = Text.t("Tried your function:")
	var earlier: Array[Control] = []
	var earlier_ok := true
	for i in cases.size():
		var case_data: Dictionary = cases[i]
		var verdict: Dictionary = verdicts[i] if i < verdicts.size() and verdicts[i] is Dictionary else {}
		var answer: Dictionary = answers[i] if i < answers.size() and answers[i] is Dictionary else {}
		var ok := bool(verdict.get("ok", false))
		var said := _answer(verdict, answer, language)
		var now := int(case_data.stage) == stage
		var row := _row(
			LessonResults.mark(ok),
			_call(task, case_data, language),
			said,
			LessonCode.TEXT_COLOUR if ok else BAD,
			Text.t(String(case_data.get("say", ""))),
			1.0 if now else 0.8,
		)
		if now:
			add_child(row)
		else:
			earlier.append(row)
			earlier_ok = earlier_ok and ok
	if not earlier.is_empty():
		var heading := Ui.label(TaskWords.still_works(earlier_ok), "Muted")
		heading.add_theme_color_override("font_color", UiTheme.PASS if earlier_ok else BAD)
		add_child(heading)
		for row in earlier:
			add_child(row)


## What the function gave back for a case, as code shows it, or the error it raised.
static func _answer(verdict: Dictionary, answer: Dictionary, language: String) -> String:
	if answer.has("ok") and not bool(answer.ok):
		return _error(answer)
	if String(verdict.get("reason", "")) in ["error", Tasks.NO_FUNCTION]:
		return _error(verdict)
	if answer.has("value"):
		return Tasks.shown(answer.value, language)
	if verdict.has("got"):
		return Tasks.shown(verdict.got, language)
	return ""


static func _error(failed: Dictionary) -> String:
	var kind := String(failed.get("kind", ""))
	var message := String(failed.get("message", ""))
	var line := int(failed.get("line", 0))
	var said := message if kind in ["", "missing"] else "%s: %s" % [kind, message]
	return Text.f("%s (line %d)", [said, line]) if line > 0 else said


## `shortcut("escape")`: the function's name and the case's arguments as code writes them.
static func call_text(task: Dictionary, case_data: Dictionary, language: String) -> String:
	var parts := PackedStringArray()
	for arg: Variant in case_data.get("args", []):
		parts.append(Tasks.shown(arg, language))
	return "%s(%s)" % [Tasks.entry(task, int(case_data.get("stage", 0)), language), ", ".join(parts)]


static func _call(task: Dictionary, case_data: Dictionary, language: String) -> Label:
	var code := _code(call_text(task, case_data, language), LessonCode.TEXT_COLOUR)
	code.custom_minimum_size.x = CALL_WIDTH
	return code


static func _code(text: String, colour: Color) -> Label:
	var label := Ui.label(text)
	label.add_theme_font_override("font", UiTheme.code_font())
	label.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_SMALL + 1)
	label.add_theme_color_override("font_color", colour)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## One row: the mark, the call, an arrow and the answer, the case's words.
func _row(mark: Control, call: Control, answer: String, colour: Color, said: String, fade: float, said_colour := OverworldStyle.MUTED) -> Control:
	var parts: Array = [mark, call]
	if answer != "":
		var arrow := Ui.label("→", "Muted")
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var shown := _code(answer, colour)
		shown.custom_minimum_size.x = ANSWER_WIDTH
		shown.tooltip_text = answer
		parts.append_array([arrow, shown])
	else:
		parts.append(Ui.spacer(ANSWER_WIDTH + 36.0, 0))
	var words := Ui.label(said, "Muted")
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.clip_text = true
	words.add_theme_color_override("font_color", said_colour)
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.tooltip_text = said
	parts.append(words)
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", UiTheme.box(ROW_FILL, Color.TRANSPARENT, 0, 8, Vector2(10, 2)))
	holder.add_child(Ui.hbox(parts, 12))
	holder.modulate.a = fade
	return holder


## An empty ring: a case that has not been tried yet.
static func _ring() -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(24, 24)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.draw.connect(
		func() -> void:
			var radius := minf(box.size.x, box.size.y) / 2.0 - 2.0
			box.draw_arc(box.size / 2.0, radius, 0.0, TAU, 28, UiTheme.AMBER_DIM, 2.0, true)
	)
	return box


func _clear() -> void:
	for child in get_children():
		if child != _heading:
			remove_child(child)
			child.queue_free()
