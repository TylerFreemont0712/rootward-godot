class_name StudioAssetReview
extends RefCounted
## Asset-wide art feedback is independent of map edits and deduplicated by art id. Resolving keeps the notes.


static func put(records: Dictionary, art: String, details: Dictionary, stamp: String) -> Dictionary:
	var out := records.duplicate(true)
	var entry: Dictionary = out.get(art, {}).duplicate(true)
	if entry.is_empty():
		entry = {"art": art, "created_at": stamp, "notes": "", "prompt": ""}
	entry.merge(details, true)
	entry["art"] = art
	entry["updated_at"] = stamp
	entry["state"] = "needs_update"
	out[art] = entry
	return out


static func resolve(records: Dictionary, art: String, stamp: String) -> Dictionary:
	var out := records.duplicate(true)
	if out.has(art):
		out[art]["state"] = "reviewed"
		out[art]["updated_at"] = stamp
	return out


static func pending(records: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for art: String in records:
		if records[art] is Dictionary and String(records[art].get("state", "")) == "needs_update":
			ids.append(art)
	ids.sort()
	return ids


## Prompted replacements are new variants, so a retry is reproducible and never overwrites its source art.
static func replacement_id(art: String, prompt: String) -> String:
	return art + "-update-" + prompt.strip_edges().sha256_text().left(8)
