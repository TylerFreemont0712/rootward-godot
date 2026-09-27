extends Control
## The title, as a game's front door: the Machine at dusk, the chosen battle skin standing in it, embers drifting, and a
## short menu. Pick a way to play, then continue its run or descend into a new one. How it works, the wardrobe and the
## options are one button away.

const NAMES := {"python": "Python", "javascript": "JavaScript"}
## The ways to play, in the menu's order. A mode with no playstyle yet is shown, but not open.
const MODES: Array[Dictionary] = [
	{"id": "program", "name": "Shardrun", "line": "Draft a paradigm. Write the program. Outrun them."},
	# The card Shardrun the program run grew from: shown only while a run of it is underway, so it can be finished.
	{"id": "deck", "name": "Card Shardrun", "line": "The card run underway. Finish it here."},
	{"id": "spellbook", "name": "Spellforge", "line": "The Artificer's spellbook. Build between fights."},
	{"id": "verifier", "name": "Verifier", "line": "Trace real programs. Predict their output. Master the course."},
]
const HOW_TO: Array[String] = [
	"A card is a function: it takes a list of bolts and the battle, and returns bolts.",
	"The cards you play, in order, are one program. It starts from a seed bolt; watch its code being written.",
	"Every card has a speed, O(log n) to O(2ⁿ). A foe whose tempo beats your program's work acts before it lands.",
	"Some cards need sorted bolts. Order matters: sort first, then search.",
	"Relics bend the rules for the rest of a run. Guardians guard the best of them.",
]
const MENU_WIDTH := 820.0

var _menu: VBoxContainer
var _overlay: Control
var _backdrop: TextureRect


func _ready() -> void:
	theme = UiTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content_ok := Game.boot()
	_scene()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 64 if side == "left" else 48)
	_menu = Ui.vbox([], 12)
	_menu.custom_minimum_size.x = MENU_WIDTH
	var scroll := Ui.scroll(_menu)
	scroll.custom_minimum_size.x = MENU_WIDTH
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(scroll)
	add_child(margin)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_build(content_ok)
	Sound.music("music-title")


## The picture behind the menu: the title art drifting slowly closer, darkened on the menu's side, the chosen skin
## standing on the right, and embers rising.
func _scene() -> void:
	var ground := ColorRect.new()
	ground.color = UiTheme.GROUND
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	_backdrop = TextureRect.new()
	_backdrop.texture = Art.texture("backgrounds/title")
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var painted := _backdrop.texture != null and _backdrop.texture.resource_path.ends_with(".webp")
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if painted else CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.modulate = Color(0.78, 0.74, 0.74)
	add_child(_backdrop)
	_backdrop.resized.connect(func() -> void: _backdrop.pivot_offset = _backdrop.size * 0.5)
	var drift := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	drift.tween_property(_backdrop, "scale", Vector2.ONE * 1.06, 24.0)
	drift.tween_property(_backdrop, "scale", Vector2.ONE, 24.0)
	var shade := TextureRect.new()
	var fade := GradientTexture2D.new()
	fade.gradient = Gradient.new()
	fade.gradient.set_color(0, Color(0.03, 0.02, 0.04, 0.92))
	fade.gradient.set_color(1, Color(0.03, 0.02, 0.04, 0.0))
	fade.gradient.set_offset(1, 0.62)
	fade.width = 256
	fade.height = 4
	shade.texture = fade
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var hero := HeroView.new()
	hero.anchor_left = 0.58
	hero.anchor_right = 0.58
	hero.anchor_top = 1.0
	hero.anchor_bottom = 1.0
	hero.offset_top = -560
	hero.offset_bottom = -60
	hero.offset_right = 380
	add_child(hero)
	add_child(_embers())


func _embers() -> CPUParticles2D:
	var embers := CPUParticles2D.new()
	embers.amount = 60
	embers.lifetime = 9.0
	embers.preprocess = 9.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(1300, 10)
	embers.position = Vector2(1100, 1260)
	embers.direction = Vector2.UP
	embers.spread = 18.0
	embers.gravity = Vector2(14, -6)
	embers.initial_velocity_min = 40.0
	embers.initial_velocity_max = 110.0
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.7, 0.35, 0.0))
	ramp.set_color(1, Color(1.0, 0.45, 0.2, 0.0))
	ramp.add_point(0.2, Color(1.0, 0.75, 0.4, 0.8))
	embers.color_ramp = ramp
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	embers.material = additive
	return embers


