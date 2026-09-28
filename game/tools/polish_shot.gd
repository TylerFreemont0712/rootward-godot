extends Control
## Repeatable title/Archives/options captures. Isolated saves; ROOTWARD_POLISH chooses the page.

signal shot_ready


func _ready() -> void:
	Game.reset("user://polish-shot-saves")
	Game.boot()
	Settings.reduced_motion = true
	var title: Control = (load(Game.TITLE) as PackedScene).instantiate()
	add_child(title)
	for i in 4:
		await get_tree().process_frame
	match OS.get_environment("ROOTWARD_POLISH"):
		"archive", "relics", "glossary":
			title.call("_open_archive")
			var archives := title.find_children("*", "ArchivePanel", true, false)
			var archive := archives[0] as ArchivePanel
			var page := OS.get_environment("ROOTWARD_POLISH")
			if page == "archive":
				archive.set("_query", "constant")
			else:
				archive.set("_kind", page)
			archive.call("_rebuild")
		"options":
			title.call("_open_options")
		"setup":
			title.call("_show_setup")
	for i in 6:
		await get_tree().process_frame
	set_meta("shot_ready", true)
	shot_ready.emit()
