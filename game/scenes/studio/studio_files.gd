class_name StudioFiles
extends RefCounted
## Lanternroot Studio's file access (ADR-0066, Concept/v0.3/10 section 9.1): the only code that touches files for the
## Studio. It reads content, keeps drafts and backups under user://studio/, and writes content files when Publish asks
## (write_content). Everything else in the Studio is pure (game/core/studio/) and never reaches the disk.
##
##   if StudioFiles.can_write():
##       var text := StudioFiles.read_text(path)
##       var parsed := StudioDoc.parse(path, "map", text)
##       StudioFiles.save_draft(parsed["doc"], text)
##
## Content paths are "res://" paths, named the way ContentLoader names them.

const DRAFTS := "user://studio/drafts/"
const BACKUPS := "user://studio/backups/"
## The file that proves a content folder is writable. It is created and removed again at once.
const PROBE_NAME := ".studio_write_probe"
const DRAFT_SUFFIX := ".json"


## Whether content can be written here: false in an exported build (OS.has_feature("template")), else true when a
## probe file can be created and removed in `content_root`.
static func can_write(content_root := ContentLoader.ROOT) -> bool:
	if OS.has_feature("template"):
		return false
	var probe := content_root.path_join(PROBE_NAME)
	var file := FileAccess.open(probe, FileAccess.WRITE)
	if file == null:
		return false
	file.close()
	return DirAccess.remove_absolute(probe) == OK


## Where a content file's draft lives: drafts_dir + the path without "res://", "/" replaced by "__", + ".json".
## "res://content/packs/core/overworld/maps/home.jsonc"
##   -> drafts_dir + "content__packs__core__overworld__maps__home.jsonc.json"
static func draft_path(content_path: String, drafts_dir := DRAFTS) -> String:
	var name := content_path.trim_prefix("res://").replace("/", "__")
	return drafts_dir.path_join(name + DRAFT_SUFFIX)


## Saves a doc as a draft: JSON with file, kind, header, base_hash, base_text, data, sids, next_sid and saved_at.
## `base_text` is the text the doc was parsed from. Creates the folder. True when written.
static func save_draft(doc: StudioDoc, base_text: String, drafts_dir := DRAFTS, base_sids: Array[int] = []) -> bool:
	if DirAccess.make_dir_recursive_absolute(drafts_dir) != OK:
		return false
	return _write_atomic(draft_path(doc.path, drafts_dir), draft_text(doc, base_text, base_sids))


## The exact serialized draft record, also used to stage a multi-document transaction before any session changes.
static func draft_text(doc: StudioDoc, base_text: String, base_sids: Array[int] = []) -> String:
	var draft := {
		"file": doc.path,
		"kind": doc.kind,
		"header": doc.header,
		"base_hash": doc.base_hash,
		"base_text": base_text,
		"data": doc.data,
		"sids": doc.sids,
		"next_sid": doc.next_sid,
		"saved_at": Time.get_datetime_string_from_system(),
	}
	if not base_sids.is_empty():
		draft["base_sids"] = base_sids
	# LEARN: JSON.stringify sorts keys by default and writes floats with 6 digits. The map writer takes its key order
	# from the data, so a draft must keep the order (sort_keys false) and every float (full_precision true).
	return JSON.stringify(draft, "\t", false, true)


