class_name StudioQuestWork
extends RefCounted
## What the quest editor (Concept/v0.3/10, S9) edits: `quests.jsonc` and the talk files, each a StudioDoc ("quests",
## "talk") with its own history (undo and redo), changed only by commands (StudioCommands' set_at, insert_at,
## remove_at, in batches). Every change writes the doc's text into the drafts of plain files (StudioThings, the same
## record a thing's files use), so Publish reviews and writes them like any other draft, a file changed meanwhile is a
## conflict, and Play draft plays them (load_world reads those drafts). The flag browser reads what the docs say now.
##
##   var quests := StudioQuestWork.new(studio)
##   quests.do("quests", {"type": "insert_at", "path": ["hello", "steps"], "index": -1, "value": step})
##   quests.do("talk/pip", {"type": "insert_at", "path": ["nodes", "hello", "set"], "index": -1, "value": "pip-waved"})
##   quests.flags()     # StudioQuests.flag_index of the docs as they are now

signal changed(key: String)

var _studio: StudioMode
## Doc key ("quests", or "talk/<id>") -> StudioHistory.
var _docs: Dictionary = {}
## File path -> {text, data}: the maps read for the flag index, and the files of the docs, each parsed once per text.
var _map_files: Dictionary = {}
var _file_data_of: Dictionary = {}


func _init(studio: StudioMode) -> void:
	_studio = studio


## The folder of the overworld's content in the Studio's content root.
func folder() -> String:
	return _studio.content_root().path_join("packs/core/overworld")


## The content path of a doc key.
func path_of(key: String) -> String:
	if key == "quests":
		return folder().path_join("quests.jsonc")
	return folder().path_join("talk").path_join(key.trim_prefix("talk/") + ".jsonc")


## The talk files there are, by id, sorted.
func talk_ids() -> Array[String]:
	var ids: Array[String] = []
	for name: String in StudioFiles.list_files(folder().path_join("talk"), ".jsonc"):
		ids.append(name.get_basename())
	for path: String in _studio.work.things().files:
		if path.get_base_dir() == folder().path_join("talk") and not path.get_file().get_basename() in ids:
			ids.append(path.get_file().get_basename())
	ids.sort()
	return ids


## A listed file can still be unreadable. Navigation must not open an empty editor for broken dialogue.
func talk_available(id: String) -> bool:
	if id.is_empty() or not talk_ids().has(id):
		return false
	var kept := history("talk/" + id)
	if kept == null:
		return false
	var nodes: Variant = kept.doc.data.get("nodes", {})
	return nodes is Dictionary and not (nodes as Dictionary).is_empty()


## A doc's history, from its draft when there is one, else from its file. Null when neither reads.
func history(key: String) -> StudioHistory:
	if _docs.has(key):
		return _docs[key]
	var path := path_of(key)
	var drafted: Dictionary = _studio.work.things().files.get(path, {})
	var text := String(drafted.get("text", StudioFiles.read_text(path)))
	var parsed := StudioDoc.parse(path, "quests" if key == "quests" else "talk", text)
	if not bool(parsed.ok):
		return null
	var made := StudioHistory.new(parsed.doc as StudioDoc)
	_docs[key] = made
	return made


## A doc's data now ({} when it cannot be read).
func data(key: String) -> Dictionary:
	var kept := history(key)
	return kept.doc.data if kept != null else {}


## Applies a command to a doc: its text goes in the drafts, Play draft plays it. {ok, ...} as StudioCommands.apply.
func do(key: String, command: Dictionary) -> Dictionary:
	var kept := history(key)
	if kept == null:
		return {"ok": false, "error": "%s cannot be read" % path_of(key).get_file()}
	var result := kept.do(command)
	if result.ok:
		_kept(key)
	else:
		_studio.say(String(result.error), true)
	return result


func undo(key: String) -> bool:
	var kept := history(key)
	if kept == null or not kept.undo():
		return false
	_kept(key)
	return true


func redo(key: String) -> bool:
	var kept := history(key)
	if kept == null or not kept.redo():
		return false
	_kept(key)
	return true


## Whether a doc differs from its file (it has a draft to publish). What is compared is what the doc says, not how it is
## written: a file laid out by hand and the same data written by the Studio are the same.
func drafted(key: String) -> bool:
	var kept := history(key)
	return kept != null and kept.doc.data != _file_data(key)


## What a doc's file says as data (null when it is not there or cannot be read). Parsed again only when the text changes.
func _file_data(key: String) -> Variant:
	var path := path_of(key)
	var text := StudioFiles.read_text(path)
	var kept: Dictionary = _file_data_of.get(path, {})
	if kept.has("text") and kept.text == text:
		return kept.data
	var parsed := StudioDoc.parse(path, "quests" if key == "quests" else "talk", text)
	var data: Variant = (parsed.doc as StudioDoc).data if bool(parsed.ok) else null
	_file_data_of[path] = {"text": text, "data": data}
	return data


