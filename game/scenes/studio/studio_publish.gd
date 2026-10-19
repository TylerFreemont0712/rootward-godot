class_name StudioPublish
extends RefCounted
## Reviews and publishes the Studio's whole draft world (ADR-0066, phase S2). StudioFiles owns every file access;
## this service combines sessions, the game's loader and the pure Studio rules, then asks for one backed-up batch.
## Keep draft is permission for the exact disk version shown in the last review. A later disk change needs a new review.

var content_root := ContentLoader.ROOT
var drafts_dir := StudioFiles.DRAFTS
var backups_dir := StudioFiles.BACKUPS
var art_root := OverworldArt.ROOT
## The remakes not made yet (StudioRemakes): a thing or a catalog entry waiting for one of these pictures is a warning
## (it is drawn as a placeholder until then), not a missing picture.
var remakes_waiting: Array[String] = []

var _reviewed_hashes: Dictionary = {}

## The `map_id` of a change that is a plain file (a thing's file or a starter, Studio S8) rather than a map's.
const FILES_KEY := "~files"


## Includes persisted drafts of unvisited maps and the latest in-memory documents. Unchanged sessions do not publish.
## `changes` carries {file, map_id, summary, lines}; problems carry {severity, file, map_id, message, sid, cell}.
func review(sessions: Dictionary) -> Dictionary:
	var report := _inspect(sessions)
	_reviewed_hashes.clear()
	for conflict: Dictionary in report.conflicts:
		_reviewed_hashes[String(conflict.file)] = String(conflict.current_hash)
	return report


## Fresh validation and conflict checks precede every publish, even if a dialog's review is older. Warnings require
## acceptance. Drafts and session history are cleared only after every content write succeeds.
func publish(sessions: Dictionary, accept_warnings := false, keep_paths: Array[String] = []) -> Dictionary:
	var report := _inspect(sessions)
	if int(report.error_count) > 0:
		return _failure("Fix the errors before publishing.", report)
	var unresolved: Array[Dictionary] = []
	for conflict: Dictionary in report.conflicts:
		var path := String(conflict.file)
		var reviewed := String(_reviewed_hashes.get(path, ""))
		if not path in keep_paths or reviewed != String(conflict.current_hash):
			unresolved.append(conflict)
	if not unresolved.is_empty():
		report.conflicts = unresolved
		return _failure("A file changed on disk. Review it, then keep the draft or rebase.", report)
	if int(report.warning_count) > 0 and not accept_warnings:
		return _failure("Accept the warnings before publishing.", report)
	if (report.changes as Array).is_empty():
		return _failure("There are no changes to publish.", report)
	var entries: Array[Dictionary] = []
	var all_sessions: Dictionary = report.sessions
	var file_drafts := StudioFiles.load_file_drafts(drafts_dir)
	for change: Dictionary in report.changes:
		var path := String(change.file)
		if String(change.map_id) == FILES_KEY:
			entries.append({
				"path": path, "text": String((file_drafts[path] as Dictionary).text),
				"expected_hash": String(report.disk_hashes[path]), "new": not StudioFiles.exists(path),
			})
			continue
		var changed: Variant = _session_in(report, String(change.map_id))
		entries.append({
			"path": path,
			"text": _doc_of(changed).to_text(),
			"expected_hash": String(report.disk_hashes[path]),
			"new": changed is StudioSession and (changed as StudioSession).is_new,
		})
	var stamp := Time.get_datetime_string_from_system().replace(":", "-") + "-%d" % Time.get_ticks_usec()
	var written := StudioFiles.batch_publish(entries, stamp, backups_dir)
	if not bool(written.get("ok", false)):
		var failed := _failure(String(written.get("error", "The files could not be written.")), report)
		failed["backup_stamp"] = String(written.get("backup_stamp", stamp))
		failed["rollback_errors"] = written.get("rollback_errors", [])
		if written.has("conflicts") and not (written.conflicts as Array).is_empty():
			var batch_conflicts: Array[Dictionary] = []
			for value: Variant in written.conflicts:
				if value is Dictionary:
					batch_conflicts.append(value as Dictionary)
				else:
					var path := String(value)
					batch_conflicts.append({"file": path, "map_id": path.get_file().get_basename(),
						"current_hash": StudioFiles.read_text(path).sha256_text()})
			failed["conflicts"] = batch_conflicts
		return failed
	var cleanup_errors: Array[String] = []
	var written_files: Array[String] = []
	for change: Dictionary in report.changes:
		if String(change.map_id) == FILES_KEY:
			written_files.append(String(change.file))
			continue
		var changed: Variant = _session_in(report, String(change.map_id))
		if changed is StudioCatalogSession:
			var catalog := changed as StudioCatalogSession
			var written_doc := catalog.doc().copy()
			var written_text := written_doc.to_text()
			written_doc.base_hash = written_text.sha256_text()
			catalog.base_text = written_text
			catalog.base_doc = written_doc
			catalog.history = StudioHistory.new(written_doc.copy())
			catalog.unsaved = false
			StudioFiles.discard_draft(catalog.path, drafts_dir)
			if StudioFiles.exists(StudioFiles.draft_path(catalog.path, drafts_dir)):
				cleanup_errors.append(catalog.path)
			continue
		var session: StudioSession = changed
		var published := session.doc().copy()
		var text := published.to_text()
		published.base_hash = text.sha256_text()
		_adopt(session, published, published.copy(), text)
		StudioFiles.discard_draft(session.path, drafts_dir)
		if StudioFiles.exists(StudioFiles.draft_path(session.path, drafts_dir)):
			# A completed publish remains completed if cleanup fails. Refresh a stuck record to the published base so
			# reopening it cannot mistake the old draft for a new edit, and report the file that still needs cleanup.
			StudioFiles.save_draft(published, text, drafts_dir, published.sids)
			cleanup_errors.append(session.path)
	if not written_files.is_empty():
		for path: String in written_files:
			file_drafts.erase(path)
		if not StudioFiles.save_file_drafts(file_drafts, drafts_dir):
			cleanup_errors.append(StudioFiles.file_drafts_path(drafts_dir))
	_reviewed_hashes.clear()
	return {
		"ok": true, "error": "", "files": written.get("files", []), "backup_stamp": stamp,
		"problems": report.problems, "conflicts": [], "sessions": all_sessions, "cleanup_errors": cleanup_errors,
	}