## The draft of a content file as {ok: true, doc, base_text, saved_at}, or {ok: false} when there is none or it cannot
## be read. The sids and next_sid come back as ints (JSON reads every number as a float), and the data goes through
## JsoncWriter.normalized so its whole numbers are ints again.
static func load_draft(content_path: String, drafts_dir := DRAFTS) -> Dictionary:
	var path := draft_path(content_path, drafts_dir)
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false}
	var record: Dictionary = parsed
	var data: Variant = record.get("data")
	var sids: Variant = record.get("sids")
	if typeof(data) != TYPE_DICTIONARY or typeof(sids) != TYPE_ARRAY:
		return {"ok": false}
	var doc := StudioDoc.new()
	doc.path = String(record.get("file", content_path))
	doc.kind = String(record.get("kind", ""))
	doc.header = String(record.get("header", ""))
	doc.base_hash = String(record.get("base_hash", ""))
	doc.data = JsoncWriter.normalized(data)
	for sid: Variant in sids:
		doc.sids.append(int(sid))
	doc.next_sid = int(record.get("next_sid", doc.sids.size() + 1))
	return {
		"ok": true,
		"doc": doc,
		"base_text": String(record.get("base_text", "")),
		"saved_at": String(record.get("saved_at", "")),
		"base_sids": JsoncWriter.normalized(record.get("base_sids", [])),
	}


## Every content path that has a draft, sorted. The names reverse draft_path: "__" back to "/".
static func list_drafts(drafts_dir := DRAFTS) -> Array[String]:
	var paths: Array[String] = []
	if not DirAccess.dir_exists_absolute(drafts_dir):
		return paths
	for name: String in DirAccess.get_files_at(drafts_dir):
		if name.ends_with(DRAFT_SUFFIX):
			var record: Variant = JSON.parse_string(read_text(drafts_dir.path_join(name)))
			if record is Dictionary and record.get("file") is String:
				paths.append(String(record.file))
	paths.sort()
	return paths


## Throws a draft away (Revert draft). A draft that is not there is left alone.
static func discard_draft(content_path: String, drafts_dir := DRAFTS) -> void:
	var path := draft_path(content_path, drafts_dir)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Copies a content file into backups_dir/<stamp>/<its path without res://, folders kept>. True when copied.
static func backup(content_path: String, stamp: String, backups_dir := BACKUPS) -> bool:
	if not FileAccess.file_exists(content_path):
		return false
	var target := backup_path(content_path, stamp, backups_dir)
	if FileAccess.file_exists(target):
		return false
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
		return false
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_buffer(FileAccess.get_file_as_bytes(content_path))
	file.close()
	return stored


static func backup_path(content_path: String, stamp: String, backups_dir := BACKUPS) -> String:
	var relative := content_path.trim_prefix("res://").trim_prefix("user://").trim_prefix("/")
	return backups_dir.path_join(stamp).path_join(relative)


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


static func list_dirs(path: String) -> Array[String]:
	var names: Array[String] = []
	if DirAccess.dir_exists_absolute(path):
		names.assign(DirAccess.get_directories_at(path))
		names.sort()
	return names


static func list_files(path: String, suffix := "") -> Array[String]:
	var names: Array[String] = []
	if DirAccess.dir_exists_absolute(path):
		for name: String in DirAccess.get_files_at(path):
			if suffix == "" or name.ends_with(suffix):
				names.append(name)
		names.sort()
	return names