func _build(content_ok: bool) -> void:
	Ui.clear(_menu)
	var emblem := Ui.picture("brand/shardrun", Vector2(84, 84), "")
	var logo := Ui.vbox(
		[
			Ui.label("ROOTWARD", "Title"),
			Ui.tint(Ui.label("PROGRAM THE SPELL. SURVIVE THE MACHINE.", "Faint"), UiTheme.TEAL)
		],
		0
	)
	_menu.add_child(Ui.hbox([emblem, logo], 16))
	_menu.add_child(Ui.spacer(0, 8))
	if not content_ok:
		_menu.add_child(_broken())
		return
	var problem: String = Game.session.saves.problem
	if problem != "":
		_menu.add_child(Ui.panel(Ui.tint(Ui.label(problem, "", true), UiTheme.WARN), "Card"))
	_menu.add_child(_section("01", "Choose your journey"))
	var modes := Ui.hbox([], 8)
	for mode in MODES:
		var run: ShardrunSession = Game.sessions.get(mode.id)
		if mode.id == "deck" and (run == null or not run.in_progress()):
			continue
		modes.add_child(_tile(mode))
	_menu.add_child(modes)
	if Settings.playstyle == "program":
		_menu.add_child(_section("02", "Paradigms  /  algorithms"))
		_menu.add_child(
			Ui.label(
				"Cards are real algorithms. Play them in order to write one program a turn; faster code acts first.",
				"Muted",
				true
			)
		)
	elif Settings.playstyle == "deck":
		_menu.add_child(_section("02", "Artificer  /  foundations"))
		_menu.add_child(Ui.label("Build real functions from shard cards in Python or JavaScript.", "Muted", true))
	elif Settings.playstyle == "verifier":
		_menu.add_child(_section("02", "Verifier  /  code reading"))
		_menu.add_child(
			Ui.label(
				"A separate course: trace state, predict exact output, and unlock data structures and algorithms.",
				"Muted",
				true
			)
		)
	else:
		_menu.add_child(_section("02", "Artificer workshop"))
		_menu.add_child(
			Ui.label("Arrange functions between encounters and keep each spell in your book.", "Muted", true)
		)
	_menu.add_child(
		_section("03", "Prepare your descent" if Settings.playstyle != "verifier" else "Enter the code lab")
	)
	_menu.add_child(_course_launcher() if Settings.playstyle == "verifier" else _launcher(Game.session))
	var footer := Ui.hbox(
		[Ui.button("How to play", _open_how_to), Ui.button("Options", _open_options), Ui.button("Quit", Game.quit)], 8
	)
	_menu.add_child(footer)
	_menu.add_child(Ui.tint(Ui.label("THE WORLD  /  COMING LATER", "Faint"), UiTheme.FAINT))


func _section(number: String, title: String) -> Control:
	return Ui.hbox([Ui.tint(Ui.label(number, "Faint"), UiTheme.TEAL), Ui.label(title, "Subheading")], 10)


