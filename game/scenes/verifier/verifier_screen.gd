extends Control
## A course instead of a combat run: inspect executable code, trace one state, predict the exact console output.

var _index := 0
var _chosen := ""
var _revealed := 0
var _attempts: Dictionary = {}
var _pending: Thread
var _main: VBoxContainer
var _rail: VBoxContainer
var _work: VBoxContainer
var _answer: LineEdit
var _submit: Button
var _feedback: VBoxContainer
var _trace: VBoxContainer
var _board: TraceBoard
var _choices: Dictionary = {}
var _submitted_choice := ""
var _submitted_output := ""
var _submitted_revealed := 0


func _ready() -> void:
	theme = UiTheme.shared()
	var error := VerifierCourse.load_course()
	var background := ColorRect.new()
	background.color = UiTheme.GROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	_main = Ui.vbox([], 18)
	margin.add_child(_main)
	if error != "":
		_main.add_child(Ui.label(error, "Heading"))
		_main.add_child(Ui.button("Return to title", func() -> void: Game.go(Game.TITLE)))
		return
	_index = VerifierCourse.lessons.size() - 1
	for i in VerifierCourse.lessons.size():
		if VerifierCourse.unlocked(i) and VerifierCourse.stars(i) == 0:
			_index = i
			break
	_build()
	Sound.music("music-title")


func _exit_tree() -> void:
	if _pending != null:
		_pending.wait_to_finish()


func _process(_delta: float) -> void:
	if _pending == null or _pending.is_alive():
		return
	var result: SandboxResult = _pending.wait_to_finish()
	_pending = null
	_grade(result)


func _build() -> void:
	Ui.clear(_main)
	var lesson: Dictionary = VerifierCourse.lessons[_index]
	var earned := 0
	for i in VerifierCourse.lessons.size():
		earned += VerifierCourse.stars(i)
	var header := Ui.hbox(
		[
			Ui.button("← Title", func() -> void: Game.go(Game.TITLE)),
			Ui.tint(Ui.label("VERIFIER  /  CODE LAB", "Heading"), UiTheme.TEAL),
			Ui.spacer(),
			Ui.label("%d / %d STARS" % [earned, VerifierCourse.lessons.size() * 3], "Subheading")
		],
		16
	)
	_main.add_child(header)
	_main.add_child(
		Ui.label(
			"Trace real programs. Commit an exact output. Unlock the next lesson with a correct prediction.", "Muted"
		)
	)
	var body := Ui.hbox([], 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main.add_child(body)
	_rail = Ui.vbox([], 8)
	var rail_scroll := Ui.scroll(_rail)
	rail_scroll.custom_minimum_size.x = 300
	rail_scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(Ui.panel(rail_scroll, "Card"))
	_build_rail()
	_work = Ui.vbox([], 14)
	_work.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_work)
	_build_lesson(lesson)


func _build_rail() -> void:
	Ui.clear(_rail)
	_rail.add_child(Ui.label("COURSE MAP", "Subheading"))
	var chapter := ""
	for i in VerifierCourse.lessons.size():
		var lesson: Dictionary = VerifierCourse.lessons[i]
		if lesson.chapter != chapter:
			chapter = lesson.chapter
			_rail.add_child(Ui.tint(Ui.label(chapter, "Faint"), UiTheme.TEAL))
		var stars := VerifierCourse.stars(i)
		var label := "%02d  %s" % [i + 1, lesson.title]
		if stars > 0:
			label += "  " + "★".repeat(stars)
		var button := Ui.button(label, _select.bind(i), "PrimaryButton" if i == _index else "")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not VerifierCourse.unlocked(i)
		_rail.add_child(button)


func _select(index: int) -> void:
	if _pending != null or not VerifierCourse.unlocked(index):
		return
	_index = index
	_chosen = ""
	_revealed = 0
	_build()


func _build_lesson(lesson: Dictionary) -> void:
	var intro := Ui.vbox(
		[
			Ui.tint(Ui.label(lesson.chapter + "  /  " + lesson.concept.to_upper(), "Faint"), UiTheme.TEAL),
			Ui.label(lesson.title, "Heading"),
			Ui.label(lesson.brief, "Muted", true)
		],
		5
	)
	_work.add_child(Ui.panel(intro, "Card"))
	var columns := Ui.hbox([], 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_work.add_child(columns)
	var source_column := Ui.vbox([Ui.tint(Ui.label("SOURCE  /  lesson.js", "Faint"), UiTheme.TEAL)], 8)
	source_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var source := RichTextLabel.new()
	source.bbcode_enabled = true
	source.selection_enabled = true
	source.custom_minimum_size.y = 440
	source.add_theme_font_override("normal_font", UiTheme.ui_font())
	source.add_theme_font_size_override("normal_font_size", 20)
	source.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL, UiTheme.LINE, 1, 8, Vector2(20, 20)))
	var numbered := ""
	for i: int in lesson.code.size():
		var line: String = lesson.code[i]
		numbered += "[color=#6f5e46]%02d[/color]  %s\n" % [i + 1, line.replace("[", "[lb]")]
	source.text = numbered
	source_column.add_child(source)
	_board = TraceBoard.new()
	_board.stages = lesson.model
	_board.tokens = lesson.tokens
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.step_requested.connect(_step)
	source_column.add_child(_board)
	columns.add_child(source_column)
	var right := Ui.vbox([], 12)
	var right_scroll := Ui.scroll(right)
	right_scroll.custom_minimum_size.x = 390
	right_scroll.size_flags_horizontal = Control.SIZE_SHRINK_END
	columns.add_child(right_scroll)
	var probe: Dictionary = lesson.probe
	var probe_column := Ui.vbox(
		[
			Ui.tint(Ui.label("01  /  TRACE THE STATE", "Faint"), UiTheme.TEAL),
			Ui.label(probe.question, "Subheading", true)
		],
		9
	)
	_choices = {}
	for choice: String in probe.choices:
		var button := Ui.choice(choice, false, _pick.bind(choice))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		probe_column.add_child(button)
		_choices[choice] = button
	right.add_child(Ui.panel(probe_column, "Card"))
	_trace = Ui.vbox([Ui.tint(Ui.label("TRACE TAPE  /  optional clues", "Faint"), UiTheme.AMBER)], 5)
	var reveal := Ui.button("Step through →", _step)
	_trace.add_child(reveal)
	right.add_child(Ui.panel(_trace, "Sunken"))
	var output := Ui.vbox(
		[
			Ui.tint(Ui.label("02  /  PREDICT STDOUT", "Faint"), UiTheme.TEAL),
			Ui.label("What exactly does console.log print?", "Muted", true)
		],
		8
	)
	_answer = LineEdit.new()
	_answer.placeholder_text = "Type the exact output"
	_answer.text_submitted.connect(func(_text: String) -> void: _submit_answer())
	output.add_child(_answer)
	_submit = Ui.button("Commit prediction", _submit_answer, "PrimaryButton")
	output.add_child(_submit)
	right.add_child(Ui.panel(output, "Card"))
	_feedback = Ui.vbox([], 8)
	right.add_child(_feedback)
	_answer.grab_focus.call_deferred()


