class_name ProgramCode
extends PanelContainer

signal card_resolved(card_id: String)
## The fight's Program, always on the table (ADR-0012): the code its played cards make, written in with runes as each
## card lands (RuneCode); the race between its work and each foe's tempo; and what it will do.
##
## During a cast it runs, and draws the eye while it does: the panel lights up, each call steps into its card's
## function, loops go round (their rounds counted up to what the sandbox measured), recursion shows its calls, and every
## result lands like a hit, harder for bigger numbers. The ops counter and the race climb as each stage finishes.

## Seconds a call line holds the light during a cast, by the code speed option, and a line inside a card's function.
const PACE := {"slow": 0.62, "normal": 0.34, "fast": 0.14}
const STEP := {"slow": 0.16, "normal": 0.07, "fast": 0.03}
## About how long one card's function may take to walk, by the code speed option: a long function walks faster.
const BUDGET := {"slow": 3.0, "normal": 1.2, "fast": 0.5}

var session: ShardrunSession
var colour := UiTheme.SHARD
var _code: RuneCode
var _scroll: ScrollContainer
var _title: Label
var _speed: Label
var _ops: Label
var _race: RaceBar
var _meter: VolleyMeter
var _footer: Label
var _lines: Array[Dictionary] = []
var _hurry := false
var _drawn := false
var _look: StyleBoxFlat
## The ops shown in the header while a cast counts them up, and the foes already passed.
var _counted := 0
var _passed: Dictionary = {}


static func create(run_session: ShardrunSession) -> ProgramCode:
	var panel := ProgramCode.new()
	panel.session = run_session
	panel._build()
	return panel


func _build() -> void:
	var paradigm := ProgramDraft.paradigm_of(session.catalog, String(session.state.get("paradigm", "")))
	colour = Color(paradigm.get("colour", UiTheme.SHARD.to_html()))
	# A plain frame: the paradigm's colour is in the header above, and in the runes the code is written with.
	_look = UiTheme.box(Color("#110d12"), UiTheme.LINE, 2, 10, Vector2(12, 10))
	add_theme_stylebox_override("panel", _look)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size.x = 780
	var file: String = (session.state.spells as Array)[0].name
	_title = Ui.tint(Ui.label(file, "Subheading"), UiTheme.TEXT) as Label
	var school := Ui.label("", "Faint")
	_speed = Ui.tint(Ui.label("", "Subheading"), colour.lightened(0.25)) as Label
	_ops = Ui.label("", "Muted")
	_meter = VolleyMeter.new()
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
	add_child(Ui.vbox([header, _meter, _race, _scroll, _footer], 6))


## Draws the Program as it stands: its code (new lines written in), the race, and the preview when it has one.
func show_program(state: Dictionary, view: Dictionary) -> void:
	var spell: Dictionary = (state.spells as Array)[0]
	var cards: Array = spell.shards
	var fresh := view if _for(view, cards) else {}
	_lines = ProgramViews.code_lines(state, cards, fresh, session.catalog)
	# The code already there when the fight is drawn is simply there; only what is played from now on is written in.
	var first := _code.show_lines(_lines, _drawn)
	_drawn = true
	if first >= 0:
		_reveal(first)
		Sound.play("sfx-glyph", 0.5)
	var work := int(fresh.get("work", 0))
	_show_final_volley(fresh)
	_speed.text = ProgramRules.speed_label(cards, session.catalog)
	var budget := ProgramRules.budget(session.state, session.catalog)
	_ops.text = "%d / %d ops" % [work, budget] if not fresh.is_empty() else "… ops"
	_ops.add_theme_color_override("font_color", UiTheme.FAIL if work > budget else UiTheme.MUTED)
	_race.show_race(
		fresh.get("race", ProgramViews.race(state, work, session.catalog)), work, budget, not fresh.is_empty()
	)
	_footer.text = _summary(fresh, cards)
	_footer.add_theme_color_override("font_color", _summary_colour(fresh))


## The volley the Program will make, as the preview measured it: its last stage's, or the seed's with no cards.
func _show_final_volley(view: Dictionary) -> void:
	var steps: Array = view.get("steps", [])
	if not steps.is_empty():
		var last: Dictionary = steps.back()
		_meter.show_volley(int(last.returned), float(last.get("power", 0.0)), last.get("elements", {}))
		return
	var seed: Array = (view.get("base", {}) as Dictionary).get(
		"bolts", ProgramRules.seed(session.state, session.catalog)
	)
	_meter.show_volley(seed.size(), _power_of(seed), _elements_of(seed))


static func _power_of(bolts: Array) -> float:
	var total := 0.0
	for bolt: Dictionary in bolts:
		total += float(bolt.get("power", 0))
	return total


