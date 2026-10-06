class_name LanternrootScreen
extends Control
## Lanternroot (ADR-0055): a hamlet in the roots whose whole town is the player's program. The screen shows the town
## and its letters, opens the workbench, runs tests in the sandbox and plays the Night Watch; the rules are
## LanternRules, the drawing LanternTownView, the code-running LanternWatch. The town is saved after every change.

const SIDE_WIDTH := 500.0

const WELCOME: Array[String] = [
	"Below the surface station, a little hamlet hangs in the roots. Its lanterns went out when the old tinker left.",
	(
		"Villagers will send you letters. Each asks for one function. Write it in real code and run its tests: "
		+ "when they pass, a lantern is lit."
	),
	(
		"Every file you write becomes a house, and every import a rope bridge between two houses. "
		+ "The whole town is one program: yours."
	),
	(
		"Each night the Night Watch reruns every test in town. "
		+ "If a change broke something that used to work, a gremlin moves in."
	),
]

static var _catalog_cache: Dictionary = {}

var town: Dictionary = {}
var catalog: Dictionary = {}

var _store: LanternStore
var _view: LanternTownView
var _side: PanelContainer
var _side_box: VBoxContainer
var _bench: LanternWorkbench
var _modal: Control
var _heading: Label
var _subheading: Label
var _status := ""
var _busy := false


func _ready() -> void:
	Game.boot()
	theme = FoundryUi.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	catalog = catalog_of()
	_store = LanternStore.for_profile()
	_build()
	Sound.music("music-rest")
	var saved := _store.languages()
	var preferred := Settings.language if Settings.language in LanternRules.LANGUAGES else LanternCode.PYTHON
	if preferred in saved:
		start(preferred)
	elif not saved.is_empty():
		start(saved[0])
	else:
		_side.visible = false
		_show_welcome()


## Lanternroot's content, loaded once.
static func catalog_of() -> Dictionary:
	if _catalog_cache.is_empty():
		var loaded := LanternContent.load_town()
		for diagnostic: Dictionary in loaded.diagnostics:
			push_error(ContentLoader.describe(diagnostic))
		_catalog_cache = loaded.catalog
	return _catalog_cache


## Opens the town in `language`, founding it if there is none yet.
func start(language: String) -> void:
	var saved := _store.load_town(language)
	town = saved if not saved.is_empty() else LanternRules.new_town(language)
	_side.visible = true
	_save()
	_close_modal()
	_refresh()


func _build() -> void:
	_view = LanternTownView.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.house_pressed.connect(_on_house)
	add_child(_view)
	_heading = Ui.sized(Ui.label("LANTERNROOT", "Title"), 54) as Label
	_heading.add_theme_color_override("font_color", UiTheme.AMBER)
	_subheading = Ui.label("", "Muted")
	var corner := Ui.vbox([_heading, _subheading], 2)
	corner.position = Vector2(48, 28)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(corner)
	_side_box = Ui.vbox([], 10)
	_side = Ui.panel(Ui.scroll(_side_box), "Overlay")
	_side.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_side.offset_left = -SIDE_WIDTH - 24
	_side.offset_right = -24
	_side.offset_top = 24
	_side.offset_bottom = -24
	add_child(_side)
	_bench = LanternWorkbench.make()
	_bench.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top"]:
		_bench.set("offset_" + side, 20.0)
	for side: String in ["right", "bottom"]:
		_bench.set("offset_" + side, -20.0)
	_bench.visible = false
	_bench.run_requested.connect(_run_tests)
	_bench.hint_requested.connect(_take_hint)
	_bench.restore_requested.connect(_restore)
	_bench.back_requested.connect(_leave_bench)
	_bench.add_file_requested.connect(_ask_for_house.bind(true))
	add_child(_bench)
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_modal)
	resized.connect(_place_town)
	_place_town()


func _place_town() -> void:
	if _view != null:
		_view.area = Rect2(60, 170, maxf(400.0, size.x - SIDE_WIDTH - 160), maxf(400.0, size.y - 260))