func _pick(choice: String) -> void:
	if _pending != null:
		return
	_chosen = choice
	for key: String in _choices:
		(_choices[key] as Button).set_pressed_no_signal(key == choice)


func _step() -> void:
	if _pending != null or _board.complete:
		return
	var steps: Array = VerifierCourse.lessons[_index].steps
	if _revealed >= steps.size():
		return
	_revealed += 1
	_board.phase = mini(_revealed, _board.stages.size() - 1)
	_trace.add_child(Ui.label("%02d  %s" % [_revealed, steps[_revealed - 1]], "Muted", true))
	if _revealed == steps.size():
		(_trace.get_child(1) as Button).disabled = true
	Sound.play("sfx-glyph", 0.35)


func _submit_answer() -> void:
	if _pending != null or _chosen == "" or _answer.text.strip_edges() == "":
		Ui.clear(_feedback)
		_feedback.add_child(
			Ui.tint(Ui.label("Choose a trace value and type an output first.", "Muted", true), UiTheme.WARN)
		)
		return
	if not Sandbox.is_available(SandboxJob.JAVASCRIPT):
		Ui.clear(_feedback)
		_feedback.add_child(
			Ui.tint(
				Ui.label("JavaScript sandbox unavailable. Install it to run the lesson.", "Muted", true), UiTheme.FAIL
			)
		)
		return
	_submit.disabled = true
	_submit.text = "Running lesson…"
	_answer.editable = false
	_submitted_choice = _chosen
	_submitted_output = _answer.text
	_submitted_revealed = _revealed
	for button: Button in _choices.values():
		button.disabled = true
	var lesson: Dictionary = VerifierCourse.lessons[_index]
	_pending = Thread.new()
	_pending.start(VerifierCourse.execute.bind(lesson))


func _grade(result: SandboxResult) -> void:
	Ui.clear(_feedback)
	_submit.disabled = false
	_submit.text = "Commit prediction"
	_answer.editable = true
	for button: Button in _choices.values():
		button.disabled = false
	if not result.is_ok():
		_feedback.add_child(Ui.tint(Ui.label("Sandbox: " + result.message, "Muted", true), UiTheme.FAIL))
		return
	_board.complete = true
	_board.phase = _board.stages.size() - 1
	var lesson: Dictionary = VerifierCourse.lessons[_index]
	var actual := VerifierCourse.normalize_output(result.stdout)
	var predicted := VerifierCourse.normalize_output(_submitted_output)
	var output_right := predicted == actual
	var trace_right: bool = _submitted_choice == lesson.probe.answer
	var attempts := int(_attempts.get(lesson.id, 0))
	_attempts[lesson.id] = attempts + 1
	var stars := 0
	if output_right:
		stars = (
			3
			if trace_right and _submitted_revealed == 0 and attempts == 0
			else (2 if trace_right and attempts == 0 else 1)
		)
		VerifierCourse.record(_index, stars)
	var headline := "PROVEN  /  %s" % "★".repeat(stars) if output_right else "TRACE MISMATCH"
	_feedback.add_child(Ui.tint(Ui.label(headline, "Subheading"), UiTheme.PASS if output_right else UiTheme.FAIL))
	_feedback.add_child(Ui.label("Actual stdout: %s" % actual, "Code", true))
	_feedback.add_child(Ui.label("Checkpoint: %s" % lesson.probe.answer, "Muted", true))
	_feedback.add_child(Ui.label(lesson.explanation, "Muted", true))
	if output_right:
		var next := _index + 1
		if next < VerifierCourse.lessons.size():
			_feedback.add_child(Ui.button("Next lesson →", _select.bind(next), "PrimaryButton"))
		else:
			_feedback.add_child(
				Ui.tint(
					Ui.label("COURSE COMPLETE  /  replay lessons to improve your stars.", "Muted", true), UiTheme.TEAL
				)
			)
		_build_rail()
	else:
		_feedback.add_child(Ui.button("Try another prediction", func() -> void: _answer.grab_focus()))
