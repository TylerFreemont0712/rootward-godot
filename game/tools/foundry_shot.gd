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
	Settings.reduced_motion = moment != "motion"
	if moment == "resume":
		Game.session.start("javascript", "beginner", "foundry-review")
	var title := (load(Game.TITLE) as PackedScene).instantiate()
	add_child(title)
	for i in 4:
		await get_tree().process_frame
	match moment.trim_suffix("-ja"):
		"adventure":
			title.call("_show_setup")
		"settings":
			title.call("_open_options")
		"audio":
			title.call("_open_options")
			var panel := _panel(title, "FoundrySettingsPanel")
			panel.set("_tab", "Audio")
			panel.call("_rebuild")
		"character":
			title.call("_open_skins")
		"academy":
			title.call("_open_academy")
		"library", "foes":
			title.call("_open_archive")
			if moment == "foes":
				var panel := _panel(title, "FoundryLibraryPanel")
				panel.set("_kind", "foes")
				panel.call("_rebuild")
		"records":
			title.call("_open_git_log", Game.session.saves.load_history())
		"profiles":
			title.call("_open_profiles")
	for i in 6:
		await get_tree().process_frame
	set_meta("shot_ready", true)
	shot_ready.emit()


static func _panel(root: Node, wanted: String) -> Control:
	for child: Node in root.find_children("*", "", true, false):
		if child.get_script() != null and child.get_script().get_global_name() == wanted:
			return child as Control
	return null
