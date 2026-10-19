class_name StudioDoc
extends RefCounted
## One content file being edited (Concept/v0.3/10, section 9.2): its data as the loader reads it, its comment header
## kept word for word, and the hash of the text it came from, so a change is one comparison away.
##
##   var parsed := StudioDoc.parse(path, "map", text)   # {ok: true, doc} or {ok: false, error, line}
##   var edited := doc.copy()
##   edited.data["objects"][0]["at"] = [1, 1]           # plain data; commands make such edits
##
## Map objects have no ids in their files, so each one gets a session id (sid) here: sids[i] belongs to
## data.objects[i]. The sids live beside the data and are never written.

## The kinds of content file a doc can be, each with its canonical writer in JsoncWriter.
const KINDS: Array[String] = ["map", "catalog", "quests", "talk", "schedules"]

var path: String = ""
var kind: String = ""
var header: String = ""
var data: Dictionary = {}
var base_hash: String = ""
var sids: Array[int] = []
var next_sid: int = 1


## {ok: true, doc} or {ok: false, error, line}. The objects of a map get the sids 1 to n in file order.
static func parse(path_text: String, kind_name: String, text: String) -> Dictionary:
	if not kind_name in KINDS:
		return {"ok": false, "error": "no writer for kind %s" % kind_name, "line": 0}
	var parsed := Jsonc.parse(text)
	if not parsed["ok"]:
		return {"ok": false, "error": parsed["error"], "line": parsed["line"]}
	var value: Variant = parsed["value"]
	if typeof(value) != TYPE_DICTIONARY:
		return {"ok": false, "error": "the file is not a JSON object", "line": 1}
	var doc := StudioDoc.new()
	doc.path = path_text
	doc.kind = kind_name
	doc.header = JsoncWriter.header_of(text)
	doc.data = JsoncWriter.normalized(value)
	doc.base_hash = text.sha256_text()
	var count := 0
	var objects: Variant = doc.data.get("objects", [])
	if typeof(objects) == TYPE_ARRAY:
		count = (objects as Array).size()
	for i in count:
		doc.sids.append(i + 1)
	doc.next_sid = count + 1
	return {"ok": true, "doc": doc}


## A deep copy: changing the copy's data or sids leaves this doc as it was.
func copy() -> StudioDoc:
	var out := StudioDoc.new()
	out.path = path
	out.kind = kind
	out.header = header
	out.data = data.duplicate(true)
	out.base_hash = base_hash
	out.sids = sids.duplicate()
	out.next_sid = next_sid
	return out


## The text the doc would be written as now, in its kind's canonical form. Quests and talk have no objects, so no sids.
func to_text() -> String:
	match kind:
		"catalog":
			return JsoncWriter.catalog_text(header, data)
		"quests":
			return JsoncWriter.quests_text(header, data)
		"talk":
			return JsoncWriter.talk_text(header, data)
		"schedules":
			return JsoncWriter.schedules_text(header, data)
	return JsoncWriter.map_text(header, data)


## The position in data.objects of the object with this sid, or -1 when there is none.
func index_of_sid(sid: int) -> int:
	return sids.find(sid)


## A copy of the object with this sid, or {} when there is none. Change an object through a command, not this copy.
func object_of_sid(sid: int) -> Dictionary:
	var index := index_of_sid(sid)
	var objects: Array = data.get("objects", [])
	if index < 0 or index >= objects.size():
		return {}
	return (objects[index] as Dictionary).duplicate(true)


## True when writing the doc now would give text different from the file it was read from.
func changed() -> bool:
	return to_text().sha256_text() != base_hash