## Back up every file before writing any. A failure restores writes already made and keeps drafts intact. An entry with
## `new` true is a file the Studio makes (a map made in it, phase S6): it must not exist yet (its expected hash is that
## of no text), it has nothing to back up, and a rollback removes it again.
static func batch_publish(entries: Array[Dictionary], stamp: String, backups_dir := BACKUPS) -> Dictionary:
	var originals := {}
	var seen := {}
	var conflicts: Array[String] = []
	for entry: Dictionary in entries:
		var path := String(entry.path)
		var made := bool(entry.get("new", false))
		if seen.has(path) or (not made and not exists(path)):
			return {"ok": false, "error": "Missing or repeated content file: " + path, "files": []}
		if made and not DirAccess.dir_exists_absolute(path.get_base_dir()):
			return {"ok": false, "error": "No folder for the new file: " + path, "files": []}
		seen[path] = true
		var original := read_text(path)
		originals[path] = original
		if original.sha256_text() != String(entry.expected_hash) or (made and exists(path)):
			conflicts.append(path)
	if not conflicts.is_empty():
		return {"ok": false, "error": "Content changed after review", "conflicts": conflicts, "files": []}
	for entry: Dictionary in entries:
		if bool(entry.get("new", false)):
			continue
		if not backup(String(entry.path), stamp, backups_dir):
			return {"ok": false, "error": "Could not back up " + String(entry.path), "files": []}
	var written: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var path := String(entry.path)
		var changed := read_text(path).sha256_text() != String(entry.expected_hash)
		if changed or not write_content(path, String(entry.text), String(entry.expected_hash)):
			var rollback_errors: Array[String] = []
			for prior: Dictionary in written:
				var prior_path := String(prior.path)
				# Do not overwrite a further external edit while restoring our own write.
				if read_text(prior_path).sha256_text() != String(prior.text).sha256_text():
					rollback_errors.append(prior_path)
				elif bool(prior.get("new", false)):
					if DirAccess.remove_absolute(prior_path) != OK:
						rollback_errors.append(prior_path)
				elif not write_content(prior_path, String(originals[prior_path])):
					rollback_errors.append(prior_path)
			return {
				"ok": false, "error": ("Content changed: " if changed else "Could not write: ") + path,
				"files": [], "rollback_errors": rollback_errors, "backup_stamp": stamp,
			}
		written.append(entry)
	var files: Array[String] = []
	for entry: Dictionary in written:
		files.append(String(entry.path))
	return {"ok": true, "files": files, "backup_stamp": stamp, "rollback_errors": []}


## Writes text to a content file safely: to `<path>.tmp` beside it, then renamed over the original, so a failure
## never leaves half a file. True when written.
static func write_content(content_path: String, text: String, expected_hash := "") -> bool:
	return _write_atomic(content_path, text, expected_hash)


## The world pipeline's folder of specs (pipeline/world/objects), beside the game's folder in the repository.
static func world_objects_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../pipeline/world/objects").simplify_path()


## Writes a remake's spec into the world pipeline (Concept/v0.3/10, section 7.7: the one write outside `user://` that is
## not Publish, done when Run remakes starts). A spec already there with other text is someone's work and is kept:
## false then. True when the file holds `text`.
static func write_world_spec(id: String, text: String, folder := "") -> bool:
	var dir := folder if folder != "" else world_objects_dir()
	if id.is_empty() or id.contains("/") or id.contains(".."):
		return false
	var path := dir.path_join(id + ".jsonc")
	if FileAccess.file_exists(path):
		return read_text(path) == text
	DirAccess.make_dir_recursive_absolute(dir)
	return _write_atomic(path, text)


