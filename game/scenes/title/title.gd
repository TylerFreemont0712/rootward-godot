extends Control
## Kernel Foundry's front door: a small launch column over the inhabited lift station, then a departure desk.
## All run launch commands are the existing commands; no battle or descent UI lives here.

const DESIGN := Vector2(1920, 1080)
const HOW_TO: Array[String] = [
	"A shard is a real function. The cards you play, in order, become one program.",
	"Build your program, preview its measured work, then cast it.",
	"Faster foes act before slower programs. Order and complexity matter.",
	"Some shards expect sorted bolts. Sort before you search.",
	"Relics change a run. Guardians test what you have built.",
]

var _canvas: Control
var _menu: Control
var _overlay: Control
var _utilities: HBoxContainer
var _dock: HBoxContainer
var _backdrop: FoundryBackdrop
var _adventure: FoundryAdventurePanel
var _setup := false
var _menu_motion: Tween
var _overlay_motion: Tween
var _archive_transition: ArchivePassage
var _overlay_return: Control
var _focus_modes: Dictionary = {}
var _refresh_adventure := false


func _ready() -> void:
	theme = FoundryUi.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content_ok := Game.boot()
	var ground := ColorRect.new()
	ground.color = UiTheme.GROUND
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	_canvas = Control.new()
	_canvas.size = DESIGN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_backdrop = FoundryBackdrop.new()
	_backdrop.size = DESIGN
	_canvas.add_child(_backdrop)
	_menu = Control.new()
	_menu.size = DESIGN
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_menu)
	_overlay = Control.new()
	_overlay.size = DESIGN
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build(content_ok)
	_canvas.add_child(_overlay)
	resized.connect(_fit)
	_fit()
	Sound.music("music-title")
	if Game.profile.get("needs_name", false):
		call_deferred("_edit_profile", String(Game.profile.id), true)


func _fit() -> void:
	var fit := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_canvas.scale = Vector2.ONE * fit
	_canvas.position = (size - DESIGN * fit) * 0.5


func _text(english: String, japanese: String) -> String:
	return FoundryUi.text(english, japanese)


func _build(content_ok: bool) -> void:
	Ui.clear(_menu)
	_adventure = null
	_chrome()
	if not content_ok:
		FoundryUi.place(_menu, _broken(), Rect2(104, 200, 810, 0))
	elif _setup:
		_adventure = FoundryAdventurePanel.make()
		_adventure.closed.connect(_show_home)
		_adventure.character_requested.connect(_open_skins)
		_adventure.records_requested.connect(_open_git_log.bind(Game.session.saves.load_history()))
		_adventure.help_requested.connect(_open_how_to)
		_adventure.start_requested.connect(
			func(sandbox: bool) -> void:
				if sandbox:
					_start_sandbox()
				else:
					_start()
		)
		_adventure.continue_requested.connect(_continue)
		_adventure.trial_requested.connect(_start_trial)
		var departure := Ui.scroll(_adventure)
		FoundryUi.place(_menu, departure, Rect2(104, 220, 700, 480))
	else:
		_home()
	_reveal()


func _chrome() -> void:
	# LEARN: locale buttons rebuild their own parent inside pressed. Detach now, free after signal dispatch.
	for old: HBoxContainer in [_utilities, _dock]:
		if is_instance_valid(old):
			_canvas.remove_child(old)
			old.queue_free()
	var profile := FoundryUi.button(String(Game.profile.get("name", "Player")), _open_profiles, false, true)
	profile.custom_minimum_size.x = 220
	profile.clip_text = true
	profile.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	profile.tooltip_text = profile.text
	_utilities = (
		Ui
		. hbox(
			[
				profile,
				FoundryUi.button("EN", _set_locale.bind("en"), false, true),
				FoundryUi.button("日本語", _set_locale.bind("ja"), false, true),
				FoundryUi.button(_text("Quit", "おわる"), Game.quit, false, true),
			],
			8
		)
	)
	_utilities.position = Vector2(1250, 46)
	_canvas.add_child(_utilities)
	_dock = (
		Ui
		. hbox(
			[
				FoundryUi.icon_button("library", _text("Library", "図鑑"), _open_archive, false, true),
				FoundryUi.icon_button("character", _text("Character", "キャラクター"), _open_skins, false, true),
				FoundryUi.icon_button("settings", _text("Settings", "設定"), _open_options, false, true),
			],
			18
		)
	)
	_dock.position = Vector2(104, 980 if _setup else 952)
	_canvas.add_child(_dock)
	# Rebuilding chrome must keep it below any open modal.
	if _overlay.get_parent() == _canvas:
		_canvas.move_child(_overlay, -1)


