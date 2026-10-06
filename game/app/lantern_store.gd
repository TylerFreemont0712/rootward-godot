class_name LanternStore
extends RefCounted
## Lanternroot's towns on disk, one per language, in the profile's own folder (ADR-0055):
## `<profile>/lanternroot-python.json`. A town is written whole after every change, the way runs are (SaveStore).

var root: String


func _init(save_root: String) -> void:
	root = save_root


## The store for the active profile, or for the legacy save folder when there is no profile (a test, a screenshot).
static func for_profile() -> LanternStore:
	if Game.profiles != null and not Game.profile.is_empty():
		return LanternStore.new(Game.profiles.run_root(String(Game.profile.id)))
	var override := OS.get_environment(Game.SAVES_ENV)
	return LanternStore.new(override if override != "" else SaveStore.ROOT)


func path_for(language: String) -> String:
	return root.path_join("lanternroot-%s.json" % language)


## The saved town in `language`, or {} when there is none or it cannot be read.
func load_town(language: String) -> Dictionary:
	var path := path_for(language)
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JsJson.parse(FileAccess.get_file_as_string(path))
	if not value is Dictionary or int((value as Dictionary).get("version", 0)) != LanternRules.VERSION:
		return {}
	var town := LanternRules.new_town(language)
	town.merge(value, true)
	return town


func save_town(town: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(root)
	var path := path_for(String(town.language))
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JsJson.stringify(town))
	file.close()
	return DirAccess.rename_absolute(temporary, path)


func delete_town(language: String) -> void:
	if FileAccess.file_exists(path_for(language)):
		DirAccess.remove_absolute(path_for(language))


## The languages with a saved town, so the gate can offer "continue".
func languages() -> Array[String]:
	var found: Array[String] = []
	for language in LanternRules.LANGUAGES:
		if FileAccess.file_exists(path_for(language)):
			found.append(language)
	return found