## Re-applies a draft to today's file. A merge conflict or failed draft save leaves the session and its history intact.
func rebase(session: StudioSession) -> Dictionary:
	if session == null or not _map_path(session.path):
		return {"ok": false, "error": "There is no map draft to rebase.", "conflicts": []}
	if session.is_new:
		var taken := "A file %s was made after this map was. Keep the draft to write over it, or revert this map." % session.path.get_file()
		return {"ok": false, "error": taken, "conflicts": []}
	var text := StudioFiles.read_text(session.path)
	var parsed := StudioDoc.parse(session.path, "map", text)
	if not bool(parsed.ok):
		return {"ok": false, "error": String(parsed.error), "conflicts": []}
	var current: StudioDoc = parsed.doc
	var merged := StudioRebase.rebase(session.base_doc, session.doc(), current)
	if not bool(merged.get("ok", false)):
		return merged
	var doc: StudioDoc = merged.doc
	doc.base_hash = text.sha256_text()
	var base: StudioDoc = merged.get("base_doc", current)
	if not StudioFiles.save_draft(doc, text, drafts_dir, base.sids):
		return {"ok": false, "error": "The rebased draft could not be saved.", "conflicts": []}
	_adopt(session, doc, base, text)
	session.saved_at = StudioSession._clock_of(Time.get_datetime_string_from_system())
	_reviewed_hashes.erase(session.path)
	return {"ok": true, "error": "", "doc": doc, "base_doc": base, "conflicts": []}


