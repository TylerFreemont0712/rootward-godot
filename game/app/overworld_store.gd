class_name OverworldStore
extends RefCounted
## Lanternroot's overworld on disk (ADR-0061): one file in the profile's folder, `<profile>/overworld.json`, written
## whole after every change the way runs are (SaveStore, LanternStore).

const FILE := "overworld.json"

var root: String


func _init(save_root: String) -> void:
	root = save_root


static func for_profile() -> OverworldStore:
	if Game.profiles != null and not Game.profile.is_empty():
		return OverworldStore.new(Game.profiles.run_root(String(Game.profile.id)))
	var override := OS.get_environment(Game.SAVES_ENV)
	return OverworldStore.new(override if override != "" else SaveStore.ROOT)


func path() -> String:
	return root.path_join(FILE)


## The saved state, or {} when there is none or it cannot be read.
func load_state() -> Dictionary:
	if not FileAccess.file_exists(path()):
		return {}
	var value: Variant = JsJson.parse(FileAccess.get_file_as_string(path()))
	return value if value is Dictionary else {}


func save_state(state: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(root)
	var temporary := path() + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JsJson.stringify(state))
	file.close()
	return DirAccess.rename_absolute(temporary, path())


func delete_state() -> void:
	if FileAccess.file_exists(path()):
		DirAccess.remove_absolute(path())
