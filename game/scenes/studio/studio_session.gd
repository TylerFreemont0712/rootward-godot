class_name StudioSession
extends RefCounted
## One map being edited in Lanternroot Studio (ADR-0066, phase S1): the draft's StudioDoc with its StudioHistory, the doc
## the draft began from (to count the changes), and the draft on disk. Every edit is a command through `do`; `build`
## turns the doc into the map the game plays.
##
##   var session := StudioSession.open("lanternroot", StudioMode.drafts_dir)   # the draft when there is one
##   session.do({"type": "move", "sids": [3], "by": [1, 0]})
##   var built := session.build(catalog.terrain)   # {ok, map, errors, problems, diagnostics}
##   session.save()                                 # the draft, in user://studio/drafts/
##
## Nothing here writes a content file: only Publish (phase S2) does.
##
## A map made in the Studio (a room from Make interior, phase S6) has no file until it is published: its session is
## `is_new`, it began from no text at all (`base_text` "", an empty `base_doc`), and Publish creates its file.

const MAPS := "res://content/packs/core/overworld/maps/"
## The comment a map made in the Studio starts with: the one every map file has.
const MAP_HEADER := "// A map of Lanternroot's overworld (ADR-0061): its ground through the legend, one row a string, and the things on it.\n// Coordinates are [column, row], counted from 0 at the top left.\n"

var map_id := ""
var path := ""
## The text of the content file the draft began from ("" for a map that has no file yet).
var base_text := ""
var base_doc: StudioDoc
## Whether the map was made in the Studio and has no file yet (Publish creates it).
var is_new := false
var history: StudioHistory
## "HH:MM" of the last save of the draft (or of the draft that was loaded); "" before the first.
var saved_at := ""
var drafts_dir := StudioFiles.DRAFTS
## Whether the doc has changes the draft file does not hold yet.
var unsaved := false

var _write: DraftWrite
# LEARN: a doc is never changed once it is a history's doc (StudioCommands.apply works on a copy), so "the same doc
# object" means "the same content". That lets a worker thread read a doc the main thread is also reading, and lets the
# count of changes be remembered per doc instead of worked out again for every redraw of the top bar.
var _counted_doc: StudioDoc
var _counted_base: StudioDoc
var _counted := 0


## A draft write on a worker thread (save_later). It holds what the write needs, taken on the main thread, so it reads
## no live state.
class DraftWrite:
	extends RefCounted
	var doc: StudioDoc
	var base_text := ""
	var base_sids: Array[int] = []
	var drafts_dir := ""
	var saved_at := ""
	var task := -1
	var ok := false

	func run() -> void:
		ok = StudioFiles.save_draft(doc, base_text, drafts_dir, base_sids)


static func path_of(id: String, content_root := ContentLoader.ROOT) -> String:
	return content_root.path_join("packs/core/overworld/maps").path_join(id + ".jsonc")


## The session for a map: its draft when one is saved, else its file's text parsed. Null when neither can be read.
static func open(id: String, drafts_folder := StudioFiles.DRAFTS, content_root := ContentLoader.ROOT) -> StudioSession:
	var session := StudioSession.new()
	session.map_id = id
	session.path = path_of(id, content_root)
	session.drafts_dir = drafts_folder
	var drafted := StudioFiles.load_draft(session.path, drafts_folder)
	if bool(drafted.get("ok", false)):
		session.base_text = String(drafted.base_text)
		session.saved_at = _clock_of(String(drafted.saved_at))
		session.history = StudioHistory.new(drafted.doc as StudioDoc)
		if session.base_text == "" and not StudioFiles.exists(session.path):
			# A map made in the Studio: it began from nothing, and has no file to read.
			session.is_new = true
			session.base_doc = empty_base(session.path)
			return session
		if session.base_text == "":
			session.base_text = StudioFiles.read_text(session.path)
	else:
		session.base_text = StudioFiles.read_text(session.path)
		var parsed := StudioDoc.parse(session.path, "map", session.base_text)
		if not parsed.ok:
			return null
		session.history = StudioHistory.new(parsed.doc as StudioDoc)
	var base := StudioDoc.parse(session.path, "map", session.base_text)
	if not base.ok:
		return null
	session.base_doc = base.doc as StudioDoc
	var base_sids: Array = drafted.get("base_sids", [])
	if not base_sids.is_empty() and base_sids.size() == session.base_doc.sids.size():
		session.base_doc.sids.assign(base_sids)
	return session


## A session for a new map, `data` (map data as a file would say it), with no file yet: null when a file of that id
## exists already. Its draft is not written until `save`.
static func create(id: String, data: Dictionary, drafts_folder := StudioFiles.DRAFTS, content_root := ContentLoader.ROOT) -> StudioSession:
	var file := path_of(id, content_root)
	if StudioFiles.exists(file):
		return null
	var parsed := StudioDoc.parse(file, "map", JsoncWriter.map_text(MAP_HEADER, data))
	if not parsed.ok:
		return null
	var doc: StudioDoc = parsed.doc
	# LEARN: a file that is not there reads as "" (StudioFiles.read_text), so "" is the text a new map began from: its
	# hash is what Publish finds on disk while nobody has made the file, and a file made meanwhile is a conflict.
	doc.base_hash = "".sha256_text()
	var session := StudioSession.new()
	session.map_id = id
	session.path = file
	session.drafts_dir = drafts_folder
	session.base_text = ""
	session.base_doc = empty_base(file)
	session.history = StudioHistory.new(doc)
	session.is_new = true
	session.unsaved = true
	return session