static func _elements_of(bolts: Array) -> Dictionary:
	var found := {}
	for bolt: Dictionary in bolts:
		var element: String = bolt.get("element", "none")
		found[element] = int(found.get(element, 0)) + 1
	return found


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
		var seed := ProgramRules.seed(session.state, session.catalog)
		var noun := "bolt" if seed.size() == 1 else "bolts"
		var total := int(_power_of(seed))
		return (
			"An empty program still casts its seed: %d %s (%d power) at the front foe. Play cards to write more."
			% [seed.size(), noun, total]
		)
	if view.is_empty():
		return "Running it in the sandbox…"
	if view.has("misfire"):
		return "It crashes: %s" % view.misfire.reason
	if view.timeout:
		return "Time limit: %d ops is over the budget of %d. Nothing would land." % [int(view.work), int(view.budget)]
	var parts: Array[String] = []
	for warning: Dictionary in view.get("lint", []):
		parts.append("⚠ " + String(warning.message))
	var race: Array = view.get("race", [])
	var first := race.filter(func(entry: Dictionary) -> bool: return entry.first)
	if not first.is_empty():
		parts.append("⚡ %s %s before it lands." % [_names(first), "acts" if first.size() == 1 else "act"])
	if int(view.get("locked", 0)) > 0:
		var noun := "bolt" if int(view.locked) == 1 else "bolts"
		parts.append("⚠ %d %s held by a lock: hit both halves of a deadlock in one program." % [int(view.locked), noun])
	if int(view.get("fixed", 0)) > 0:
		var noun := "bolt does" if int(view.fixed) == 1 else "bolts do"
		parts.append(
			"⚠ The same program as last time: a Quine recognises it, and %d %s nothing." % [int(view.fixed), noun]
		)
	for echo: Dictionary in view.get("reprints", []):
		var hits := int(echo.hits)
		parts.append("⎘ %s will reprint %d bolts: %d damage." % [echo.name, hits, hits * int(echo.power)])
	var caught := race.filter(func(entry: Dictionary) -> bool: return not entry.first)
	var bonus := roundi((ProgramRules.initiative(session.state, session.catalog) - 1.0) * 100.0)
	if not caught.is_empty() and bonus > 0:
		var verb := "moves" if caught.size() == 1 else "move"
		parts.append("» Initiative: it lands before %s %s, +%d%% damage." % [_names(caught), verb, bonus])
	if view.has("result"):
		var result: Dictionary = view.result
		var noun := "bolt" if int(result.bolts) == 1 else "bolts"
		var outcome := "→ %d %s · %d damage" % [int(result.bolts), noun, int(result.damage)]
		if int(result.block) > 0:
			outcome += " · %d block" % int(result.block)
		if int(result.wasted) > 0:
			outcome += " · %d wasted" % int(result.wasted)
		parts.append(outcome)
	return "\n".join(parts)


## Race entries' names as a list: "A", "A and B", "A, B and C".
static func _names(entries: Array) -> String:
	var names: PackedStringArray = entries.map(func(entry: Dictionary) -> String: return entry.name)
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


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
	var line_time: float = STEP[speed]
	var steps: Array = view.get("steps", [])
	var race: Array = view.get("race", [])
	var budget := int(view.get("budget", ProgramRules.budget(session.state, session.catalog)))
	var seeds: Array = (view.get("base", {}) as Dictionary).get("bolts", [])
	_meter.show_volley(seeds.size(), _power_of(seeds), _elements_of(seeds))
	var tint := VolleyMeter.colour_of(_elements_of(seeds))
	_running(true, tint)
	_passed = {}
	_counted = 0
	_count_ops(0, budget, race)
	var ops := 0
	var walked := {}
	for index in _lines.size():
		var line: Dictionary = _lines[index]
		match String(line.kind):
			"seed":
				_focus(index)
				_code.set_note(
					index, "%d bolt%s" % [seeds.size(), "" if seeds.size() == 1 else "s"], UiTheme.MUTED, 0.3
				)
				await _wait(pace)
			"call":
				var slot := int(line.slot)
				if slot >= steps.size():
					continue
				var step: Dictionary = steps[slot]
				_focus(index)
				_code.set_note(index, "▶ running…", UiTheme.MUTED)
				# Each step's rune a little higher than the last: the program climbing through its lines.
				Sound.play("sfx-glyph", 0.35, 0.9 + 0.06 * slot)
				await _wait(pace * 0.5)
				# A card's function is walked the first time it runs; the same card again only shows its result.
				if not walked.has(line.card) and not _hurry:
					walked[line.card] = true
					await _walk(String(line.card), step, line_time, float(BUDGET[speed]))
				_focus(index)
				ops = mini(ProgramRules.WORK_CAP, ops + int(step.work))
				var note := "n %d → %d ops · %d bolts" % [int(step.n), int(step.work), int(step.returned)]
				_code.set_note(index, note, _status_colour(ops, budget, race), _strength(int(step.work)))
				_count_ops(ops, budget, race)
				# The volley so far lands in the meter; if its element changed, the panel takes the new colour.
				var elements: Dictionary = step.get("elements", {})
				_meter.show_volley(int(step.returned), float(step.get("power", 0.0)), elements, true)
				if not _hurry:
					card_resolved.emit(String(line.card))
				var now := VolleyMeter.colour_of(elements)
				if not now.is_equal_approx(tint):
					tint = now
					_running(true, tint)
					_code.wash(tint)
					var element := VolleyMeter.dominant(elements)
					Sound.play("sfx-element-" + element if element in SpellAnim.ELEMENT_LAYERS else "sfx-glyph", 0.4)
				await _wait(pace)
			"return":
				_focus(index)
				var final: Dictionary = steps.back() if not steps.is_empty() else {}
				var power := roundi(float(final.get("power", _power_of(seeds))))
				var note := "→ %d bolts · %d power" % [int(final.get("returned", seeds.size())), power]
				_code.set_note(index, note, tint.lightened(0.3), 0.8)
				Sound.play("sfx-glyph", 0.6, 0.75)
				await _wait(pace * 1.4)
	_code.set_cursor(-1)
	_running(false)