func _refresh() -> void:
	if town.is_empty():
		return
	_view.language = town.language
	_view.show_town(LanternLayout.of(catalog, town), _ghosts())
	var day := LanternRules.day_info(catalog, int(town.day))
	_subheading.text = Text.f("Day %d: %s", [int(town.day), Text.t(day.title)])
	FoundryUi.rebuild(_side_box, _fill_side)


## Houses not built yet that today's letters will raise: drawn as faint plans so the town to come can be seen.
func _ghosts() -> Array[Dictionary]:
	var ghosts: Array[Dictionary] = []
	var houses: Dictionary = catalog.town.houses
	for request in LanternRules.letters(catalog, town):
		var module := String(request.module)
		if houses.has(module) and not (town.files as Dictionary).has(module):
			if ghosts.any(func(g: Dictionary) -> bool: return g.module == module):
				continue
			var spot: Dictionary = houses[module]
			ghosts.append(
				{"module": module, "name": spot.name, "roof": spot.roof, "at": Vector2(spot.at[0], spot.at[1])}
			)
	return ghosts


func _fill_side() -> void:
	var day := LanternRules.day_info(catalog, int(town.day))
	_side_box.add_child(Ui.label(Text.f("DAY %d OF %d", [int(town.day), LanternRules.last_day(catalog)]), "Faint"))
	_side_box.add_child(Ui.sized(Ui.label(Text.t(day.title), "Heading", true), 26))
	_side_box.add_child(Ui.label(Text.t(day.dawn), "Muted", true))
	_side_box.add_child(FoundryUi.rule())
	if bool(town.complete):
		(
			_side_box
			. add_child(
				(
					Ui
					. panel(
						(
							Ui
							. vbox(
								[
									Ui.tint(
										Ui.label(Text.t("✦ Every lantern in Lanternroot is lit."), "Subheading", true),
										UiTheme.AMBER
									),
									(
										Ui
										. label(
											(
												Text
												. t(
													"The hamlet runs on your program. Deeper in the roots, more villages are waiting."
												)
											),
											"Muted",
											true
										)
									),
								],
								6
							)
						),
						"Card"
					)
				)
			)
		)
	var gremlins := _gremlins()
	if not gremlins.is_empty():
		_side_box.add_child(Ui.tint(Ui.label(Text.t("GREMLINS"), "Faint"), UiTheme.FAIL))
		_side_box.add_child(
			Ui.label(
				Text.t("Fix the code, then run its tests at the workbench to chase each gremlin out."), "Muted", true
			)
		)
		for lantern: String in gremlins:
			var standing: String = LanternRules.standing(catalog, town)[lantern]
			var request: Dictionary = catalog.requests[standing]
			var house: Dictionary = (catalog.town.houses as Dictionary).get(request.module, {"name": request.module})
			_side_box.add_child(
				FoundryUi.action(
					Text.f("A gremlin in %s", [Text.t(house.name)]),
					Text.f("“%s” no longer works", [Text.t(request.title)]),
					_open_bench.bind(standing, String(request.module))
				)
			)
	var letters := LanternRules.letters(catalog, town)
	_side_box.add_child(
		Ui.label(Text.t("LETTERS") if not letters.is_empty() else Text.t("NO LETTERS WAITING"), "Faint")
	)
	for request in letters:
		var villager: Dictionary = catalog.town.villagers[request.villager]
		var concepts := ", ".join(
			PackedStringArray((request.concepts as Array).map(func(c: String) -> String: return Text.t(c)))
		)
		var card := FoundryUi.action(
			Text.t(request.title),
			Text.f("From %s · %s", [Text.t(villager.name), concepts]),
			_open_letter.bind(String(request.id)),
			request == letters[0]
		)
		_side_box.add_child(card)
	if letters.is_empty() and not bool(town.complete):
		var hint := (
			"Ring the night bell: the Night Watch checks the town, and a new day brings new letters."
			if gremlins.is_empty()
			else "Chase out the gremlins, then ring the night bell."
		)
		_side_box.add_child(Ui.label(Text.t(hint), "Muted", true))
	_side_box.add_child(FoundryUi.rule())
	_side_box.add_child(Ui.label(_tally(), "Muted", true))
	var bell := FoundryUi.button(
		Text.t("Ring the night bell"), _ring_bell, letters.is_empty() and not (town.solved as Dictionary).is_empty()
	)
	bell.tooltip_text = Text.t("The Night Watch reruns every test in town against the code as it is now.")
	bell.disabled = _busy or (town.solved as Dictionary).is_empty()
	_side_box.add_child(bell)
	_side_box.add_child(FoundryUi.button(Text.t("Build a workshop of your own"), _ask_for_house.bind(false)))
	var other := LanternCode.JAVASCRIPT if town.language == LanternCode.PYTHON else LanternCode.PYTHON
	if other in Game.languages():
		var switch := FoundryUi.button(
			Text.f("Visit the %s town", [SandboxJob.NAMES[other]]), start.bind(other), false, true
		)
		switch.tooltip_text = Text.t("Each language has its own town, with its own code.")
		_side_box.add_child(switch)
	_side_box.add_child(FoundryUi.button(Text.t("Back to the surface"), _leave, false, true))
	if _status != "":
		_side_box.add_child(Ui.tint(Ui.label(_status, "Muted", true), UiTheme.WARN))