func _home() -> void:
	var eyebrow := Ui.label(_text("THE SURFACE STATION", "地上の駅"), "Faint")
	FoundryUi.place(_menu, eyebrow, Rect2(104, 116, 580, 24))
	var logo := Art.texture("menus/rootward-wordmark")
	if logo != null:
		var crop := FoundryUi.wordmark(logo)
		var wordmark := TextureRect.new()
		wordmark.texture = crop
		wordmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wordmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wordmark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		FoundryUi.place(_menu, wordmark, Rect2(98, 150, 532, 108))
	else:
		FoundryUi.place(_menu, Ui.sized(Ui.label("ROOTWARD", "Title"), 112), Rect2(104, 146, 550, 118))
	FoundryUi.place(
		_menu,
		Ui.label(_text("Program the spell.\nDescend into the machine.", "呪文をプログラムしよう。\n機械の奥へ、降りていこう。"), "Narration"),
		Rect2(104, 290, 550, 68)
	)
	var underway := Game.session.in_progress() and Settings.playstyle != "verifier"
	var resume := FoundryUi.button(
		_text("↓  Resume descent", "↓  冒険のつづき"), _continue if underway else _show_setup, true
	)
	resume.text = resume.text if underway else _text("↓  Begin your descent", "↓  冒険を始める")
	FoundryUi.place(_menu, resume, Rect2(104, 418, 400, 56))
	FoundryUi.focus.call_deferred(resume)
	var note := _text("The lift is ready when you are.", "準備ができたら、リフトへ。")
	if underway:
		note = (
			"%s · %s · %s"
			% [
				Game.PLAYSTYLES[Settings.playstyle],
				ShardrunRules.layer_of(Game.session.state, Game.session.catalog).name,
				String(Game.session.state.language).capitalize()
			]
		)
	FoundryUi.place(_menu, Ui.label(note, "Muted", true), Rect2(104, 492, 540, 54))
	var launches := (
		Ui
		. hbox(
			[
				FoundryUi.icon_button("adventure", _text("Adventure", "冒険"), _show_setup, true),
				FoundryUi.icon_button("academy", _text("Academy", "アカデミー"), _open_academy),
			],
			18
		)
	)
	FoundryUi.place(_menu, launches, Rect2(104, 572, 455, 52))
	FoundryUi.place(
		_menu,
		Ui.label(_text("SALVAGE  →  HEAP  →  KERNEL", "サルベージ  →  ヒープ  →  カーネル"), "Faint"),
		Rect2(104, 885, 560, 24)
	)
	FoundryUi.place(_menu, FoundryUi.rule(), Rect2(104, 934, 545, 1))
	FoundryUi.place(
		_menu,
		Ui.label(_text("Tab · Select    Enter · Confirm    Esc · Back", "Tab · 移動    Enter · 選択    Esc · 戻る"), "Faint"),
		Rect2(1240, 1002, 620, 25)
	)


func _show_setup() -> void:
	if Settings.playstyle == "verifier":
		Game.use("program")
	_setup = true
	_build(true)


func _show_home() -> void:
	_setup = false
	_build(true)


func _reveal() -> void:
	if _menu_motion != null:
		_menu_motion.kill()
	_menu.modulate.a = 1.0
	if not Settings.reduced_motion:
		_menu.modulate.a = 0.0
		_menu_motion = create_tween()
		_menu_motion.tween_property(_menu, "modulate:a", 1.0, 0.24)


func _continue() -> void:
	if Game.session.in_progress():
		Game.trial_active = false
		Game.go(Game.SHARDRUN)
	else:
		_show_setup()