## Walks the function of `card` line by line (comments are passed over): each loop goes round, its rounds counted up to
## the sandbox's count; a recursive function shows how often it was entered; its last return shows what it gave back.
func _walk(card: String, step: Dictionary, most_line: float, budget: float) -> void:
	var first := _code.line_of("fn:%s:0" % card)
	if first < 0:
		return
	var last := first
	while last + 1 < _code.line_count() and _lines[last + 1].key == "fn:%s:%d" % [card, last + 1 - first]:
		last += 1
	var loops: Dictionary = step.get("loops", {})
	# Paced to the budget: every line it will light, and the rounds its loops walk, share the time.
	var lit := 0
	for index in range(first, last + 1):
		if not _is_quiet(index):
			lit += 1
	for number: String in loops:
		var header := first + int(number) - 1
		lit += (_body_end(header, last) - header + 1) * mini(int(loops[number]), 2) + 4
	var line_time := minf(most_line, budget / maxf(1.0, float(lit)))
	var calls := int(step.get("calls", 1))
	var final_return := first
	for index in range(first, last + 1):
		if _code.text_of(index).strip_edges().begins_with("return"):
			final_return = index
	var index := first
	while index <= last and not _hurry:
		if _is_quiet(index):
			index += 1
			continue
		_focus(index)
		if index == first and calls > 1:
			_code.set_note(index, "↺ %d calls" % calls, colour.lightened(0.3), _strength(calls))
		var number := str(index - first + 1)
		if loops.has(number):
			var end := _body_end(index, last)
			await _loop(index, end, int(loops[number]), loops, first, line_time)
			index = end + 1
			continue
		if index == final_return:
			_code.set_note(index, "→ %d bolts" % int(step.returned), colour.lightened(0.3), 0.35)
		await _wait(line_time)
		index += 1


## A loop goes round: a bracket down its lines, its body walked for up to two rounds (the second faster), then the rest
## of its rounds counted up quickly to the total, which lands like a hit. Loops inside it show their totals.
func _loop(header: int, end: int, rounds: int, loops: Dictionary, first: int, line_time: float) -> void:
	_code.set_loop(header, end)
	var walked := mini(rounds, 2)
	var quicker: Array[float] = [1.0, 0.55]
	for round in walked:
		if _hurry:
			break
		_code.set_note(header, "↻ %d / %d" % [round + 1, rounds], colour.lightened(0.2), 0.12)
		for index in range(header, end + 1):
			if _is_quiet(index):
				continue
			_focus(index)
			await _wait(line_time * 0.7 * quicker[round])
		if header == end:
			await _wait(line_time * 1.5 * quicker[round])
	if rounds > walked and not _hurry:
		_focus(header)
		var ticks := mini(8, rounds - walked)
		for tick in ticks:
			var shown := walked + roundi(float(rounds - walked) * (tick + 1) / ticks)
			_code.set_note(header, "↻ %d / %d" % [shown, rounds], colour.lightened(0.2))
			await _wait(line_time * 0.4)
	var total := "↻ ×%d" % rounds if rounds > 0 else "↻ ×0, skipped"
	_code.set_note(header, total, colour.lightened(0.35), _strength(rounds))
	for index in range(header + 1, end + 1):
		var inner := str(index - first + 1)
		if loops.has(inner):
			_code.set_note(index, "↻ ×%d in all" % int(loops[inner]), colour.lightened(0.2), 0.2)
	_code.clear_loop()
	await _wait(line_time * 2.0)