## The docs that differ from their files, as keys: "quests" first, then "talk/<id>" in order (the panel's drafted line).
func drafted_keys() -> Array[String]:
	var out: Array[String] = []
	if drafted("quests"):
		out.append("quests")
	for id: String in talk_ids():
		if drafted("talk/" + id):
			out.append("talk/" + id)
	return out


## Every flag with where it is set and where it is read (StudioQuests.flag_index), from the docs as they are now (the
## quests and every talk file, drafts included) and the maps (their drafts when there are).
func flags() -> Dictionary:
	var talk := {}
	for id: String in talk_ids():
		talk[id] = data("talk/" + id)
	var maps := {}
	for id: String in _studio.catalog().maps:
		var session: StudioSession = _studio.work.sessions().get(id)
		maps[id] = session.doc().data if session != null else _file_map(id)
	# The town raises "<id>-open" itself when a thing's `open` field turns true (ThingHost.applied).
	var game_flags: Array[Dictionary] = LESSON_FLAGS.duplicate(true)
	# v0.4: each task's stage sets its flag when it passes (TaskHost), and the town sets the parts' own.
	for task_id: String in _studio.catalog().get("tasks", {}):
		for stage: Variant in (_studio.catalog().tasks[task_id] as Dictionary).get("stages", []):
			if stage is Dictionary and String((stage as Dictionary).get("flag", "")) != "":
				game_flags.append({"flag": String(stage.flag), "lesson": task_id})
	for flag: String in PART_FLAGS:
		game_flags.append({"flag": flag, "lesson": "game"})
	for item: String in _studio.catalog().get("items", {}):
		game_flags.append({"flag": "picked-" + item, "lesson": "game"})
		game_flags.append({"flag": "gave-" + item, "lesson": "game"})
	for id: String in maps:
		for object: Variant in (maps[id] as Dictionary).get("objects", []):
			if object is Dictionary and TownThings.specs_of(object).has("open"):
				game_flags.append({"flag": String((object as Dictionary).get("id", "")) + "-open", "lesson": "game"})
	return StudioQuests.flag_index(data("quests"), talk, maps, game_flags)


## The flags the game's own code sets rather than content: the lessons' (memory, lamps) and the town's ("game": waking,
## the boots' first steps, leaving home, the menu's Save).
const LESSON_FLAGS: Array[Dictionary] = [
	{"flag": "memory-written", "lesson": "memory"}, {"flag": "lamps-written", "lesson": "lamps"},
	{"flag": "lamps-lit", "lesson": "lamps"}, {"flag": "saved-once", "lesson": "game"}, {"flag": "woke", "lesson": "game"},
	{"flag": "first-step", "lesson": "game"}, {"flag": "all-ways", "lesson": "game"}, {"flag": "left-home", "lesson": "game"},
	{"flag": "boots-hint-seen", "lesson": "game"}, {"flag": "first-action", "lesson": "game"},
]


## The flags the town sets for v0.4's parts (the overworld: the menu opened, a slider moved, a song chosen, the map
## opened, the first evening, the credits rolled) and for Hotaru's first pocket menu.
const PART_FLAGS: Array[String] = [
	"menu-opened", "volume-tried", "music-played", "map-opened", "clock-evening", "credits-rolled", "pocket-menu-seen",
	"tally-read", "rain-seen", "hours-seen", "shop-sold", "shop-bought", "bag-tidied", "history-viewed",
]


## The doc's text goes in the drafts (or its draft goes, when it says what the file says), and Play draft's catalog
## takes the quests and talk as the docs say them now.
func _kept(key: String) -> void:
	var path := path_of(key)
	var things := _studio.work.things()
	if not drafted(key):
		things.forget([path])
	else:
		things.put(path, history(key).doc.to_text())
	things.save()
	if _studio.play_draft:
		put_in_catalog()
	_studio.draft_changed()
	changed.emit(key)


## The quests and talk in the catalog the town plays become the docs' (with their drafts): Play draft shows a new step.
## `with_drafts` false puts the files' back (Play draft turned off).
func put_in_catalog(with_drafts := true) -> void:
	var loaded := OverworldContent.load_world(_studio.content_root(), _studio.work.things().drafts() if with_drafts else {})
	for section: String in ["quests", "talk"]:
		var live: Dictionary = _studio.catalog().get(section, {})
		live.clear()
		live.merge(loaded.catalog.get(section, {}))


## A map as its file says it. Parsed again only when the file's text changes (the flag index asks on every rebuild).
func _file_map(id: String) -> Dictionary:
	var path := StudioSession.path_of(id, _studio.content_root())
	var text := StudioFiles.read_text(path)
	var kept: Dictionary = _map_files.get(path, {})
	if kept.has("data") and kept.text == text:
		return kept.data
	var parsed := Jsonc.parse(text)
	var data: Dictionary = JsoncWriter.normalized(parsed.value) if bool(parsed.ok) and parsed.value is Dictionary else {}
	_map_files[path] = {"text": text, "data": data}
	return data
