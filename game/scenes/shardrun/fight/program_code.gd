class_name ProgramCode
extends PanelContainer
## The fight's Program, always on the table (ADR-0012): the code its played cards make, written in with runes as each
## card lands (RuneCode); the race between its work and each foe's tempo; and what it will do. During a cast it runs:
## the line being run lights up and each call shows the n it handled and the work it did.

## Seconds a line holds the light during a cast, by the code speed option.
const PACE := {"slow": 0.62, "normal": 0.34, "fast": 0.14}

var session: ShardrunSession
var colour := UiTheme.SHARD
var _code: RuneCode
var _scroll: ScrollContainer
var _title: Label
var _speed: Label
var _ops: Label
var _race: RaceBar
var _footer: Label
var _lines: Array[Dictionary] = []
var _hurry := false
var _drawn := false


static func create(run_session: ShardrunSession) -> ProgramCode:
	var panel := ProgramCode.new()
	panel.session = run_session
	panel._build()
	return panel


func _build() -> void:
	var paradigm := ProgramDraft.paradigm_of(session.catalog, String(session.state.get("paradigm", "")))
	colour = Color(paradigm.get("colour", UiTheme.SHARD.to_html()))
	# A plain frame: the paradigm's colour is in the header above, and in the runes the code is written with.
	add_theme_stylebox_override("panel", UiTheme.box(Color("#110d12"), UiTheme.LINE, 2, 10, Vector2(12, 10)))
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size.x = 780
	var file: String = (session.state.spells as Array)[0].name
	_title = Ui.tint(Ui.label(file, "Subheading"), UiTheme.TEXT) as Label
	var school := Ui.label("", "Faint")
	_speed = Ui.tint(Ui.label("", "Subheading"), colour.lightened(0.25)) as Label
	_ops = Ui.label("", "Muted")
	_race = RaceBar.new()
	_race.colour = colour
	_race.custom_minimum_size.y = 46
	_code = RuneCode.new()
	_code.language = session.state.language
	_code.glow = colour
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll = Ui.scroll(_code)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = 120
	_footer = Ui.label("", "Muted", true)
	_footer.add_theme_font_size_override("font_size", 13)
	var header := Ui.hbox([_title, school, Ui.spacer(), _speed, _ops], 10)
	add_child(Ui.vbox([header, _race, _scroll, _footer], 6))


## Draws the Program as it stands: its code (new lines written in), the race, and the preview when it has one.
func show_program(state: Dictionary, view: Dictionary) -> void:
	var spell: Dictionary = (state.spells as Array)[0]
	var cards: Array = spell.shards
	var fresh := view if _for(view, cards) else {}
	_lines = ProgramViews.code_lines(state.language, cards, fresh, session.catalog)
	# The code already there when the fight is drawn is simply there; only what is played from now on is written in.
	var first := _code.show_lines(_lines, _drawn)
	_drawn = true
	if first >= 0:
		_reveal(first)
		Sound.play("sfx-charge", 0.35, 1.5)
	var work := int(fresh.get("work", 0))
	_speed.text = ProgramRules.speed_label(cards, session.catalog)
	var budget := ProgramRules.budget(session.catalog)
	_ops.text = "%d / %d ops" % [work, budget] if not fresh.is_empty() else "… ops"
	_ops.add_theme_color_override("font_color", UiTheme.FAIL if work > budget else UiTheme.MUTED)
	_race.show_race(
		fresh.get("race", ProgramViews.race(state, work, session.catalog)), work, budget, not fresh.is_empty()
	)
	_footer.text = _summary(fresh, cards)
	_footer.add_theme_color_override("font_color", _summary_colour(fresh))


## A view belongs to these cards when its steps are theirs (a view from before the last card was played does not).
static func _for(view: Dictionary, cards: Array) -> bool:
	if view.is_empty() or not view.get("program", false):
		return false
	if view.has("misfire"):
		return true
	var steps: Array = view.get("steps", [])
	if steps.size() != cards.size():
		return false
	for index in steps.size():
		if steps[index].shard != cards[index]:
			return false
	return true


func _summary(view: Dictionary, cards: Array) -> String:
	if cards.is_empty():
		return "An empty program still casts its seed: one 3-power bolt at the front foe. Play cards to write more."
	if view.is_empty():
		return "Running it in the sandbox…"
	if view.has("misfire"):
		return "It crashes: %s" % view.misfire.reason
	if view.timeout:
		return "Time limit: %d ops is over the budget of %d. Nothing would land." % [int(view.work), int(view.budget)]
	var parts: Array[String] = []
	for warning: Dictionary in view.get("lint", []):
		parts.append("⚠ " + String(warning.message))
	var first: Array = (view.get("race", []) as Array).filter(func(entry: Dictionary) -> bool: return entry.first)
	if not first.is_empty():
		var names := ", ".join(first.map(func(entry: Dictionary) -> String: return entry.name))
		parts.append("⚡ %s %s before it lands." % [names, "acts" if first.size() == 1 else "act"])
	if view.has("result"):
		var result: Dictionary = view.result
		var outcome := "→ %d bolts · %d damage" % [int(result.bolts), int(result.damage)]
		if int(result.block) > 0:
			outcome += " · %d block" % int(result.block)
		if int(result.wasted) > 0:
			outcome += " · %d wasted" % int(result.wasted)
		parts.append(outcome)
	return "\n".join(parts)