## The last line of the loop whose header is `header`: the lines after it indented further (none for a loop written on
## one line, such as a comprehension or a map).
func _body_end(header: int, last: int) -> int:
	var indent := _indent(_code.text_of(header))
	var end := header
	for index in range(header + 1, last + 1):
		var text := _code.text_of(index)
		if text.strip_edges() == "":
			continue
		if _indent(text) <= indent:
			break
		end = index
	return end


static func _indent(text: String) -> int:
	return text.length() - text.lstrip(" \t").length()


func _is_quiet(index: int) -> bool:
	var text := _code.text_of(index).strip_edges()
	return text == "" or text.begins_with("#") or text.begins_with("//")


func _focus(index: int) -> void:
	_code.set_cursor(index)
	_reveal(index)


## How hard a number lands: a little for 1, fully for a few hundred.
static func _strength(amount: int) -> float:
	return clampf(log(float(maxi(1, amount)) + 1.0) / log(2.0) / 8.0, 0.15, 1.0)


## Green while no foe is quicker, amber once one is, red past the budget.
func _status_colour(ops: int, budget: int, race: Array) -> Color:
	if ops > budget:
		return UiTheme.FAIL.lightened(0.15)
	for entry: Dictionary in race:
		if int(entry.tempo) < ops:
			return UiTheme.WARN
	return UiTheme.PASS


## The header's ops climb to `ops` and pop; the race's marker moves with them, and a foe it passes is called out.
func _count_ops(ops: int, budget: int, race: Array) -> void:
	var from := _counted
	_counted = ops
	var shown_colour := _status_colour(ops, budget, race)
	var count := func(value: float) -> void: _ops.text = "%d / %d ops" % [roundi(value), budget]
	var tween := create_tween()
	tween.tween_method(count, float(from), float(ops), 0.25)
	_ops.add_theme_color_override("font_color", shown_colour)
	_pop(_ops, _strength(ops - from))
	var passed_now: Array[String] = []
	var marks: Array = []
	for entry: Dictionary in race:
		var faster := int(entry.tempo) < ops
		var mark := entry.duplicate()
		mark.first = faster
		marks.append(mark)
		if faster and not _passed.has(entry.uid):
			_passed[entry.uid] = true
			passed_now.append("%s (%d)" % [entry.name, int(entry.tempo)])
	_race.show_race(marks, ops, budget, true)
	if not passed_now.is_empty():
		_footer.text = (
			"⚡ %s %s faster: acting first." % [", ".join(passed_now), "is" if passed_now.size() == 1 else "are"]
		)
		_footer.add_theme_color_override("font_color", UiTheme.WARN)
		_pop(_footer, 0.6)
		Sound.play("sfx-tempo", 0.45)


## A label lands like a hit: it swells and flashes, then settles.
func _pop(label: Control, strength: float) -> void:
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * (1.0 + 0.45 * strength)
	label.modulate = Color(1.6, 1.6, 1.6)
	var tween := label.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.32)
	tween.tween_property(label, "modulate", Color.WHITE, 0.3)


## While the Program runs, its panel is the brightest thing on the table, glowing in the colour of its volley's
## element (`tint`), which changes as the cards turn the bolts to fire, frost or spark.
func _running(on: bool, tint := Color.TRANSPARENT) -> void:
	var look := _look.duplicate() as StyleBoxFlat
	if on:
		var glow := tint if tint.a > 0.0 else colour
		look.border_color = glow.lightened(0.2)
		look.set_border_width_all(3)
		look.shadow_color = Color(glow, 0.5)
		look.shadow_size = 20
		look.bg_color = Color("#110d12").lerp(glow, 0.05)
		_title.text = "%s  ▶ running" % (session.state.spells as Array)[0].name
		_title.add_theme_color_override("font_color", glow.lightened(0.35))
		_code.glow = glow
	else:
		_title.text = (session.state.spells as Array)[0].name
		_title.add_theme_color_override("font_color", UiTheme.TEXT)
	add_theme_stylebox_override("panel", look)


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
			# Red: it acts before the program lands. Gold: the program lands first (Initiative). Grey: nothing known yet.
			var tint := UiTheme.FAIL.lightened(0.15) if entry.first else (UiTheme.AMBER if _known else UiTheme.MUTED)
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