func _tally() -> String:
	var layout := LanternLayout.of(catalog, town)
	var lit := 0
	var total := 0
	for house: Dictionary in layout.houses:
		for lantern: Dictionary in house.lanterns:
			total += 1
			lit += 1 if lantern.state == LanternRules.LIT else 0
	return Text.f(
		"Lanterns lit: %d of %d · Houses: %d · Bridges: %d · %s",
		[lit, total, (layout.houses as Array).size(), (layout.bridges as Array).size(), SandboxJob.NAMES[town.language]]
	)


func _gremlins() -> Array[String]:
	var dark: Array[String] = []
	for lantern: String in town.lanterns:
		if town.lanterns[lantern] == LanternRules.DARK:
			dark.append(lantern)
	return dark


func _open_letter(id: String) -> void:
	town = LanternRules.open_letter(catalog, town, id)
	_save()
	_open_bench(id, String(catalog.requests[id].module))


func _open_bench(letter: String, module: String) -> void:
	Sound.play("sfx-card-place", 0.6)
	_bench.open(catalog, town, letter, module)
	_bench.visible = true
	_side.visible = false
	_view.modulate = Color(1, 1, 1, 0.25)


func _leave_bench() -> void:
	town.files = _bench.files()
	_save()
	_bench.visible = false
	_side.visible = true
	_view.modulate = Color.WHITE
	_refresh()


## A house clicked in town: its file at the workbench, with the letter that most needs it.
func _on_house(module: String) -> void:
	var letter := ""
	var stands := LanternRules.standing(catalog, town)
	for lantern: String in _gremlins():
		if catalog.requests[stands[lantern]].module == module:
			letter = stands[lantern]
	if letter == "":
		for request in LanternRules.letters(catalog, town):
			if request.module == module and request.id in town.read:
				letter = request.id
				break
	if letter == "":
		for lantern: String in stands:
			if catalog.requests[stands[lantern]].module == module:
				letter = stands[lantern]
	_open_bench(letter, module)


func _run_tests() -> void:
	if _busy or _bench.letter_id == "":
		return
	_busy = true
	town.files = _bench.files()
	_save()
	_bench.set_busy(true)
	var letter := _bench.letter_id
	var language: String = town.language
	var files: Dictionary = (town.files as Dictionary).duplicate()
	var cases := LanternRules.letter_cases(catalog, letter, language)
	var report: Dictionary = await Background.run(func() -> Dictionary: return LanternWatch.run(language, files, cases))
	var outcome := LanternRules.record_run(catalog, town, letter, report.results)
	town = outcome.town
	town.files = _bench.files()
	_save()
	_busy = false
	_bench.set_busy(false)
	_bench.set_town(town)
	_bench.show_results(report, outcome.lit)
	if outcome.lit:
		Sound.cue("cue-treasure")
	else:
		Sound.play("sfx-whiff", 0.6)


