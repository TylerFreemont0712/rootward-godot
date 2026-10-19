class_name LessonResults
extends VBoxContainer
## What a lesson's check found (ADR-0061), one row per case: a mark (a green tick or a red cross), the case, what the
## player's code gave back (a save's dictionary as code, or a lane of little lamps that light up one by one), and the
## verdict in kind words.
##
##   results.wait(LessonWords.waiting(id))            # before the first check
##   results.show_run(id, cases, checked, run, language)

const ROW_FILL := Color(0.07, 0.05, 0.04, 0.55)
const LABEL_WIDTH := 250.0
const VERDICT_WIDTH := 620.0
## The room the list keeps for its heading and three rows, so the code above does not move when a check lands.
const HEIGHT := 134.0

var _heading: Label


func _init() -> void:
	add_theme_constant_override("separation", 4)
	custom_minimum_size.y = HEIGHT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading = Ui.label("", "Muted")
	add_child(_heading)


## Before the first check: one muted line saying what Try it will do.
func wait(text: String) -> void:
	_clear()
	_heading.text = text


func show_run(id: String, given: Array, checked: Dictionary, ran: Dictionary, language: String) -> void:
	_clear()
	_heading.text = Text.t("Tried on three lanes:") if id == Lessons.LAMPS else Text.t("Tried on three players:")
	var problem: Dictionary = checked.get("problem", {})
	if not problem.is_empty():
		var signature := "%s(%s)" % [Lessons.entry(id, language), "lamps" if id == Lessons.LAMPS else "player"]
		add_child(_row(false, Text.t("Your code"), null, LessonWords.problem(problem, signature)))
		return
	var answers: Array = ran.get("results", [])
	var judged: Array = checked.get("cases", [])
	for i in given.size():
		var case_check: Dictionary = judged[i] if i < judged.size() else {}
		var answer: Dictionary = answers[i] if i < answers.size() and answers[i] is Dictionary else {}
		var shows: Control = null
		if bool(answer.get("ok", false)):
			shows = LampStrip.new(answer.get("value")) if id == Lessons.LAMPS else _value(answer.get("value"), language)
		var said := LessonWords.verdict(case_check, language)
		add_child(_row(bool(case_check.get("ok", false)), LessonWords.case_label(id, given[i]), shows, said))


func _clear() -> void:
	for child in get_children():
		if child != _heading:
			remove_child(child)
			child.queue_free()


func _row(ok: bool, label: String, shows: Control, said: String) -> Control:
	var what := Ui.label(label)
	what.add_theme_font_override("font", OverworldStyle.body_font(600))
	what.custom_minimum_size.x = LABEL_WIDTH
	var middle: Control = shows if shows != null else Control.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var verdict := Ui.label(said, "", true)
	verdict.custom_minimum_size.x = VERDICT_WIDTH
	verdict.add_theme_color_override("font_color", UiTheme.PASS if ok else Color("#f08a7e"))
	var line := Ui.hbox([mark(ok), what, middle, verdict], 12)
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", UiTheme.box(ROW_FILL, Color.TRANSPARENT, 0, 8, Vector2(10, 2)))
	holder.add_child(line)
	return holder


## What a save gave back, written as code: {"x": 2, "y": 3} in Python, {x: 2, y: 3} in JavaScript.
static func written(value: Variant, language: String) -> String:
	if not value is Dictionary:
		return Lessons.shown(value)
	var parts: PackedStringArray = []
	var kept: Dictionary = value
	for key in Lessons.kept_fields(kept):
		var shown_key := key if language == Lessons.JAVASCRIPT else '"%s"' % key
		parts.append("%s: %s" % [shown_key, Lessons.shown(kept[key])])
	return "{%s}" % ", ".join(parts)


static func _value(value: Variant, language: String) -> Control:
	var code := Ui.label(written(value, language))
	code.add_theme_font_override("font", UiTheme.code_font())
	code.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_SMALL)
	code.add_theme_color_override("font_color", LessonCode.TEXT_COLOUR)
	code.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	code.clip_text = true
	return code


## A round mark: a green tick for a case that worked, a red cross for one that did not.
static func mark(ok: bool) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(24, 24)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.draw.connect(
		func() -> void:
			var centre := box.size / 2.0
			var radius := minf(box.size.x, box.size.y) / 2.0 - 1.0
			box.draw_circle(centre, radius, UiTheme.PASS if ok else UiTheme.FAIL)
			var ink := Color("#1d140c")
			if ok:
				var tick := PackedVector2Array(
					[centre + Vector2(-6, 0), centre + Vector2(-1, 5), centre + Vector2(6, -5)]
				)
				box.draw_polyline(tick, ink, 3.0, true)
			else:
				box.draw_line(centre + Vector2(-5, -5), centre + Vector2(5, 5), ink, 3.0, true)
				box.draw_line(centre + Vector2(5, -5), centre + Vector2(-5, 5), ink, 3.0, true)
	)
	return box


## A lane after light_all: one little lamp per entry, lit amber with a glow or dark. They light up one after another
## when shown, as the real lane will.
class LampStrip:
	extends Control

	const STEP := 30.0
	const RADIUS := 8.0
	const DARK := Color("#4a4058")

	var _lit: Array[bool] = []
	var _shown := 0.0

	func _init(lamps: Variant) -> void:
		var given: Array = lamps if lamps is Array else []
		for lamp: Variant in given:
			var on: Variant = (lamp as Dictionary).get("lit") if lamp is Dictionary else false
			_lit.append(on is bool and on)
		custom_minimum_size = Vector2(maxf(STEP, _lit.size() * STEP), 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		var tween := create_tween()
		tween.tween_method(_set_shown, 0.0, float(_lit.size()), 0.09 * _lit.size() + 0.01)

	func _set_shown(amount: float) -> void:
		_shown = amount
		queue_redraw()

	func _draw() -> void:
		if _lit.is_empty():
			var y := size.y / 2.0
			draw_dashed_line(Vector2(4, y), Vector2(STEP - 4, y), DARK, 2.0, 6.0)
			return
		for i in _lit.size():
			var centre := Vector2(STEP * i + STEP / 2.0, size.y / 2.0)
			var on := _lit[i] and float(i) < _shown
			if on:
				draw_circle(centre, RADIUS + 4.0, Color(UiTheme.AMBER, 0.25))
				draw_circle(centre, RADIUS, UiTheme.AMBER)
				draw_circle(centre + Vector2(-2, -2), 2.0, Color("#fff1c4"))
			else:
				draw_circle(centre, RADIUS, DARK)
				draw_arc(centre, RADIUS, 0.0, TAU, 24, Color("#2a1d2b"), 2.0, true)