func _open_archive() -> void:
	var library := FoundryLibraryPanel.make(Game.display_catalog())
	library.closed.connect(_close_overlay)
	_show_overlay(library, true)


func _open_options() -> void:
	var options := FoundrySettingsPanel.make()
	options.closed.connect(_close_overlay)
	options.changed.connect(_backdrop.apply_motion)
	_show_overlay(options)


func _open_skins() -> void:
	var character := FoundryCharacterPanel.make()
	character.closed.connect(_close_overlay)
	character.skin_selected.connect(
		func(_id: String) -> void:
			_backdrop.refresh_skin()
			_refresh_adventure = _setup
	)
	_show_overlay(character)


func _open_academy() -> void:
	var column := Ui.vbox(
		[
			FoundryUi.heading("ACADEMY / THE LEARNING WORKSHOP", _text("A place to grow", "学びを育てる場所"), _close_overlay),
			FoundryUi.rule()
		],
		8
	)
	column.add_child(Ui.tint(Ui.label(_text("IN PREPARATION", "準備中"), "Faint"), UiTheme.AMBER))
	column.add_child(Ui.sized(Ui.label(_text("The workbench is taking shape.", "学びの工房を準備しているよ。"), "Heading", true), 22))
	column.add_child(
		Ui.label(
			_text(
				"A separate journey into programming, at your own pace. Lessons, practice and projects will live here.",
				"自分のペースでプログラミングを学ぶ、もうひとつの旅。レッスンや練習、プロジェクトをここに用意するよ。"
			),
			"Muted",
			true
		)
	)
	var paths := [
		[_text("Read & trace", "読む・追う"), _text("Follow an idea, one step at a time.", "一歩ずつ、考えの流れを追う。")],
		[_text("Build & test", "作る・試す"), _text("Turn a small problem into working code.", "小さな問題を、動くコードにする。")],
		[
			_text("Explore & improve", "探る・磨く"),
			_text("Find another way. Understand the difference.", "別の方法を見つけ、その違いを知る。")
		],
	]
	var plans := Ui.hbox([], 8)
	for i in paths.size():
		var card := Ui.panel(
			Ui.vbox(
				[
					Ui.label("0%d" % (i + 1), "Faint"),
					Ui.label(paths[i][0], "Subheading", true),
					Ui.label(paths[i][1], "Muted", true)
				],
				6
			),
			"Card"
		)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plans.add_child(card)
	column.add_child(plans)
	var existing := FoundryUi.button(
		_text("Open existing Verifier course", "今あるコード読解コースを開く"), func() -> void: Game.go(Game.VERIFIER), false, true
	)
	existing.disabled = not Sandbox.is_available(SandboxJob.JAVASCRIPT)
	column.add_child(Ui.hbox([existing]))
	_show_overlay(FoundryUi.page(column, Vector2(700, 430)))


func _open_profiles() -> void:
	var column := Ui.vbox(
		[
			FoundryUi.heading("LOCAL PLAYERS", _text("Who is at the station?", "駅にいるのはだれ？"), _close_overlay),
			FoundryUi.rule()
		],
		12
	)
	for player: Dictionary in Game.profiles.list_profiles():
		var id := String(player.id)
		var choose := func() -> void:
			if Game.select_profile(id):
				get_tree().reload_current_scene.call_deferred()
		var selected: bool = id == Game.profile.get("id", "")
		column.add_child(
			FoundryUi.action(
				String(player.name),
				_text("Current player", "今のプレイヤー") if selected else _text("Return to their journeys", "このプレイヤーの旅に戻る"),
				choose,
				selected
			)
		)
	column.add_child(
		Ui.hbox(
			[
				FoundryUi.button(_text("New player", "新しいプレイヤー"), func() -> void: _edit_profile(), true),
				FoundryUi.button(_text("Rename", "名前を変える"), func() -> void: _edit_profile(String(Game.profile.id))),
				FoundryUi.button(_text("Delete", "消す"), _confirm_delete_profile),
			],
			12
		)
	)
	_show_overlay(FoundryUi.page(column, Vector2(590, 0)))


func _set_locale(locale: String) -> void:
	Game.profile.preferred_language = locale
	Game.profiles.save_profile(Game.profile)
	TranslationServer.set_locale(locale)
	_build(true)


