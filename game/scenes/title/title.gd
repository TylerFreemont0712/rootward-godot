extends Control
## The title: continue the run underway, or start one in Python or JavaScript at a difficulty. What a shard is and how
## a spell runs are said here once, in a few lines.

const HOW_TO: Array[String] = [
	"A shard is a function that takes a list of bolts and the battle, and returns bolts.",
	(
		"A spell runs its shards in order, starting from one plain bolt. Press </> Code on a spell to read it as one "
		+ "function, and watch every cast run line by line."
	),
	(
		"Every bolt a shard handles costs mana, and bolts past the cap fizzle, so a loop that makes a thousand bolts "
		+ "wins nothing."
	),
	"Relics bend the rules for the rest of a run. Guardians guard the best of them.",
]
const NAMES := {"python": "Python", "javascript": "JavaScript"}
const MODES := {
	"deck":
	[
		"Shardrun",
		(
			"Shards are cards. Every turn you draw a hand and play it into two blank spells, in the order they should run: "
			+ "building the spell is the turn."
		),
	],
	"spellbook":
	[
		"Spellforge",
		"Shards are yours to keep. Build your spells at the workbench between fights, then cast them in battle.",
	],
}

var _column: VBoxContainer
var _overlay: Control


func _ready() -> void:
	theme = UiTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content_ok := Game.boot()
	var ground := ColorRect.new()
	ground.color = UiTheme.GROUND
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	var backdrop := TextureRect.new()
	backdrop.texture = Art.texture("backgrounds/title")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.modulate = Color(0.42, 0.38, 0.36)
	add_child(backdrop)
	_column = Ui.vbox([], 16)
	_column.custom_minimum_size.x = 1240
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	margin.add_child(_column)
	var page := Ui.centered_scroll(margin)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_build(content_ok)
	Sound.music("music-title")