func _summary_colour(view: Dictionary) -> Color:
	if view.has("misfire") or view.get("timeout", false):
		return UiTheme.FAIL
	if not (view.get("lint", []) as Array).is_empty():
		return UiTheme.WARN
	return UiTheme.MUTED


## Scrolls so the new line and some of what follows it are in view.
func _reveal(index: int) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_instance_valid(_scroll):
		return
	var top := _code.line_top(index)
	var bottom := top + _code.line_height() * 6.0
	var view_height := _scroll.size.y
	if top < _scroll.scroll_vertical or bottom > _scroll.scroll_vertical + view_height:
		var tween := create_tween()
		tween.tween_property(_scroll, "scroll_vertical", int(maxf(0.0, top - _code.line_height() * 2.0)), 0.35)


## Runs the Program on screen: the seed, then each call lit in turn with the n it handled and the work it did, then
## the return. `view` is the cast's run view (ProgramViews.run_view).
func play_cast(view: Dictionary, speed: String) -> void:
	_hurry = false
	if speed == "off" or not PACE.has(speed):
		return
	var pace: float = PACE[speed]
	var steps: Array = view.get("steps", [])
	for index in _lines.size():
		var line: Dictionary = _lines[index]
		if not line.kind in ["seed", "call", "return"]:
			continue
		_code.set_cursor(index)
		_reveal(index)
		if line.kind == "call" and int(line.slot) < steps.size():
			var step: Dictionary = steps[int(line.slot)]
			var note := "n %d → %d ops · %d bolts" % [int(step.n), int(step.work), (step.bolts as Array).size()]
			_code.set_note(index, note, colour.lightened(0.35))
			Sound.play("sfx-card", 0.35, 1.2 + 0.05 * int(line.slot))
		await _wait(pace * (1.6 if line.kind == "call" else 1.0))
	_code.set_cursor(-1)


func skip() -> void:
	_hurry = true


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _hurry and is_inside_tree():
		await get_tree().process_frame
		left -= get_process_delta_time()


## The race, drawn: a track from 1 to the budget on a log scale, each foe's tempo on it, and the program's work. Foes
## left of the program act before it lands.
class RaceBar:
	extends Control

	var colour := UiTheme.SHARD
	var _race: Array = []
	var _work := 0
	var _budget := 4096
	var _known := false

	func show_race(race: Array, work: int, budget: int, known: bool) -> void:
		_race = race
		_work = work
		_budget = budget
		_known = known
		queue_redraw()

	func _x(value: int) -> float:
		var span := log(float(_budget) + 1.0)
		return 10.0 + (size.x - 20.0) * clampf(log(float(maxi(0, value)) + 1.0) / span, 0.0, 1.0)

	func _draw() -> void:
		var font := UiTheme.ui_font()
		var y := size.y * 0.62
		draw_line(Vector2(10, y), Vector2(size.x - 10, y), Color(UiTheme.LINE, 1.0), 2.0)
		for mark: int in [1, 10, 100, 1000]:
			draw_line(Vector2(_x(mark), y - 3), Vector2(_x(mark), y + 3), UiTheme.LINE, 1.0)
		var limit := _x(_budget)
		draw_line(Vector2(limit, y - 10), Vector2(limit, y + 8), UiTheme.FAIL, 2.0)
		draw_string(
			font, Vector2(limit - 80, size.y - 1), "time limit", HORIZONTAL_ALIGNMENT_RIGHT, 76, 11, UiTheme.FAIL
		)
		if _known:
			var you := _x(_work)
			draw_rect(Rect2(10, y - 2, you - 10, 4), Color(colour, 0.55))
		var above := true
		for entry: Dictionary in _race:
			var x := _x(int(entry.tempo))
			var tint := UiTheme.FAIL.lightened(0.15) if entry.first else UiTheme.MUTED
			draw_colored_polygon(
				PackedVector2Array([Vector2(x, y - 2), Vector2(x - 5, y - 11), Vector2(x + 5, y - 11)]), tint
			)
			var text := "%s %d" % [String(entry.name).get_slice(" ", 0), int(entry.tempo)]
			draw_string(
				font, Vector2(x - 60, y - 14 if above else size.y - 1), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, tint
			)
			above = not above
		if _known:
			var you := _x(_work)
			var diamond := PackedVector2Array(
				[Vector2(you, y - 7), Vector2(you + 7, y), Vector2(you, y + 7), Vector2(you - 7, y)]
			)
			draw_circle(Vector2(you, y), 11.0, Color(colour, 0.25))
			draw_colored_polygon(diamond, colour.lightened(0.3))
			draw_string(
				font,
				Vector2(you - 60, size.y - 1),
				"you %d" % _work,
				HORIZONTAL_ALIGNMENT_CENTER,
				120,
				11,
				colour.lightened(0.4)
			)