func _edit_profile(id := "", required := false) -> void:
	var panel := ProfilePanel.editor(
		id, required, func() -> void: get_tree().reload_current_scene.call_deferred(), _close_overlay
	)
	panel.custom_minimum_size.x = 370
	for input: Node in panel.find_children("*", "LineEdit", true, false):
		(input as Control).custom_minimum_size.x = 280
	_show_overlay(panel)


func _confirm_delete_profile() -> void:
	_show_overlay(
		ProfilePanel.delete_confirmation(
			func() -> void: get_tree().reload_current_scene.call_deferred(), _close_overlay
		)
	)


func _open_git_log(history: Array[Dictionary]) -> void:
	var records := FoundryRecordsPanel.make(history)
	records.closed.connect(_close_overlay)
	records.commit_log_requested.connect(_open_commit_log.bind(history))
	_show_overlay(records)


func _open_commit_log(history: Array[Dictionary]) -> void:
	var view := GitLogView.create(history)
	view.custom_minimum_size.x = 700
	for scroll: Node in view.find_children("*", "ScrollContainer", true, false):
		(scroll as Control).custom_minimum_size.y = 350
	var hint := view.get_child(0).get_child(2) as Label
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 40
	view.closed.connect(_close_overlay)
	_show_overlay(view)


func _open_how_to() -> void:
	var column := Ui.vbox(
		[FoundryUi.heading("THE FIELD GUIDE", _text("Before you descend", "降りる前に"), _close_overlay), FoundryUi.rule()],
		8
	)
	column.add_child(
		Ui.label(
			_text(
				(
					"Under the station lies the Salvage: old programs, broken into shards. "
					+ "Chain them into spells and find your way down."
				),
				"駅の下にはサルベージがある。古いプログラムはシャードに砕けた。呪文に組み合わせて、下へ続く道を探そう。"
			),
			"Narration",
			true
		)
	)
	for i in HOW_TO.size():
		column.add_child(Ui.hbox([Ui.label("0%d" % (i + 1), "Faint"), Ui.expand(Ui.label(HOW_TO[i], "", true))], 12))
	column.add_child(FoundryUi.button(_text("Travel with Pip", "ピップと旅する"), _start_trial, true))
	_show_overlay(FoundryUi.page(column, Vector2(650, 0)))


func _show_overlay(panel: Control, library_room := false) -> void:
	if is_instance_valid(_archive_transition):
		panel.queue_free()
		return
	if _overlay_motion != null:
		_overlay_motion.kill()
	if _overlay.get_child_count() == 0:
		_overlay_return = get_viewport().gui_get_focus_owner()
		_freeze_navigation()
	Ui.clear(_overlay)
	_overlay.modulate.a = 1.0
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.GROUND, 0.62)
	dim.size = DESIGN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = not library_room
	_overlay.add_child(dim)
	var page: Control = FoundryLibraryRoom.make(panel) if library_room else Ui.centered_scroll(panel)
	page.size = DESIGN
	_overlay.add_child(page)
	_canvas.move_child(_overlay, -1)
	if library_room and not Settings.reduced_motion:
		page.hide()
		_archive_passage(page.show, _focus_first.bind(panel))
		return
	if not library_room and not Settings.reduced_motion:
		page.modulate.a = 0.0
		_overlay_motion = create_tween()
		_overlay_motion.tween_property(page, "modulate:a", 1.0, 0.2)
	# LEARN: a page can close before deferred focus runs; capture it in a checked closure, not a typed deferred argument.
	var pending_focus: WeakRef = weakref(panel)
	(
		(func() -> void:
			var target := pending_focus.get_ref() as Control
			if target != null:
				_focus_first(target))
		. call_deferred()
	)


func _close_overlay() -> void:
	if is_instance_valid(_archive_transition):
		return
	if _overlay.get_child_count() == 0:
		return
	if _overlay_motion != null:
		_overlay_motion.kill()
	if Settings.reduced_motion:
		_finish_close()
	else:
		if _overlay.get_child(1) is FoundryLibraryRoom:
			_archive_passage(_finish_close.bind(false), _restore_navigation)
			return
		_overlay_motion = create_tween()
		_overlay_motion.tween_property(_overlay, "modulate:a", 0.0, 0.12)
		_overlay_motion.tween_callback(_finish_close)