func _build(content_ok: bool) -> void:
	Ui.clear(_column)
	var emblem := Ui.picture("brand/shardrun", Vector2(96, 96), "")
	var mode_name := String(Game.PLAYSTYLES.get(Settings.playstyle, "Shardrun")).to_upper()
	var titles := Ui.vbox([Ui.label("ROOTWARD", "Title"), Ui.tint(Ui.label(mode_name, "Heading"), UiTheme.SHARD)], 0)
	_column.add_child(Ui.hbox([emblem, titles], 18))
	if not content_ok:
		_column.add_child(_broken())
		return
	var left := Ui.vbox([], 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	var story := (
		"Under the Bastion lies the Salvage: old programs, broken into shards. Every shard is a real function. "
		+ "Chain them into spells, climb through three layers of the Machine, and find out what your code can do."
	)
	left.add_child(Ui.label(story, "Narration", true))
	left.add_child(_modes())
	var problem: String = Game.session.saves.problem
	if problem != "":
		left.add_child(Ui.panel(Ui.tint(Ui.label(problem, "", true), UiTheme.WARN), "Card"))
	var session := Game.session
	if session.in_progress():
		left.add_child(_underway(session))
	elif session.has_run():
		left.add_child(Ui.panel(RunSummary.ending(session.state, "Heading"), "Card"))
	left.add_child(_new_run(session))
	var how := Ui.vbox([Ui.label("How it works", "Subheading")], 10)
	for line in HOW_TO:
		how.add_child(Ui.label("•  " + line, "", true))
	var right := Ui.panel(how, "")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_column.add_child(Ui.hbox([left, right], 20))
	var quit := Ui.button("Quit", Game.quit)
	_column.add_child(Ui.hbox([Ui.button("Appearance", _open_skins), Ui.button("Options", _open_options), quit], 8))


## The two ways to play, side by side; the chosen one is the one below it continues or starts.
func _modes() -> Control:
	var row := Ui.hbox([], 10)
	for playstyle: String in MODES:
		var chosen := Settings.playstyle == playstyle
		var pick := func() -> void:
			Game.use(playstyle)
			Settings.save_file()
			_build(true)
		var run: ShardrunSession = Game.sessions.get(playstyle)
		var note := ""
		if run != null and run.in_progress():
			note = "A run is underway on %s." % ShardrunRules.layer_of(run.state, run.catalog).name
		var column := Ui.vbox(
			[Ui.choice(MODES[playstyle][0], chosen, pick), Ui.label(MODES[playstyle][1], "Muted", true)], 6
		)
		if note != "":
			column.add_child(Ui.tint(Ui.label(note, "Faint"), UiTheme.SHARD))
		row.add_child(Ui.expand(Ui.panel(column, "Card")))
	return row


func _underway(session: ShardrunSession) -> Control:
	var state := session.state
	var layer := ShardrunRules.layer_of(state, session.catalog)
	var where := (
		"%s · Integrity %d/%d · %s · %s"
		% [
			layer.name,
			int(state.integrity),
			int(state.integrity_max),
			NAMES.get(state.language, state.language),
			session.difficulty().get("name", "")
		]
	)
	var go := Ui.button(
		"Continue the %s run" % Game.PLAYSTYLES.get(session.playstyle, ""),
		func() -> void: Game.go(Game.SHARDRUN),
		"PrimaryButton"
	)
	go.custom_minimum_size = Vector2(260, 44)
	go.call_deferred("grab_focus")
	var column := Ui.vbox([Ui.label("A run is underway", "Subheading"), Ui.label(where, "Muted"), Ui.hbox([go])], 8)
	return Ui.panel(column, "Card")


func _new_run(session: ShardrunSession) -> Control:
	var column := Ui.vbox([Ui.label("A new run" if session.in_progress() else "Descend", "Subheading")], 10)
	var usable := Game.languages()
	var languages := Ui.hbox([Ui.label("Language", "Muted")], 8)
	for language in SandboxJob.LANGUAGES:
		var pick := func() -> void:
			Settings.language = language
			Settings.save_file()
			_build(true)
		var button := Ui.choice(NAMES[language], Settings.language == language, pick)
		button.disabled = not language in usable
		languages.add_child(button)
	column.add_child(languages)
	if usable.is_empty():
		var missing := "No sandbox is installed, so no spell can run. Run scripts/fetch-sandbox.sh, then restart."
		column.add_child(Ui.tint(Ui.label(missing, "", true), UiTheme.FAIL))
	var difficulties := Ui.hbox([], 10)
	for difficulty: Dictionary in session.catalog.config.difficulties:
		var pick := func() -> void:
			Settings.difficulty = difficulty.id
			Settings.save_file()
			_build(true)
		var chosen: bool = Settings.difficulty == difficulty.id
		var name := Ui.choice(difficulty.name, chosen, pick)
		var card := Ui.vbox([name, Ui.label(difficulty.summary, "Muted", true)], 6)
		difficulties.add_child(Ui.expand(Ui.panel(card, "Card")))
	column.add_child(difficulties)
	var language_name: String = NAMES.get(Settings.language, Settings.language)
	var start := Ui.button("Descend in %s" % language_name, _start, "PrimaryButton")
	start.custom_minimum_size = Vector2(260, 44)
	start.disabled = not Settings.language in usable
	if not session.in_progress():
		start.call_deferred("grab_focus")
	var actions := Ui.hbox([start], 10)
	if Game.dev_tools():
		var sandbox := Ui.button("Sandbox run (dev tools)", _start_sandbox)
		sandbox.tooltip_text = "A run with the dev drawer: grant shards and relics, spawn foes, jump layers."
		sandbox.disabled = start.disabled
		actions.add_child(sandbox)
	column.add_child(actions)
	return Ui.panel(column, "Card")


func _start() -> void:
	if Game.session.in_progress():
		_confirm_new_run(false)
		return
	_begin(false)


func _start_sandbox() -> void:
	if Game.session.in_progress():
		_confirm_new_run(true)
		return
	_begin(true)


func _begin(sandbox: bool) -> void:
	var difficulties: Array = Game.catalog.config.difficulties
	var known := difficulties.any(func(d: Dictionary) -> bool: return d.id == Settings.difficulty)
	Game.session.start(Settings.language, Settings.difficulty if known else String(difficulties[0].id), "", sandbox)
	Game.go(Game.SHARDRUN)


func _confirm_new_run(sandbox: bool) -> void:
	var text := "The run underway ends here: one run at a time. It is replaced by the new one."
	var yes := Ui.button("Start anew", _begin.bind(sandbox), "DangerButton")
	var no := Ui.button("Keep the run", func() -> void: Ui.clear(_overlay), "PrimaryButton")
	var panel := Ui.panel(
		Ui.vbox([Ui.label("Start a new run?", "Heading"), Ui.label(text, "", true), Ui.hbox([no, yes])], 14), "Overlay"
	)
	panel.custom_minimum_size = Vector2(520, 0)
	_show_overlay(panel)


func _open_options() -> void:
	var options := OptionsPanel.create()
	options.closed.connect(func() -> void: Ui.clear(_overlay))
	_show_overlay(options)


func _open_skins() -> void:
	var wardrobe := SkinSelectionPanel.create()
	wardrobe.closed.connect(func() -> void: Ui.clear(_overlay))
	_show_overlay(wardrobe)


func _show_overlay(panel: Control) -> void:
	Ui.clear(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var page := Ui.centered_scroll(panel)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(page)


func _broken() -> Control:
	var column := Ui.vbox(
		[Ui.tint(Ui.label("The content has errors, so a run cannot start.", "Subheading"), UiTheme.FAIL)]
	)
	for diagnostic: Dictionary in Game.diagnostics.slice(0, 12):
		column.add_child(Ui.label(ContentLoader.describe(diagnostic), "Muted", true))
	column.add_child(Ui.label("scripts/validate.sh lists every problem.", "Faint"))
	return Ui.panel(column, "Card")