func _take_hint() -> void:
	town = LanternRules.take_hint(town, _bench.letter_id)
	_save()
	_bench.set_town(town)


func _restore(module: String) -> void:
	town.files = _bench.files()
	var restored := LanternRules.restore(town, module)
	town = restored.town
	_save()
	_bench.open(catalog, town, _bench.letter_id, module)


func _ring_bell() -> void:
	if _busy or (town.solved as Dictionary).is_empty():
		return
	_busy = true
	_status = ""
	_refresh()
	Sound.play("sfx-turn")
	var language: String = town.language
	var files: Dictionary = (town.files as Dictionary).duplicate()
	var cases := LanternRules.night_cases(catalog, town)
	var report: Dictionary = await Background.run(func() -> Dictionary: return LanternWatch.run(language, files, cases))
	var outcome := LanternRules.night_watch(catalog, town, report.results)
	_side.visible = false
	await _view.play_night(LanternLayout.of(catalog, outcome.town), Settings.reduced_motion)
	town = outcome.town
	_save()
	_busy = false
	_side.visible = true
	_refresh()
	_show_dawn(outcome.report, report)


func _show_dawn(night: Dictionary, report: Dictionary) -> void:
	var box := Ui.vbox([], 10)
	box.add_child(Ui.label(Text.f("NIGHT %d", [int(night.night)]), "Faint"))
	var dark: Array = night.dark
	var title := Text.t("Every lantern held.") if dark.is_empty() else Text.f("%d lanterns went dark.", [dark.size()])
	box.add_child(
		Ui.sized(Ui.tint(Ui.label(title, "Heading", true), UiTheme.PASS if dark.is_empty() else UiTheme.FAIL), 28)
	)
	box.add_child(
		Ui.label(
			Text.f(
				"The Night Watch ran %d tests: %d held, %d failed.",
				[night.passed + night.failed, night.passed, night.failed]
			),
			"",
			true
		)
	)
	for lantern: String in dark:
		var standing: String = LanternRules.standing(catalog, town)[lantern]
		var request: Dictionary = catalog.requests[standing]
		var first_failure := ""
		for result: Dictionary in report.results:
			if String(result.id).get_slice("#", 0) == standing and result.status != "pass":
				first_failure = String(result.call)
				break
		var line := LanternWorkbench.prose(
			Text.f(
				"A gremlin got into `%s`: “%s” no longer works (`%s`).",
				[LanternCode.file_name(request.module, town.language), Text.t(request.title), first_failure]
			)
		)
		line.add_theme_color_override("default_color", UiTheme.FAIL)
		box.add_child(line)
	if not dark.is_empty():
		(
			box
			. add_child(
				(
					Ui
					. label(
						(
							Text
							. t(
								"Something changed in town today and broke code that used to work. That is what a test suite is for."
							)
						),
						"Muted",
						true
					)
				)
			)
		)
	for lantern: String in night.relit:
		box.add_child(
			Ui.tint(
				Ui.label(Text.f("The gremlin left %s.", [Text.t(catalog.requests[lantern].title)]), "", true),
				UiTheme.PASS
			)
		)
	if bool(night.complete):
		box.add_child(
			Ui.sized(Ui.tint(Ui.label(Text.t("The Lantern Festival begins!"), "Heading", true), UiTheme.AMBER), 26)
		)
		(
			box
			. add_child(
				(
					Ui
					. label(
						(
							Text
							. t(
								"Every house, every bridge and every lantern is code you wrote, tested every night. This is a program."
							)
						),
						"",
						true
					)
				)
			)
		)
	elif bool(night.new_day):
		var day := LanternRules.day_info(catalog, int(town.day))
		box.add_child(
			Ui.sized(
				Ui.tint(
					Ui.label(Text.f("Day %d dawns: %s", [int(town.day), Text.t(day.title)]), "Subheading", true),
					UiTheme.AMBER
				),
				20
			)
		)
		box.add_child(Ui.label(Text.t(day.dawn), "Muted", true))
	elif dark.is_empty():
		box.add_child(Ui.label(Text.t("Today's letters are still waiting. The day goes on."), "Muted", true))
	box.add_child(FoundryUi.button(Text.t("Good morning"), _close_modal, true))
	_show_modal(box, 640)
	Sound.cue("cue-victory" if dark.is_empty() else "cue-defeat")