## A Dictionary's keys as sorted Strings.
static func sorted_keys(of: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in of:
		keys.append(String(key))
	keys.sort()
	return keys


## Where the drafts of plain files live (a thing's file and its starters, Studio S8): one record beside the map drafts.
static func file_drafts_path(drafts_dir := DRAFTS) -> String:
	return drafts_dir.path_join("files.json")


## The drafts of plain files: content path -> {text, base_hash}. {} when there are none.
static func load_file_drafts(drafts_dir := DRAFTS) -> Dictionary:
	var parsed: Variant = read_record(file_drafts_path(drafts_dir))
	var out := {}
	if parsed is Dictionary:
		for path: Variant in parsed:
			var entry: Variant = (parsed as Dictionary)[path]
			if entry is Dictionary and (entry as Dictionary).get("text") is String:
				out[String(path)] = {"text": String(entry.text), "base_hash": String((entry as Dictionary).get("base_hash", ""))}
	return out


## Writes the drafts of plain files (an empty record removes the file). True when written.
static func save_file_drafts(files: Dictionary, drafts_dir := DRAFTS) -> bool:
	var path := file_drafts_path(drafts_dir)
	if files.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return true
	if DirAccess.make_dir_recursive_absolute(drafts_dir) != OK:
		return false
	return _write_atomic(path, file_drafts_text(files))


static func file_drafts_text(files: Dictionary) -> String:
	return JSON.stringify(files, "\t", false, true)


## A durable before-image for one user:// draft file. The in-flight manifest stores this before replacing any draft.
static func storage_snapshot(path: String) -> Dictionary:
	return {"exists": FileAccess.file_exists(path), "text": read_text(path)}


## Restores one draft file from a transaction snapshot. Repeating the operation is safe, as startup recovery may retry.
static func restore_storage_snapshot(path: String, snapshot: Dictionary) -> bool:
	if not path.begins_with("user://") or not snapshot.get("exists") is bool:
		return false
	if not bool(snapshot.exists):
		if not FileAccess.file_exists(path):
			return true
		return DirAccess.remove_absolute(path) == OK
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	return _write_atomic(path, String(snapshot.get("text", "")))


static func world_transaction_manifest_path(drafts_dir := DRAFTS) -> String:
	return drafts_dir.path_join("world_transaction.json")


static func world_groups_path(drafts_dir := DRAFTS) -> String:
	return drafts_dir.path_join("world_groups.json")


## Replays the manifest's explicit before- or after-images. A prepared operation is rolled back; a committed operation
## is completed. No ordering guess is made from whichever draft files happened to reach disk first.
static func recover_world_transaction(drafts_dir := DRAFTS) -> Dictionary:
	var path := world_transaction_manifest_path(drafts_dir)
	if not FileAccess.file_exists(path):
		return {"ok": true, "recovered": false, "error": ""}
	var value: Variant = read_record(path)
	if (
		not value is Dictionary
		or int((value as Dictionary).get("version", 0)) != 1
		or String((value as Dictionary).get("id", "")).is_empty()
		or not (value as Dictionary).get("storage", []) is Array
		or ((value as Dictionary).get("storage", []) as Array).is_empty()
	):
		return {"ok": false, "recovered": false, "error": "The saved world transaction recovery record cannot be read."}
	var committed := String((value as Dictionary).get("state", "")) == "committed"
	if not committed and String((value as Dictionary).get("state", "")) != "prepared":
		return {"ok": false, "recovered": false, "error": "The saved world transaction has an unknown state."}
	for item: Variant in (value as Dictionary).storage:
		if not item is Dictionary:
			return {"ok": false, "recovered": false, "error": "The saved world transaction has an invalid draft record."}
		var entry: Dictionary = item
		var image: Variant = entry.get("after" if committed else "before")
		if not image is Dictionary or not restore_storage_snapshot(String(entry.get("path", "")), image):
			return {"ok": false, "recovered": false, "error": "The saved world transaction could not restore %s." % String(entry.get("path", "a draft"))}
	if DirAccess.remove_absolute(path) != OK:
		return {"ok": false, "recovered": false, "error": "The recovered world transaction record could not be removed."}
	return {"ok": true, "recovered": true, "error": ""}


## A small JSON record the Studio keeps for itself under `user://` (the remake queue). {} or [] when absent.
static func read_record(path: String) -> Variant:
	var parsed: Variant = JSON.parse_string(read_text(path)) if FileAccess.file_exists(path) else null
	return parsed


static func write_record(path: String, value: Variant) -> bool:
	if not path.begins_with("user://"):
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return _write_atomic(path, JSON.stringify(value, "\t", false, true))


## The text of a file, "" when it does not exist.
static func read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## Writes `text` to `path` through `path + ".tmp"` and a rename, so `path` is always either the old text or the new.
static func _write_atomic(path: String, text: String, expected_hash := "") -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_string(text)
	file.close()
	if expected_hash != "" and read_text(path).sha256_text() != expected_hash:
		DirAccess.remove_absolute(temp)
		return false
	if stored and DirAccess.rename_absolute(temp, path) == OK:
		return true
	DirAccess.remove_absolute(temp)
	return false
