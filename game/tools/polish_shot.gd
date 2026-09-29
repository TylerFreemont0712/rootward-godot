extends Control
## Repeatable title/Archives/options captures. Isolated saves; ROOTWARD_POLISH chooses the page.

signal shot_ready


func _ready() -> void:
	var moment := OS.get_environment("ROOTWARD_POLISH")
	Game.reset("user://polish-shot-saves/" + (moment if moment != "" else "title"))
	Game.boot()
	if moment in ["profiles", "profile-rename", "profile-delete", "profile-ja"]:
		var first := Game.profiles.rename(String(Game.profile.id), "Joe")
		if first.ok:
			Game.select_profile(String(first.profile.id))
		var japanese := Game.profiles.create("ゆき", "ja", "vesper")
		Game.profiles.create("Guest")
		if moment == "profile-ja":
			Game.select_profile(String(japanese.profile.id))
		else:
			Game.select_profile(String(first.profile.id))
	Settings.reduced_motion = true
	var title: Control = (load(Game.TITLE) as PackedScene).instantiate()
	add_child(title)
	for i in 4:
		await get_tree().process_frame
	match moment:
		"archive", "relics", "glossary", "shards":
			title.call("_open_archive")
			var archives := title.find_children("*", "ArchivePanel", true, false)
			var archive := archives[0] as ArchivePanel
			var page := OS.get_environment("ROOTWARD_POLISH")
			if page == "archive":
				archive.set("_query", "constant")
			elif page == "shards":
				archive.set("_mode", "spellbook")
				archive.set("_kind", "cards")
				archive.set("_selected", "adapt")
			else:
				archive.set("_kind", page)
			archive.call("_rebuild")
		"options":
			title.call("_open_options")
		"setup":
			title.call("_show_setup")
		"profile-rename":
			title.call("_edit_profile", String(Game.profile.id))
		"profile-delete":
			title.call("_confirm_delete_profile")
	for i in 6:
		await get_tree().process_frame
	set_meta("shot_ready", true)
	shot_ready.emit()