## Revert loads the current content file, then discards its saved draft and resets its edit history. A map made in the
## Studio has no file to go back to: its draft is thrown away and the result says `removed` (the caller lets go of it).
func revert(session: StudioSession) -> Dictionary:
	if session == null or not _map_path(session.path):
		return {"ok": false, "error": "There is no map draft to revert."}
	if session.is_new and not StudioFiles.exists(session.path):
		StudioFiles.discard_draft(session.path, drafts_dir)
		if StudioFiles.exists(StudioFiles.draft_path(session.path, drafts_dir)):
			return {"ok": false, "error": "The draft could not be removed."}
		_reviewed_hashes.erase(session.path)
		return {"ok": true, "error": "", "removed": true}
	var text := StudioFiles.read_text(session.path)
	var parsed := StudioDoc.parse(session.path, "map", text)
	if not bool(parsed.ok):
		return {"ok": false, "error": String(parsed.error)}
	StudioFiles.discard_draft(session.path, drafts_dir)
	if StudioFiles.exists(StudioFiles.draft_path(session.path, drafts_dir)):
		return {"ok": false, "error": "The draft could not be removed."}
	var doc: StudioDoc = parsed.doc
	_adopt(session, doc, doc.copy(), text)
	_reviewed_hashes.erase(session.path)
	return {"ok": true, "error": "", "doc": doc}


func _inspect(sessions: Dictionary) -> Dictionary:
	var problems: Array[Dictionary] = []
	var all_sessions := _collect(sessions, problems)
	var changes: Array[Dictionary] = []
	var conflicts: Array[Dictionary] = []
	var drafts: Dictionary = {}
	var sids: Dictionary = {}
	var disk_hashes: Dictionary = {}
	var ids := _sorted_keys(all_sessions)
	var catalog_doc: StudioDoc = null
	for id: String in ids:
		var value: Variant = all_sessions[id]
		var doc := _doc_of(value)
		var base: StudioDoc = (value as StudioCatalogSession).base_doc if value is StudioCatalogSession else (value as StudioSession).base_doc
		var path := String((value as StudioCatalogSession).path if value is StudioCatalogSession else (value as StudioSession).path)
		if value is StudioCatalogSession:
			catalog_doc = doc
		var made := value is StudioSession and (value as StudioSession).is_new
		if not made and doc.to_text() == base.to_text():
			continue
		if value is StudioSession:
			drafts[path] = doc.data
			sids[path] = doc.sids
		changes.append({
			"file": path, "map_id": id,
			"summary": StudioDiff.summary(base, doc), "lines": StudioDiff.lines(base, doc),
		})
		var hash_now := StudioFiles.read_text(path).sha256_text()
		disk_hashes[path] = hash_now
		if hash_now != doc.base_hash:
			conflicts.append({
				"file": path, "map_id": id,
				"base_hash": doc.base_hash, "current_hash": hash_now,
			})
	var maps := _maps(drafts, sids, problems)
	var everything := drafts.duplicate()
	everything.merge(_file_changes(changes, conflicts, disk_hashes, problems, maps))
	var loaded := OverworldContent.load_world(content_root, everything)
	var art := _art()
	var context := {
		"maps": maps, "sids": sids, "terrain": loaded.catalog.terrain,
		"townsfolk": loaded.catalog.townsfolk, "art": art.pictures, "footprints": art.footprints,
	}
	problems.append_array(StudioRules.check(context))
	_new_maps_reached(all_sessions, maps, problems)
	if catalog_doc != null:
		problems.append_array(_catalog_problems(catalog_doc, loaded.catalog.townsfolk))
	_waiting_for_remakes(problems)
	for diagnostic: Dictionary in loaded.diagnostics:
		var file := _diagnostic_path(String(diagnostic.get("file", "")), maps)
		var problem := _problem(String(diagnostic.severity), file, String(diagnostic.message))
		if not _same_problem(problems, problem):
			problems.append(problem)
	var error_count := 0
	var warning_count := 0
	for problem: Dictionary in problems:
		var file_path := String(problem.get("file", ""))
		problem["map_id"] = StudioCatalogSession.KEY if file_path == StudioCatalogSession.path_of(content_root) else file_path.get_file().get_basename()
		if String(problem.get("severity", "error")) == "error":
			error_count += 1
		else:
			warning_count += 1
	problems.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.severity) < String(b.severity)
	)
	# The maps' sessions and the catalog's apart: callers merge `sessions` back into the Studio's map sessions.
	var map_sessions := all_sessions.duplicate()
	map_sessions.erase(StudioCatalogSession.KEY)
	return {
		"ok": error_count == 0 and conflicts.is_empty(), "changes": changes, "problems": problems,
		"conflicts": conflicts, "error_count": error_count, "warning_count": warning_count,
		"sessions": map_sessions, "catalog_session": all_sessions.get(StudioCatalogSession.KEY),
		"drafts": drafts, "disk_hashes": disk_hashes,
	}


