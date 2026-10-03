class_name CodeView
extends PanelContainer
## A spell as one function, running line by line (old ADR-0013). The cursor walks the code at the chosen speed; the
## bolts, damage and block change only where the sandbox measured them: the start, after each shard, and the end.
##
## "cast" mode plays once and says `finished` (or is skipped); "explore" mode shows the code still, and can run it
## again when there is a run to show. Numbers are the rules' own (ShardrunViews.spell_run_view).
##
##   var view := CodeView.create(language, spell, catalog.shards, 4, run_view, "cast", Settings.code_speed)
##   add_child(view)
##   await view.finished

signal finished
## A measured shard return, indexed by its call slot so duplicate shard cards remain distinct.
signal shard_resolved(index: int)

const ROW_CURRENT := Color(0.95, 0.65, 0.25, 0.22)
const ROW_ERROR := Color(0.89, 0.35, 0.31, 0.3)
const ROW_ACTIVE := Color(0.71, 0.55, 1.0, 0.07)
## The code's font size (design canvas): the code is what this view is for, so it is the largest text in it.
const CODE_SIZE := 16

var language := ""
var mode := "cast"
var speed := "normal"
var source: SpellSource
var run: Dictionary = {}
var played: Array[Dictionary] = []
var _rows: Array[PanelContainer] = []
var _notes: Array[Label] = []
var _styles: Dictionary = {}
var _scores: Dictionary = {}
var _worth: Label
var _bolts: HFlowContainer
var _scroll: ScrollContainer
var _misfire: Label
var _take := 0
var _done := false
var _resolved := 0


static func create(
	run_language: String,
	spell: Dictionary,
	shards: Dictionary,
	base_power: int,
	run_view: Dictionary,
	view_mode: String,
	play_speed: String
) -> CodeView:
	var view := CodeView.new()
	view.language = run_language
	view.mode = view_mode
	view.speed = play_speed if play_speed in SpellSource.SPEEDS else "fast"
	view.run = run_view
	view.source = SpellSource.compose(run_language, spell.name, spell.shards, shards, base_power)
	if view.playable():
		view.played = SpellSource.frames(view.source, run_view, view.speed)
	view.theme_type_variation = "Overlay"
	view._build(spell)
	return view


## Whether there is anything measured to play: a hidden prediction has no steps, so the code is shown still.
func playable() -> bool:
	return (
		not run.is_empty()
		and (not (run.get("steps", []) as Array).is_empty() or run.has("result") or run.has("misfire"))
	)


func _ready() -> void:
	if mode == "cast":
		if played.is_empty():
			_finish.call_deferred()
		else:
			play()


func _unhandled_input(event: InputEvent) -> void:
	if mode == "cast" and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		skip()


func skip() -> void:
	if mode == "cast":
		# The omitted animation still represents measured returns, never unvisited or failing functions.
		for frame: Dictionary in played:
			if frame.get("mark", "") == "step":
				_resolve_shard(int(frame.step))
		_finish()


func play() -> void:
	_take += 1
	var take := _take
	_reset()
	var started := Time.get_ticks_msec()
	for index in played.size():
		var wait := float(played[index].at) - (Time.get_ticks_msec() - started)
		if wait > 0.0:
			await get_tree().create_timer(wait / 1000.0).timeout
		if take != _take or not is_inside_tree():
			return
		_show(index)
	var tail := SpellSource.length_ms(played, speed) - (Time.get_ticks_msec() - started)
	if tail > 0.0:
		await get_tree().create_timer(tail / 1000.0).timeout
	if take == _take and mode == "cast":
		_finish()


func _finish() -> void:
	_take += 1
	if run.has("result"):
		_score(run.result)
	if _done:
		return
	_done = true
	finished.emit()