func _archive_passage(midpoint: Callable, finished: Callable) -> void:
	_archive_transition = ArchivePassage.new()
	_canvas.add_child(_archive_transition)
	_archive_transition.grab_focus()
	_archive_transition.midpoint.connect(midpoint, CONNECT_ONE_SHOT)
	_archive_transition.finished.connect(
		func() -> void:
			# LEARN: the veil still emits finished here; detach it now and free after signal dispatch.
			_canvas.remove_child(_archive_transition)
			_archive_transition.queue_free()
			_archive_transition = null
			finished.call(),
		CONNECT_ONE_SHOT
	)
	_archive_transition.play()


func _finish_close(restore_navigation := true) -> void:
	Ui.clear(_overlay)
	_overlay.modulate.a = 1.0
	if restore_navigation:
		_restore_navigation()


func _restore_navigation() -> void:
	for id: int in _focus_modes:
		var control := instance_from_id(id) as Control
		if is_instance_valid(control):
			control.focus_mode = _focus_modes[id]
	_focus_modes.clear()
	if _refresh_adventure and is_instance_valid(_adventure):
		_adventure.refresh()
		_refresh_adventure = false
	if is_instance_valid(_overlay_return) and _overlay_return.is_inside_tree():
		_overlay_return.grab_focus()
	else:
		_focus_first(_menu)


func _freeze_navigation() -> void:
	for root: Control in [_menu, _utilities, _dock]:
		for node: Node in root.find_children("*", "Control", true, false):
			var control := node as Control
			if control.focus_mode != Control.FOCUS_NONE:
				_focus_modes[control.get_instance_id()] = control.focus_mode
				control.focus_mode = Control.FOCUS_NONE


func _focus_first(root: Control) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree():
		return
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(_archive_transition):
			get_viewport().set_input_as_handled()
			return
		if _overlay.get_child_count() > 0:
			_close_overlay()
		elif _setup:
			_show_home()
		get_viewport().set_input_as_handled()


func _broken() -> Control:
	var column := Ui.vbox(
		[Ui.tint(Ui.label("The content has errors, so a run cannot start.", "Subheading"), UiTheme.FAIL)], 14
	)
	for diagnostic: Dictionary in Game.diagnostics.slice(0, 12):
		column.add_child(Ui.label(ContentLoader.describe(diagnostic), "Muted", true))
	return FoundryUi.page(column, Vector2(800, 0))


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
	if Game.profile.get("needs_name", false):
		_edit_profile(String(Game.profile.id), true)
		return
	_launch_run(sandbox)


func _launch_run(sandbox: bool) -> void:
	Game.trial_active = false
	var difficulties: Array = Game.catalog.config.difficulties
	var known := difficulties.any(func(d: Dictionary) -> bool: return d.id == Settings.difficulty)
	Game.session.start(Settings.language, Settings.difficulty if known else String(difficulties[0].id), "", sandbox)
	Game.go(Game.SHARDRUN)


func _start_trial() -> void:
	if Game.profile.get("needs_name", false):
		_edit_profile(String(Game.profile.id), true)
		return
	var active: bool = Game.trial_session.has_run() and not Game.trial_session.state.get("trial", {}).get("done", false)
	if Game.resume_trial() if active else Game.start_trial():
		Game.go(Game.SHARDRUN)


func _confirm_new_run(sandbox: bool) -> void:
	var text := "Starting anew replaces the run underway. Your Verifier course progress is saved separately."
	var yes := Ui.button("Start anew", _begin.bind(sandbox), "DangerButton")
	var no := Ui.button("Keep the run", _close_overlay, "PrimaryButton")
	var panel := Ui.panel(
		Ui.vbox([Ui.label("Start a new run?", "Heading"), Ui.label(text, "", true), Ui.hbox([no, yes])], 14), "Overlay"
	)
	panel.custom_minimum_size = Vector2(520, 0)
	_show_overlay(panel)