func _collect(sessions: Dictionary, problems: Array[Dictionary]) -> Dictionary:
	var collected: Dictionary = {}
	for path: String in StudioFiles.list_drafts(drafts_dir):
		if path == StudioCatalogSession.path_of(content_root):
			var catalog := StudioCatalogSession.open(drafts_dir, content_root)
			if catalog == null:
				problems.append(_problem("error", path, "This saved catalog draft cannot be read."))
			else:
				collected[StudioCatalogSession.KEY] = catalog
			continue
		if not _map_path(path):
			problems.append(_problem("error", path, "This draft is outside the map content folder."))
			continue
		var record := StudioFiles.load_draft(path, drafts_dir)
		if not bool(record.get("ok", false)):
			problems.append(_problem("error", path, "This saved draft cannot be read."))
			continue
		if String(record.base_text) == "" and not StudioFiles.exists(path):
			# A map made in the Studio, never published: it began from nothing.
			var made := StudioSession.new()
			made.path = path
			made.map_id = path.get_file().get_basename()
			made.base_doc = StudioSession.empty_base(path)
			made.history = StudioHistory.new(record.doc as StudioDoc)
			made.drafts_dir = drafts_dir
			made.saved_at = StudioSession._clock_of(String(record.saved_at))
			made.is_new = true
			collected[made.map_id] = made
			continue
		var base := StudioDoc.parse(path, "map", String(record.base_text))
		var doc: StudioDoc = record.doc
		if not bool(base.ok) or doc.path != path or doc.kind != "map":
			problems.append(_problem("error", path, "This saved draft has no valid map base."))
			continue
		var session := StudioSession.new()
		session.path = path
		session.map_id = path.get_file().get_basename()
		session.base_text = String(record.base_text)
		session.base_doc = base.doc
		var base_sids: Array = record.get("base_sids", [])
		if not base_sids.is_empty():
			if base_sids.size() != session.base_doc.sids.size():
				problems.append(_problem("error", path, "This saved draft has invalid base object identities."))
				continue
			session.base_doc.sids.assign(base_sids)
		session.history = StudioHistory.new(doc)
		session.drafts_dir = drafts_dir
		session.saved_at = StudioSession._clock_of(String(record.saved_at))
		collected[session.map_id] = session
	for id: String in sessions:
		var value: Variant = sessions[id]
		if value is StudioCatalogSession:
			collected[StudioCatalogSession.KEY] = value
			continue
		if not value is StudioSession:
			continue
		var session := value as StudioSession
		if not _map_path(session.path) or session.base_doc == null or session.history == null:
			problems.append(_problem("error", session.path, "This session has no valid map document."))
			continue
		collected[session.map_id] = session
	return collected


func _maps(drafts: Dictionary, sids: Dictionary, problems: Array[Dictionary]) -> Dictionary:
	var maps: Dictionary = {}
	var packs := content_root.path_join("packs")
	for pack: String in StudioFiles.list_dirs(packs):
		var folder := packs.path_join(pack).path_join("overworld/maps")
		for name_text: String in StudioFiles.list_files(folder, ".jsonc"):
			var path := folder.path_join(name_text)
			if drafts.has(path):
				continue
			var parsed := StudioDoc.parse(path, "map", StudioFiles.read_text(path))
			if bool(parsed.ok):
				var doc: StudioDoc = parsed.doc
				maps[path] = doc.data
				sids[path] = doc.sids
			else:
				problems.append(_problem("error", path, String(parsed.error)))
	for path: String in drafts:
		maps[path] = drafts[path]
	return maps


