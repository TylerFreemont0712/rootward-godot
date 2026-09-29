extends Control
## Repeatable title/Archives/options captures. Isolated saves; ROOTWARD_POLISH chooses the page.

signal shot_ready


func _ready() -> void:
	var moment := OS.get_environment("ROOTWARD_POLISH")
	Game.reset("user://polish-shot-saves/" + (moment if moment != "" else "title"))
	Game.boot()
	var named_moments := [
		"profiles",
		"profile-rename",
		"profile-delete",
		"profile-ja",
		"trial-title",
		"trial-title-ja",
		"trial-prompt",
		"trial-prompt-ja"
	]
	if moment in named_moments:
		var first_id := String(Game.profile.id)
		var japanese_id := ""
		for player: Dictionary in Game.profiles.list_profiles():
			if player.name == "Joe":
				first_id = String(player.id)
			if player.name == "ゆき":
				japanese_id = String(player.id)
		if Game.profile.name != "Joe" and first_id == Game.profile.id:
			var renamed := Game.profiles.rename(first_id, "Joe")
			if renamed.ok:
				first_id = String(renamed.profile.id)
		if japanese_id == "":
			var japanese := Game.profiles.create("ゆき", "ja", "vesper")
			if japanese.ok:
				japanese_id = String(japanese.profile.id)
		Game.profiles.create("Guest")
		if moment in ["profile-ja", "trial-title-ja", "trial-prompt-ja"]:
			Game.select_profile(japanese_id)
		else:
			Game.select_profile(first_id)
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
		"trial-prompt", "trial-prompt-ja":
			title.call("_offer_trial")
	for i in 6:
		await get_tree().process_frame
	set_meta("shot_ready", true)
	shot_ready.emit()