func _build(spell: Dictionary) -> void:
	custom_minimum_size = Vector2(560, 0)
	var steps: Array = run.get("steps", [])
	var work := 0
	for step: Dictionary in steps:
		work += int(step.work)
	var count := (spell.shards as Array).size()
	var meta := "%s · %d %s" % [language, count, "shard" if count == 1 else "shards"]
	if run.has("cost"):
		meta += " · %d mana" % int(run.cost)
	if work > 0:
		meta += " · %d work" % work
	var actions := Ui.hbox()
	if mode == "explore" and playable():
		actions.add_child(Ui.button("Run it", play))
	actions.add_child(Ui.button("Skip" if mode == "cast" else "Close", skip if mode == "cast" else _finish))
	var header := Ui.hbox([Ui.label(spell.name, "Subheading"), Ui.label(meta, "Muted"), Ui.spacer(), actions], 12)
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	var body := Ui.vbox([header], 8)
	if playable():
		body.add_child(_scoreboard())
	else:
		var hint := "No predictions on this difficulty: read the code, then cast it to watch it run."
		if run.has("note"):
			hint = run.note
		elif run.is_empty():
			hint = "Reading the shards…"
		elif not bool(run.get("revealed", true)):
			hint = "Predictions are hidden: read the code, then cast it to watch it run."
		body.add_child(Ui.label(hint, "Muted", true))
	_bolts = Ui.flow([], 6)
	body.add_child(_bolts)
	body.add_child(_code())
	_misfire = Ui.tint(Ui.label("", "", true), UiTheme.FAIL) as Label
	_misfire.visible = false
	body.add_child(_misfire)
	var console := String(run.get("console", ""))
	if console != "":
		var printed := Ui.panel(Ui.tint(Ui.label(console, "Code", true), UiTheme.MUTED), "Sunken")
		body.add_child(Ui.vbox([Ui.label("Printed", "Faint"), printed], 2))
	add_child(body)


## The three numbers in one slim row, so the code below keeps most of the height.
func _scoreboard() -> Control:
	var row := Ui.hbox([], 26)
	var kinds := [["bolts", UiTheme.SHARD], ["damage", UiTheme.AMBER], ["block", UiTheme.TEAL]]
	for kind: Array in kinds:
		var number := Ui.sized(Ui.tint(Ui.label("0", "Big"), kind[1]), 30) as Label
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_scores[kind[0]] = number
		var caption := Ui.label(String(kind[0]).to_upper(), "Faint")
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(Ui.hbox([caption, number], 8))
	_worth = Ui.label("", "Muted")
	_worth.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_worth)
	return Ui.panel(row, "Card")


func _code() -> Control:
	var lines := Ui.vbox([], 0)
	_styles = {
		"": StyleBoxEmpty.new(),
		"current": UiTheme.box(ROW_CURRENT, UiTheme.AMBER, 0, 0, Vector2(4, 0)),
		"error": UiTheme.box(ROW_ERROR, UiTheme.FAIL, 0, 0, Vector2(4, 0)),
		"active": UiTheme.box(ROW_ACTIVE, Color.TRANSPARENT, 0, 0, Vector2(4, 0)),
	}
	(_styles.current as StyleBoxFlat).border_width_left = 3
	(_styles.error as StyleBoxFlat).border_width_left = 3
	for line: Dictionary in source.lines:
		var gutter := Ui.label(str(line.number), "Faint")
		gutter.custom_minimum_size.x = 34
		gutter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.add_theme_font_override("normal_font", UiTheme.code_font())
		text.fit_content = true
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_OFF
		text.text = CodeColors.bbcode(line.text, language)
		text.add_theme_font_size_override("normal_font_size", CODE_SIZE)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var note := Ui.tint(Ui.label("", "Muted"), UiTheme.TEAL) as Label
		var row := Ui.panel(Ui.hbox([gutter, text, note], 10), "")
		row.add_theme_stylebox_override("panel", _styles[""])
		lines.add_child(row)
		_rows.append(row)
		_notes.append(note)
	_scroll = Ui.scroll(lines, true)
	_scroll.custom_minimum_size = Vector2(0, 160)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sunken := Ui.panel(_scroll, "Sunken")
	sunken.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return sunken


