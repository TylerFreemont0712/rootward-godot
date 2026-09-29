class_name ProfileStore
extends RefCounted
## Metadata and run folders for local people. SaveStore remains unaware of profiles and takes a root as before.

const ROOT := "user://profiles"

var root: String


func _init(profiles_root := ROOT) -> void:
	root = profiles_root


func run_root(id: String) -> String:
	return root.path_join(id)


func get_profile(id: String) -> Dictionary:
	if id.is_empty() or id.contains("/") or id.contains("\\") or id == "." or id == "..":
		return {}
	var path := run_root(id).path_join("profile.json")
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JsJson.parse(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("id") != id or not value.get("name") is String:
		return {}
	return value


func list_profiles() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(root):
		return found
	for id in DirAccess.get_directories_at(root):
		var profile := get_profile(id)
		if not profile.is_empty():
			found.append(profile)
	return ProfileRules.ordered(found, _active_id())


func active() -> Dictionary:
	var id := _active_id()
	var profile := get_profile(id)
	if not profile.is_empty():
		return profile
	var profiles := list_profiles()
	return profiles[0] if not profiles.is_empty() else {}


func activate(id: String) -> bool:
	var profile := get_profile(id)
	if profile.is_empty():
		return false
	profile.last_played = Time.get_datetime_string_from_system(false, true)
	if not save_profile(profile):
		return false
	return _write_json(root.path_join("active.json"), {"id": id})


func create(name: String, preferred_language := "en", avatar := "vesper") -> Dictionary:
	var names: Array[String] = []
	for profile in list_profiles():
		names.append(String(profile.name))
	var error := ProfileRules.name_error(name, names)
	if error != "":
		return {"ok": false, "error": error}
	var profile := _new_profile(name, preferred_language, avatar)
	if not save_profile(profile):
		return {"ok": false, "error": "Could not save this profile."}
	return {"ok": true, "profile": profile}


static func _new_profile(name: String, preferred_language: String, avatar: String) -> Dictionary:
	var id := "p-" + Crypto.new().generate_random_bytes(8).hex_encode()
	var now := Time.get_datetime_string_from_system(false, true)
	return {
		"id": id,
		"name": ProfileRules.clean_name(name),
		"preferred_language": preferred_language if preferred_language in ["en", "ja"] else "en",
		"avatar": avatar if avatar in Settings.CHARACTER_SKINS else "vesper",
		"created_at": now,
		"last_played": now,
		"settings": {"language": SandboxJob.PYTHON, "difficulty": "beginner"},
		"tutorial": {"trial_done": false, "trial_step": "", "trial_prompted": false},
		"needs_name": false,
	}


func rename(id: String, name: String) -> Dictionary:
	var profile := get_profile(id)
	if profile.is_empty():
		return {"ok": false, "error": "Player not found."}
	var names: Array[String] = []
	for other in list_profiles():
		if other.id != id:
			names.append(String(other.name))
	var error := ProfileRules.name_error(name, names)
	if error != "":
		return {"ok": false, "error": error}
	profile.name = ProfileRules.clean_name(name)
	profile.needs_name = false
	if not save_profile(profile):
		return {"ok": false, "error": "Could not rename this profile."}
	return {"ok": true, "profile": profile}


func save_profile(profile: Dictionary) -> bool:
	var id := String(profile.get("id", ""))
	if id.is_empty() or id.contains("/") or id.contains("\\"):
		return false
	return _write_json(run_root(id).path_join("profile.json"), profile)


func delete(id: String) -> bool:
	if get_profile(id).is_empty():
		return false
	if not _remove_tree(run_root(id)):
		return false
	if _active_id() == id:
		var remaining := list_profiles()
		_write_json(root.path_join("active.json"), {"id": remaining[0].id if not remaining.is_empty() else ""})
	return true


## Copy every legacy file and compare bytes before publishing the profile metadata. The old folder is left intact.
func migrate_legacy(legacy_root: String, language: String, difficulty: String) -> Dictionary:
	if not list_profiles().is_empty():
		return {"ok": false, "error": "Profiles already exist."}
	if not DirAccess.dir_exists_absolute(legacy_root):
		return {"ok": false, "error": "No legacy saves."}
	var files := DirAccess.get_files_at(legacy_root)
	if files.is_empty():
		return {"ok": false, "error": "No legacy saves."}
	var profile := _new_profile("Player 1", "en", "vesper")
	var destination := run_root(profile.id)
	var staged := root.path_join(".migrating-" + String(profile.id))
	if DirAccess.make_dir_recursive_absolute(staged) != OK:
		return {"ok": false, "error": "Could not prepare migration."}
	for file_name in files:
		var source := legacy_root.path_join(file_name)
		var target := staged.path_join(file_name)
		if DirAccess.copy_absolute(source, target) != OK:
			_remove_tree(staged)
			return {"ok": false, "error": "Could not copy migrated saves."}
		if FileAccess.get_file_as_bytes(source) != FileAccess.get_file_as_bytes(target):
			_remove_tree(staged)
			return {"ok": false, "error": "Could not verify migrated saves."}
	profile.needs_name = true
	profile.settings = {"language": language, "difficulty": difficulty}
	profile.migration_root = legacy_root
	profile.migration_files = Array(files)
	profile.migration_verified = false
	if not _write_json(staged.path_join("profile.json"), profile):
		_remove_tree(staged)
		return {"ok": false, "error": "Could not save migrated profile."}
	if DirAccess.rename_absolute(staged, destination) != OK:
		_remove_tree(staged)
		return {"ok": false, "error": "Could not publish migrated profile."}
	activate(profile.id)
	return {"ok": true, "profile": profile}


## Called on a later launch; the source stays untouched even after confirmation.
func confirm_migration(id: String) -> bool:
	var profile := get_profile(id)
	if profile.is_empty() or not profile.has("migration_root"):
		return false
	if profile.get("migration_verified", false):
		return true
	for file_name: String in profile.migration_files:
		var source := String(profile.migration_root).path_join(file_name)
		var target := run_root(id).path_join(file_name)
		if not FileAccess.file_exists(source) or not FileAccess.file_exists(target):
			return false
		# The copied save may have advanced since migration; the initial byte comparison was already recorded.
	profile.migration_verified = true
	return save_profile(profile)


func _active_id() -> String:
	var path := root.path_join("active.json")
	if not FileAccess.file_exists(path):
		return ""
	var value: Variant = JsJson.parse(FileAccess.get_file_as_string(path))
	return String(value.get("id", "")) if value is Dictionary else ""


static func _write_json(path: String, value: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t", false, true))
	file.close()
	return DirAccess.rename_absolute(temporary, path) == OK


static func _remove_tree(path: String) -> bool:
	for file_name in DirAccess.get_files_at(path):
		if DirAccess.remove_absolute(path.path_join(file_name)) != OK:
			return false
	for directory in DirAccess.get_directories_at(path):
		if not _remove_tree(path.path_join(directory)):
			return false
	return DirAccess.remove_absolute(path) == OK