## The doc a new map began from: no data, the hash of no text.
static func empty_base(file: String) -> StudioDoc:
	var base := StudioDoc.new()
	base.path = file
	base.kind = "map"
	base.base_hash = "".sha256_text()
	return base


func doc() -> StudioDoc:
	return history.doc


## Applies a command through the history: {ok, doc, undo, done} or {ok: false, error}.
func do(command: Dictionary) -> Dictionary:
	var result := history.do(command)
	if result.ok:
		unsaved = true
	return result


func undo() -> bool:
	var done := history.undo()
	unsaved = unsaved or done
	return done


func redo() -> bool:
	var done := history.redo()
	unsaved = unsaved or done
	return done


## How many changes the draft holds, as the Publish dialog will list them. Worked out once per doc.
func changes() -> int:
	var now := history.doc
	if _counted_doc != now or _counted_base != base_doc:
		_counted = StudioDiff.lines(base_doc, now).size()
		_counted_doc = now
		_counted_base = base_doc
	return _counted


## A copy for another thread to read: the same docs (they are never changed, see above), but its own history and
## bookkeeping, so the Studio can go on editing, undoing or publishing the original.
func snapshot() -> StudioSession:
	var copy := StudioSession.new()
	copy.map_id = map_id
	copy.path = path
	copy.base_text = base_text
	copy.base_doc = base_doc
	copy.history = StudioHistory.new(history.doc)
	copy.saved_at = saved_at
	copy.drafts_dir = drafts_dir
	copy.unsaved = unsaved
	copy.is_new = is_new
	return copy


## "Draft: 3 changes, saved 14:02", or "Draft: none".
func status() -> String:
	var count := changes()
	if count == 0:
		return "Draft: none"
	var text := "Draft: %d change%s" % [count, "" if count == 1 else "s"]
	return text + (", saved " + saved_at if saved_at != "" and not unsaved else ", not saved yet")


## The map the doc says, as the game builds it: the data copied and checked against the map schema (which fills in the
## defaults), then built. `ok` is false, and `map` empty, when the schema rejects the data.
func build(terrain: Dictionary) -> Dictionary:
	return StudioSession.build_data(history.doc.data, path, terrain)


## The map the content file says, as the game would load it: the text the file has now.
static func build_file(id: String, terrain: Dictionary, content_root := ContentLoader.ROOT) -> Dictionary:
	var file := path_of(id, content_root)
	var parsed := StudioDoc.parse(file, "map", StudioFiles.read_text(file))
	if not parsed.ok:
		return {"ok": false, "map": {}, "errors": [String(parsed.error)], "problems": [], "diagnostics": []}
	return build_data((parsed.doc as StudioDoc).data, file, terrain)


static func build_data(data: Dictionary, file: String, terrain: Dictionary) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var checked := ContentLoader._checked(OverworldContent.map_schema(), data.duplicate(true), file, "", diagnostics)
	if checked.is_empty():
		var errors: Array[String] = []
		for diagnostic: Dictionary in diagnostics:
			errors.append(String(diagnostic.message))
		return {"ok": false, "map": {}, "errors": errors, "problems": [], "diagnostics": diagnostics}
	var built := OverworldMap.build(checked, terrain)
	return {
		"ok": true,
		"map": built.map,
		"errors": built.errors,
		"problems": built.problems,
		"diagnostics": diagnostics,
	}


## Writes the draft now, and returns when it is on disk: true when it was written. A background write that is already
## running (save_later) is waited for first, so two writes of one draft never overlap; when that write was of the
## current doc, it is the save.
func save() -> bool:
	var landed := settle()
	if landed and not unsaved:
		return true
	var done := StudioFiles.save_draft(history.doc, base_text, drafts_dir, base_doc.sids)
	if done:
		unsaved = false
		saved_at = _clock_of(Time.get_datetime_string_from_system())
	return done


## Starts writing the draft on a worker thread and returns at once, so a frame does not wait for the JSON and the disk.
## False when a write of this draft is already running (poll_write lands it; ask again then). `unsaved` stays true until
## the write has landed, and then only if the doc is still the one that was written.
func save_later() -> bool:
	if _write != null:
		return false
	var write := DraftWrite.new()
	write.doc = history.doc
	write.base_text = base_text
	write.base_sids.assign(base_doc.sids)
	write.drafts_dir = drafts_dir
	write.saved_at = _clock_of(Time.get_datetime_string_from_system())
	# LEARN: the write is a Callable on a WorkerThreadPool task. It stringifies the doc's data while the main thread may
	# read the same data, which is safe because nobody writes it. The task must be waited for (settle or poll_write),
	# or the pool keeps it.
	write.task = WorkerThreadPool.add_task(write.run, false, "Studio draft save")
	_write = write
	return true


## Whether a background write of the draft is running (or finished and not yet landed).
func writing() -> bool:
	return _write != null


## Lands a finished background write, if there is one, without waiting. True when one landed.
func poll_write() -> bool:
	if _write == null or not WorkerThreadPool.is_task_completed(_write.task):
		return false
	return _land()


## Waits for the background write, if there is one, and lands it. True when one landed.
func settle() -> bool:
	return _land() if _write != null else false


func _land() -> bool:
	var write := _write
	_write = null
	WorkerThreadPool.wait_for_task_completion(write.task)
	if write.ok and history.doc == write.doc:
		unsaved = false
		saved_at = write.saved_at
	return true


## "HH:MM" from "2026-10-13T14:02:31".
static func _clock_of(stamp: String) -> String:
	var at := stamp.find("T")
	return stamp.substr(at + 1, 5) if at >= 0 and stamp.length() >= at + 6 else ""