## One way to play: its name and one line. The chosen one is outlined; a mode that is not open yet is dimmed.
func _tile(mode: Dictionary) -> Control:
	var open: bool = mode.id != ""
	var chosen: bool = open and Settings.playstyle == mode.id
	var name := Ui.tint(Ui.label(String(mode.name).to_upper(), "Heading"), UiTheme.SHARD if chosen else UiTheme.AMBER)
	var column := Ui.vbox([name, Ui.label(mode.line, "Muted", true)], 2)
	column.custom_minimum_size.y = 86
	var run: ShardrunSession = Game.sessions.get(mode.id)
	if run != null and run.in_progress():
		var where: String = ShardrunRules.layer_of(run.state, run.catalog).name
		column.add_child(Ui.tint(Ui.label("Run underway · %s" % where, "Faint"), UiTheme.TEAL))
	var tile := Ui.panel(column, "Card")
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var look := UiTheme.box(
		Color(0.08, 0.06, 0.08, 0.82),
		UiTheme.SHARD if chosen else Color(1, 1, 1, 0.08),
		2 if chosen else 1,
		10,
		Vector2(18, 12)
	)
	tile.add_theme_stylebox_override("panel", look)
	if not open:
		tile.modulate = Color(1, 1, 1, 0.45)
		return tile
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.gui_input.connect(
		func(event: InputEvent) -> void:
			var click := event as InputEventMouseButton
			if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not chosen:
				Game.use(mode.id)
				Settings.save_file()
				Sound.play("sfx-card", 0.5)
				_build(true)
	)
	return tile


## Under the chosen mode: continue its run, or descend into a new one in a language at a difficulty.
func _launcher(session: ShardrunSession) -> Control:
	var column := Ui.vbox([], 10)
	if session.in_progress():
		var state := session.state
		var where := (
			"%s · %s · Integrity %d/%d · %s"
			% [
				ShardrunRules.layer_of(state, session.catalog).name,
				"Artificer",
				int(state.integrity),
				int(state.integrity_max),
				NAMES.get(state.language, state.language)
			]
		)
		var go := Ui.button("Continue", func() -> void: Game.go(Game.SHARDRUN), "PrimaryButton")
		go.custom_minimum_size = Vector2(200, 46)
		go.call_deferred("grab_focus")
		column.add_child(Ui.hbox([go, Ui.label(where, "Muted")], 14))
	elif session.has_run():
		var score := int(session.score().get("total", 0))
		column.add_child(Ui.label("Last run: %s · score %d" % [session.state.status, score], "Faint"))
	var usable := Game.languages()
	var language := Settings.language
	var languages := Ui.hbox([Ui.label("RUNTIME", "Faint")], 6)
	for available in SandboxJob.LANGUAGES:
		var pick := func() -> void:
			Settings.language = available
			Settings.save_file()
			_build(true)
		var button := Ui.choice(NAMES[available], Settings.language == available, pick)
		button.disabled = not available in usable
		languages.add_child(button)
	column.add_child(languages)
	var choices := Ui.hbox([Ui.label("CHALLENGE", "Faint")], 6)
	for difficulty: Dictionary in session.catalog.config.difficulties:
		var pick := func() -> void:
			Settings.difficulty = difficulty.id
			Settings.save_file()
			_build(true)
		var button := Ui.choice(difficulty.name, Settings.difficulty == difficulty.id, pick)
		button.tooltip_text = difficulty.summary
		choices.add_child(button)
	column.add_child(choices)
	if usable.is_empty():
		var missing := "No sandbox is installed, so no spell can run. Run scripts/fetch-sandbox.sh, then restart."
		column.add_child(Ui.tint(Ui.label(missing, "", true), UiTheme.FAIL))
	var start := Ui.button(
		"New run" if session.in_progress() else "Descend", _start, "" if session.in_progress() else "PrimaryButton"
	)
	start.custom_minimum_size = Vector2(200, 46 if not session.in_progress() else 38)
	start.disabled = not language in usable
	if not session.in_progress():
		start.call_deferred("grab_focus")
	var actions := Ui.hbox([start], 8)
	if Game.dev_tools():
		var sandbox := Ui.button("Sandbox run", _start_sandbox)
		sandbox.tooltip_text = "A run with the dev drawer: grant shards and relics, spawn foes, jump layers."
		sandbox.disabled = start.disabled
		actions.add_child(sandbox)
	column.add_child(actions)
	var looks := Ui.button("Choose from %d looks" % Settings.CHARACTER_SKINS.size(), _open_skins)
	var history := session.saves.load_history()
	var commits := Ui.button("git log (%d)" % history.size(), _open_git_log.bind(history))
	commits.tooltip_text = "Every finished run, as a commit: how it ended, what it dealt, what it carried."
	column.add_child(Ui.hbox([Ui.label("YOUR LOOK", "Faint"), looks, Ui.spacer(), commits], 8))
	var panel := Ui.panel(column, "Card")
	panel.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(0.06, 0.05, 0.06, 0.85), Color(1, 1, 1, 0.06), 1, 10, Vector2(18, 14))
	)
	return panel


