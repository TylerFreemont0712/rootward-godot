extends Control
## Repeatable front-end captures, with named profiles and saves isolated from the player's journeys.

signal shot_ready


func _ready() -> void:
	var moment := OS.get_environment("ROOTWARD_MENU")
	Game.reset("user://foundry-shot-saves/" + (moment if moment != "" else "home"))
	Game.boot()
	Game.profile.name = "Mira"
	Game.profile.needs_name = false
	Game.profile.preferred_language = "ja" if moment.ends_with("-ja") else "en"
	Game.profile.avatar = "vesper"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	Game.use("program")
	Settings.font_style = OS.get_environment("ROOTWARD_FONT")
	if not UiFonts.CHOICES.has(Settings.font_style):
		Settings.font_style = Settings.DEFAULT_FONT
	UiTheme.refresh_fonts()
	Settings.reduced_motion = not moment in ["motion", "library-transition"]
	if moment in ["resume", "adventure-resume"]:
		Game.session.start("javascript", "beginner", "foundry-review")
	var title := (load(Game.TITLE) as PackedScene).instantiate()
	add_child(title)
	for i in 4:
		await get_tree().process_frame
	match moment.trim_suffix("-ja"):
		"adventure", "adventure-resume":
			title.call("_show_setup")
		"pip":
			title.call("_show_setup")
			var panel := _panel(title, "FoundryAdventurePanel")
			panel.set("_tab", "pip")
			panel.call("_rebuild")
		"settings":
			title.call("_open_options")
		"audio", "settings-battle", "settings-fonts":
			title.call("_open_options")
			var panel := _panel(title, "FoundrySettingsPanel")
			panel.set(
				"_tab",
				(
					"Audio"
					if moment == "audio"
					else ("Fonts" if moment.trim_suffix("-ja") == "settings-fonts" else "Battle")
				)
			)
			panel.call("_rebuild")
		"character", "character-spells", "character-dummy", "character-moves", "character-circle", "character-weave":
			title.call("_open_skins")
			var base := moment.trim_suffix("-ja")
			var panel := _panel(title, "FoundryCharacterPanel") as FoundryCharacterPanel
			if base in ["character-dummy", "character-moves", "character-weave"]:
				var wanted := OS.get_environment("ROOTWARD_SHOT_SKIN")
				if wanted == "":
					wanted = "dummy"
				for i in panel._looks.size():
					if panel._looks[i].id == wanted:
						panel._at = i
				panel._arrange(false)
			for i in 4:
				await get_tree().process_frame
			var rehearsal := panel.rehearsal
			var at := (
				float(OS.get_environment("ROOTWARD_SHOT_AFTER_MS")) / 1000.0
				if OS.get_environment("ROOTWARD_SHOT_AFTER_MS")
				else 1.6
			)
			if base == "character-weave":
				Settings.reduced_motion = false
				panel._tab = "Moves"
				panel._move_slot = "cast_heavy"
				rehearsal.set_look("cast_heavy", "shard-weave")
				panel._build_controls()
				panel._show_look()
				rehearsal.shards = 6
				rehearsal.heavy = true
				rehearsal.test_cast()
			elif base == "character-moves":
				panel._tab = "Moves"
				panel._move_slot = "cast_heavy"
				panel._build_controls()
				rehearsal.set_look("cast_heavy", "skyward-call")
				panel._carousel.at = 1
				panel._carousel.arrange(false)
				panel._show_look()
				rehearsal.test_cast(3)
			elif base == "character-spells":
				panel._tab = "Spells"
				panel._spell_slot = "impact"
				panel._build_controls()
				rehearsal.set_look("impact", "root-eruption")
				rehearsal.set_look("circle", "rootglass")
				panel._carousel.at = 2
				panel._carousel.arrange(false)
				panel._show_look()
				rehearsal.element = "frost"
				rehearsal.set_targets(3)
				rehearsal.test_cast(3)
			elif base == "character-circle":
				panel._tab = "Spells"
				panel._spell_slot = "circle"
				panel._build_controls()
				rehearsal.set_look("circle", "clockwork")
				panel._carousel.at = 2
				panel._carousel.arrange(false)
				panel._show_look()
				# ROOTWARD_SHARDS (1..6) picks the practice spell's shards: the layers of its circle (ADR-0039).
				rehearsal.shards = (
					clampi(int(OS.get_environment("ROOTWARD_SHARDS")), 1, 6)
					if OS.has_environment("ROOTWARD_SHARDS")
					else 6
				)
				rehearsal.element = (
					OS.get_environment("ROOTWARD_ELEMENT") if OS.has_environment("ROOTWARD_ELEMENT") else "spark"
				)
				rehearsal.preview_circle()
			if base != "character" and base != "character-dummy":
				await get_tree().create_timer(at).timeout
				rehearsal.set_paused(true)
		"academy":
			title.call("_open_academy")
		"library", "library-transition", "foes", "bosses", "boss-root", "boss-heap", "library-relics", "library-spellforge":
			title.call("_open_archive")
			if moment == "library-transition":
				await get_tree().create_timer(0.46).timeout
				var passage := title.get("_archive_transition") as ArchivePassage
				(passage.get("_motion") as Tween).kill()
				passage.call("_advance", 0.73)
			elif moment.trim_suffix("-ja") != "library":
				var panel := _panel(title, "FoundryLibraryPanel")
				var kind := "foes" if moment == "foes" else "bosses"
				if moment == "library-relics":
					kind = "relics"
				elif moment == "library-spellforge":
					kind = "cards"
					panel.set("_mode", "spellbook")
				panel.set("_kind", kind)
				if moment == "boss-root":
					panel.set("_layer", "root")
					panel.set("_selected", "the-quine")
				elif moment == "boss-heap":
					panel.set("_layer", "heap")
					panel.set("_selected", "page-fault-a")
				panel.call("_rebuild")
		"records":
			title.call("_open_git_log", Game.session.saves.load_history())
		"profiles":
			title.call("_open_profiles")
		"profile-edit":
			title.call("_edit_profile", String(Game.profile.id))
		"guide":
			title.call("_open_how_to")
		"commit-log":
			title.call("_open_commit_log", Game.session.saves.load_history())
	for i in 6:
		await get_tree().process_frame
	set_meta("shot_ready", true)
	shot_ready.emit()


static func _panel(root: Node, wanted: String) -> Control:
	for child: Node in root.find_children("*", "", true, false):
		if child.get_script() != null and child.get_script().get_global_name() == wanted:
			return child as Control
	return null