func _show_welcome() -> void:
	var box := Ui.vbox([], 12)
	box.add_child(Ui.label(Text.t("A HAMLET IN THE ROOTS"), "Faint"))
	box.add_child(Ui.sized(Ui.tint(Ui.label(Text.t("Welcome to Lanternroot"), "Heading", true), UiTheme.AMBER), 32))
	for line: String in WELCOME:
		box.add_child(Ui.label(Text.t(line), "", true))
	var languages := Game.languages().filter(func(l: String) -> bool: return l in LanternRules.LANGUAGES)
	if languages.is_empty():
		box.add_child(
			Ui.tint(
				Ui.label(
					Text.t("The sandbox is not installed, so no code can run (scripts/fetch-sandbox.sh)."), "", true
				),
				UiTheme.FAIL
			)
		)
	else:
		box.add_child(Ui.label(Text.t("Which language will your town speak?"), "Subheading"))
		var row := Ui.hbox([], 10)
		for language: String in languages:
			row.add_child(FoundryUi.button(SandboxJob.NAMES[language], start.bind(language), language == languages[0]))
		box.add_child(row)
	box.add_child(FoundryUi.button(Text.t("Back to the surface"), _leave, false, true))
	_show_modal(box, 760)


func _ask_for_house(from_bench: bool) -> void:
	var name_field := LineEdit.new()
	name_field.placeholder_text = "helpers"
	name_field.custom_minimum_size.x = 320
	name_field.add_theme_font_override("font", UiTheme.code_font())
	var problem := Ui.tint(Ui.label("", "Muted", true), UiTheme.FAIL)
	var build := func() -> void:
		if from_bench:
			town.files = _bench.files()
		var added := LanternRules.add_module(town, name_field.text.strip_edges())
		if not added.ok:
			problem.text = Text.t(added.error)
			return
		town = added.town
		_save()
		_close_modal()
		var letter := _bench.letter_id if from_bench else ""
		_open_bench(letter, name_field.text.strip_edges())
	name_field.text_submitted.connect(func(_text: String) -> void: build.call())
	var box := (
		Ui
		. vbox(
			[
				Ui.label(Text.t("A WORKSHOP OF YOUR OWN"), "Faint"),
				Ui.sized(Ui.label(Text.t("Name your new file"), "Heading"), 24),
				Ui.label(
					Text.t("Helpers you write here can be imported by any house. Lowercase letters, digits and _."),
					"Muted",
					true
				),
				name_field,
				problem,
				Ui.hbox(
					[
						FoundryUi.button(Text.t("Build it"), build, true),
						FoundryUi.button(Text.t("Cancel"), _close_modal, false, true)
					],
					8
				),
			],
			10
		)
	)
	_show_modal(box, 560)
	name_field.grab_focus.call_deferred()


func _show_modal(content: Control, width: float) -> void:
	_close_modal()
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(shade)
	var page := FoundryUi.page(content, Vector2(width, 0))
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.add_child(page)
	_modal.add_child(centre)
	var first := page.find_children("*", "Button", true, false)
	if not first.is_empty():
		FoundryUi.focus.call_deferred(first[0] as Control)


func _close_modal() -> void:
	Ui.clear(_modal)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _save() -> void:
	if not town.is_empty():
		_store.save_town(town)


func _leave() -> void:
	if _bench.visible:
		town.files = _bench.files()
		_save()
	Game.go(Game.TITLE)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _modal.get_child_count() > 0 and not town.is_empty():
		_close_modal()
	elif _bench.visible:
		_leave_bench()
	else:
		_leave()