func _course_launcher() -> Control:
	var error := VerifierCourse.load_course()
	var column := Ui.vbox([], 10)
	if error != "":
		column.add_child(Ui.tint(Ui.label(error, "Muted", true), UiTheme.FAIL))
	else:
		var cleared := 0
		for i in VerifierCourse.lessons.size():
			if VerifierCourse.stars(i) > 0:
				cleared += 1
		column.add_child(
			Ui.label(
				"%d / %d lessons cleared · 3 chapters · JavaScript" % [cleared, VerifierCourse.lessons.size()],
				"Subheading"
			)
		)
		column.add_child(
			Ui.label(
				"Arrays and control flow → state and references → algorithms. Progress saves after each proven output.",
				"Muted",
				true
			)
		)
	var enter := Ui.button("Open code lab", func() -> void: Game.go(Game.VERIFIER), "PrimaryButton")
	enter.custom_minimum_size = Vector2(240, 46)
	enter.disabled = error != "" or not Sandbox.is_available(SandboxJob.JAVASCRIPT)
	column.add_child(enter)
	if not Sandbox.is_available(SandboxJob.JAVASCRIPT):
		column.add_child(
			Ui.tint(
				Ui.label("JavaScript sandbox required. Run scripts/fetch-sandbox.sh, then restart.", "Muted", true),
				UiTheme.FAIL
			)
		)
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
	var text := "Starting anew replaces the run underway. Your Verifier course progress is saved separately."
	var yes := Ui.button("Start anew", _begin.bind(sandbox), "DangerButton")
	var no := Ui.button("Keep the run", func() -> void: Ui.clear(_overlay), "PrimaryButton")
	var panel := Ui.panel(
		Ui.vbox([Ui.label("Start a new run?", "Heading"), Ui.label(text, "", true), Ui.hbox([no, yes])], 14), "Overlay"
	)
	panel.custom_minimum_size = Vector2(520, 0)
	_show_overlay(panel)


func _open_how_to() -> void:
	var column := Ui.vbox([Ui.label("How it works", "Heading")], 10)
	var story := (
		"Under the Bastion lies the Salvage: old programs, broken into shards. Every shard is a real function. "
		+ "Chain them into spells, climb three layers of the Machine, and find out what your code can do."
	)
	column.add_child(Ui.label(story, "Narration", true))
	for line in HOW_TO:
		column.add_child(Ui.label("•  " + line, "", true))
	column.add_child(Ui.label("THE CLASSES", "Subheading"))
	column.add_child(
		Ui.label(
			"Artificer: choose Python or JavaScript, build a spell from cards, and watch the code execute.",
			"Muted",
			true
		)
	)
	column.add_child(
		Ui.label(
			(
				"Verifier: a separate JavaScript course. Trace a variable, predict exact stdout, "
				+ "and learn arrays, state, and algorithms across twelve lessons."
			),
			"Muted",
			true
		)
	)
	column.add_child(Ui.hbox([Ui.button("Close", func() -> void: Ui.clear(_overlay), "PrimaryButton")]))
	var panel := Ui.panel(column, "Overlay")
	panel.custom_minimum_size = Vector2(720, 0)
	_show_overlay(panel)


func _open_options() -> void:
	var options := OptionsPanel.create()
	options.closed.connect(func() -> void: Ui.clear(_overlay))
	_show_overlay(options)


func _open_git_log(history: Array[Dictionary]) -> void:
	var view := GitLogView.create(history)
	view.closed.connect(func() -> void: Ui.clear(_overlay))
	_show_overlay(view)


func _open_skins() -> void:
	var wardrobe := SkinSelectionPanel.create()
	wardrobe.closed.connect(func() -> void: Ui.clear(_overlay))
	wardrobe.skin_selected.connect(func(_id: String) -> void: get_tree().reload_current_scene.call_deferred())
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