## Actual PNGs determine whether art exists. The world pipeline's published index supplies its drawn footprint.
func _art() -> Dictionary:
	var pictures: Dictionary = {}
	for folder: String in ["world", "buildings", "props"]:
		for name_text: String in StudioFiles.list_files(art_root.path_join(folder), ".png"):
			pictures[name_text.get_basename()] = true
	var footprints: Dictionary = {}
	var parsed: Variant = JSON.parse_string(StudioFiles.read_text(art_root.path_join("world/world.json")))
	if parsed is Dictionary:
		var index: Dictionary = parsed
		for id: String in index:
			var entry: Variant = index[id]
			if entry is Dictionary and (entry as Dictionary).has("footprint"):
				footprints[id] = (entry as Dictionary).footprint
	return {"pictures": pictures, "footprints": footprints}


## The session a change of the report belongs to: a map's, or the catalog's.
static func _session_in(report: Dictionary, id: String) -> Variant:
	return report.get("catalog_session") if id == StudioCatalogSession.KEY else (report.sessions as Dictionary).get(id)


## The doc a session holds: a map's or the catalog's.
static func _doc_of(value: Variant) -> StudioDoc:
	return (value as StudioCatalogSession).doc() if value is StudioCatalogSession else (value as StudioSession).doc()


## The catalog's own checks (StudioCatalog.coverage): every picture and townsperson with one entry, every entry with a
## picture, a known category. A missing picture of a remake not made yet is left to _waiting_for_remakes.
func _catalog_problems(doc: StudioDoc, townsfolk: Dictionary) -> Array[Dictionary]:
	var pictures: Dictionary = {}
	for folder: String in ["world", "buildings", "props"]:
		var ids: Array[String] = []
		for name_text: String in StudioFiles.list_files(art_root.path_join(folder), ".png"):
			ids.append(name_text.get_basename())
		pictures[folder] = ids
	var people: Array[String] = []
	people.assign(townsfolk.keys())
	var file := StudioCatalogSession.path_of(content_root)
	var out: Array[Dictionary] = []
	for message: String in StudioCatalog.coverage(doc.data.get("assets", {}), doc.data.get("categories", []), pictures, people):
		var id := message.get_slice(" ", 0)
		if message.ends_with("names no picture") and id in remakes_waiting:
			out.append(_problem("warning", file, "%s waits for its remake (a placeholder is drawn until then)" % id))
		else:
			out.append(_problem("error", file, message))
	return out


## The plain files the Studio drafted (a thing's file and its starters, S8) that differ from the disk: each one a change
## (with a conflict when the disk changed since the draft began), and all of them as load_world's drafts (path -> data
## or text), so the review loads the world as it would be. A thing's file that no prop of any map uses is a warning.
func _file_changes(
	changes: Array[Dictionary], conflicts: Array[Dictionary], disk_hashes: Dictionary, problems: Array[Dictionary],
	maps: Dictionary
) -> Dictionary:
	var files := StudioFiles.load_file_drafts(drafts_dir)
	var out := {}
	var used := {}
	for path: String in maps:
		for object: Variant in (maps[path] as Dictionary).get("objects", []):
			if object is Dictionary and (object as Dictionary).has("program"):
				used[String((object as Dictionary).get("id", ""))] = true
	for path: String in StudioFiles.sorted_keys(files):
		var text := String((files[path] as Dictionary).text)
		var disk := StudioFiles.read_text(path)
		if path.ends_with(".jsonc"):
			var parsed := Jsonc.parse(text)
			if bool(parsed.ok) and parsed.value is Dictionary:
				out[path] = JsoncWriter.normalized(parsed.value)
			else:
				problems.append(_problem("error", path, "This drafted file is not valid JSONC: %s" % String(parsed.get("error", ""))))
			if path.get_base_dir().ends_with("/overworld/things") and not used.has(path.get_file().get_basename()):
				problems.append(_problem("warning", path, "%s: no prop of any map takes this thing's code" % path.get_file().get_basename()))
		else:
			out[path] = text
		if text == disk:
			continue
		var made := not StudioFiles.exists(path)
		var shown := path.trim_prefix(content_root.trim_suffix("/") + "/packs/core/overworld/")
		changes.append({
			"file": path, "map_id": FILES_KEY, "summary": "new file" if made else "changed",
			"lines": [("New file %s" if made else "Changed %s") % shown],
		})
		var hash_now := disk.sha256_text()
		disk_hashes[path] = hash_now
		var base := String((files[path] as Dictionary).get("base_hash", ""))
		if hash_now != base:
			conflicts.append({"file": path, "map_id": FILES_KEY, "base_hash": base, "current_hash": hash_now})
	return out