func _reset() -> void:
	_resolved = 0
	for i in _rows.size():
		_style(i, "")
		_notes[i].text = ""
	_misfire.visible = false


func _show(index: int) -> void:
	var frame := played[index]
	var line := int(frame.line)
	var active: String = (source.lines[line - 1] as Dictionary).get("shard", "")
	for i in _rows.size():
		var shard: String = (source.lines[i] as Dictionary).get("shard", "")
		_style(i, "active" if active != "" and shard == active else "")
	var mark: String = frame.get("mark", "")
	_style(line - 1, "error" if mark == "error" else "current")
	_follow(_rows[line - 1])
	if frame.has("outcome"):
		_score(frame.outcome)
	if frame.has("bolts"):
		_show_bolts(frame.bolts)
	if mark == "step":
		var step: Dictionary = (run.steps as Array)[int(frame.step)]
		var outcome: Dictionary = step.get("outcome", {})
		var note := "→ %d %s" % [int(outcome.get("bolts", 0)), "bolt" if int(outcome.get("bolts", 0)) == 1 else "bolts"]
		if int(outcome.get("damage", 0)) > 0:
			note += " · %d dmg" % int(outcome.damage)
		if int(outcome.get("block", 0)) > 0:
			note += " · %d block" % int(outcome.block)
		_notes[line - 1].text = note + " · %d work" % int(step.work)
		_resolve_shard(int(frame.step))
	if mark == "error":
		_misfire.text = "Misfire: %s" % (run.get("misfire", {}) as Dictionary).get("reason", "")
		_misfire.visible = true


func _resolve_shard(index: int) -> void:
	if index != _resolved:
		return
	_resolved += 1
	shard_resolved.emit(index)


## Scrolls up or down to keep the current line in view, a few lines from the edge; never sideways, so the start of
## every line stays where the eye expects it.
func _follow(row: Control) -> void:
	var top := row.position.y
	var margin := row.size.y * 3.0
	var view := _scroll.size.y
	if top - margin < _scroll.scroll_vertical:
		_scroll.scroll_vertical = int(maxf(0.0, top - margin))
	elif top + row.size.y + margin > _scroll.scroll_vertical + view:
		_scroll.scroll_vertical = int(top + row.size.y + margin - view)


func _style(index: int, kind: String) -> void:
	_rows[index].add_theme_stylebox_override("panel", _styles[kind])


func _score(outcome: Dictionary) -> void:
	if _scores.is_empty():
		return
	for kind: String in _scores:
		(_scores[kind] as Label).text = str(int(outcome.get(kind, 0)))
	var damage := int(outcome.get("damage", 0))
	var potential := int(outcome.get("potential", 0))
	_worth.text = ""
	if potential > damage:
		_worth.text = "worth %d" % potential
		if damage > 0:
			_worth.text += " · ×%s over" % String.num(float(potential) / damage, 1)


func _show_bolts(bolts: Array) -> void:
	Ui.clear(_bolts)
	for bolt: Dictionary in bolts.slice(0, 24):
		var text := ("⛨ " if bolt.ward else "◆ ") + JsMath.text(bolt.power)
		if float(bolt.mult) != 1.0:
			text += " ×" + JsMath.text(bolt.mult)
		var chip := Ui.panel(Ui.tint(Ui.label(text, "Muted"), UiTheme.element(bolt.element)), "Chip")
		chip.tooltip_text = "%s bolt, aimed %s%s" % [bolt.element, bolt.target, ", pierces" if bolt.pierce else ""]
		_bolts.add_child(chip)
	if bolts.size() > 24:
		_bolts.add_child(Ui.label("+%d more" % (bolts.size() - 24), "Faint"))
