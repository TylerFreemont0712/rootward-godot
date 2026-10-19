class_name StudioCatalogSession
extends RefCounted
## The catalog being edited (Concept/v0.3/10, sections 7.7 and 8): `catalog.jsonc` as a StudioDoc with its own history
## and its own draft beside the maps' drafts, published by StudioPublish with them. Its edits are `set_entry` commands
## (a remake's entry, its source joining a family); the map's own history is separate, so undoing a remake in the map
## leaves its entry in the draft, where it waits harmlessly until Publish or Revert.
##
##   var catalog := StudioCatalogSession.open(StudioMode.drafts_dir, StudioMode.content_dir)
##   catalog.do({"type": "set_entry", "id": "barrel-2x1", "value": entry})
##   catalog.save()

## What StudioPublish keys the catalog by among the sessions it is given.
const KEY := "catalog"
const RELATIVE := "packs/core/overworld/catalog.jsonc"

var path := ""
var base_text := ""
var base_doc: StudioDoc
var history: StudioHistory
var drafts_dir := StudioFiles.DRAFTS
var unsaved := false
var saved_at := ""


## The catalog of `content_root`, from its draft when there is one, else from the file. Null when neither reads.
static func open(drafts := StudioFiles.DRAFTS, content_root := ContentLoader.ROOT) -> StudioCatalogSession:
	var file := path_of(content_root)
	var text := StudioFiles.read_text(file)
	var parsed := StudioDoc.parse(file, "catalog", text)
	if not bool(parsed.ok):
		return null
	var session := StudioCatalogSession.new()
	session.path = file
	session.drafts_dir = drafts
	session.base_text = text
	session.base_doc = parsed.doc
	var start: StudioDoc = parsed.doc
	var record := StudioFiles.load_draft(file, drafts)
	if bool(record.get("ok", false)) and (record.doc as StudioDoc).kind == "catalog":
		var base := StudioDoc.parse(file, "catalog", String(record.base_text))
		if bool(base.ok):
			session.base_text = String(record.base_text)
			session.base_doc = base.doc
			start = record.doc
			session.saved_at = StudioSession._clock_of(String(record.get("saved_at", "")))
	session.history = StudioHistory.new(start.copy())
	return session


static func path_of(content_root := ContentLoader.ROOT) -> String:
	return content_root.path_join(RELATIVE)


func doc() -> StudioDoc:
	return history.doc


func do(command: Dictionary) -> Dictionary:
	var result := history.do(command)
	if result.ok:
		unsaved = true
	return result


## The draft's entry for `id`, or {} when it has none.
func entry(id: String) -> Dictionary:
	var assets: Dictionary = doc().data.get("assets", {})
	return (assets.get(id, {}) as Dictionary).duplicate(true) if assets.get(id) is Dictionary else {}


## Sets an entry (null removes it) unless it already says exactly that. True when the draft changed.
func set_entry(id: String, value: Variant) -> bool:
	var assets: Dictionary = doc().data.get("assets", {})
	if assets.get(id) == value:
		return false
	return bool(do({"type": "set_entry", "id": id, "value": value}).ok)


func changes() -> int:
	return StudioDiff.lines(base_doc, history.doc).size()


func save() -> bool:
	if changes() == 0:
		StudioFiles.discard_draft(path, drafts_dir)
		unsaved = false
		return true
	var done := StudioFiles.save_draft(history.doc, base_text, drafts_dir)
	if done:
		unsaved = false
		saved_at = StudioSession._clock_of(Time.get_datetime_string_from_system())
	return done