## A map made in the Studio that no door or warp of another map leads into cannot be walked into (Make interior undone,
## say): a warning on it, so it is not published by mistake.
func _new_maps_reached(sessions: Dictionary, maps: Dictionary, problems: Array[Dictionary]) -> void:
	var led := {}
	for path: String in maps:
		var data: Dictionary = maps[path]
		for object: Variant in data.get("objects", []):
			var to: Variant = (object as Dictionary).get("to") if object is Dictionary else null
			if to is Dictionary and String((to as Dictionary).get("map", "")) != String(data.get("id", "")):
				led[String((to as Dictionary).get("map", ""))] = true
	for id: String in _sorted_keys(sessions):
		var session: Variant = sessions[id]
		if session is StudioSession and (session as StudioSession).is_new and not led.has(id):
			problems.append(_problem("warning", (session as StudioSession).path, "%s: no door or warp leads into this map" % id))


## A thing whose picture is a remake not made yet is drawn as a placeholder: a warning, not a missing picture.
func _waiting_for_remakes(problems: Array[Dictionary]) -> void:
	for problem: Dictionary in problems:
		var message := String(problem.get("message", ""))
		for id: String in remakes_waiting:
			if message.ends_with(': no picture "%s"' % id):
				problem["severity"] = "warning"
				problem["message"] = message.trim_suffix('no picture "%s"' % id) + "waits for its remake (a placeholder until then)"


func _map_path(path: String) -> bool:
	var prefix := content_root.trim_suffix("/") + "/packs/"
	if not path.begins_with(prefix):
		return false
	var parts := path.trim_prefix(prefix).split("/", false)
	return parts.size() == 4 and parts[0] != ".." and parts[0] != "." \
		and parts[1] == "overworld" and parts[2] == "maps" and parts[3].ends_with(".jsonc")


func _diagnostic_path(path: String, maps: Dictionary) -> String:
	if path.begins_with(content_root):
		return path
	for map_path: String in maps:
		if path != "" and map_path.ends_with(path):
			return map_path
	return path


func _same_problem(problems: Array[Dictionary], candidate: Dictionary) -> bool:
	for problem: Dictionary in problems:
		if problem.get("file") == candidate.file and problem.get("message") == candidate.message:
			return true
	return false


func _adopt(session: StudioSession, doc: StudioDoc, base: StudioDoc, text: String) -> void:
	session.base_text = text
	session.base_doc = base
	# Its file is written (Publish) or read (revert, rebase): the map is no longer one made in the Studio.
	session.is_new = false
	session.history = StudioHistory.new(doc)
	session.drafts_dir = drafts_dir
	session.unsaved = false
	session.saved_at = ""


func _failure(error: String, report: Dictionary) -> Dictionary:
	return {
		"ok": false, "error": error, "files": [], "backup_stamp": "", "problems": report.problems,
		"conflicts": report.conflicts, "sessions": report.sessions,
	}


func _problem(severity: String, file: String, message: String) -> Dictionary:
	return {"severity": severity, "file": file, "message": message, "sid": -1, "cell": Vector2i(-1, -1)}


func _sorted_keys(dict: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	keys.assign(dict.keys())
	keys.sort()
	return keys
