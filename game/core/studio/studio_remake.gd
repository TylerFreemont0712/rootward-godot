class_name StudioRemake
extends RefCounted
## Remakes at a new size (Concept/v0.3/10, section 7.7), pure: the id a remake gets, its world-pipeline spec drawn from
## the source's (pipeline/world/README.md), its catalog entry as a variant of the source, and the remake queue's
## bookkeeping. No files and no nodes: StudioRemakes (the scene side) writes the spec, keeps the queue and runs
## `scripts/world.sh make`.
##
##   StudioRemake.id_of("barrel", Vector2i(2, 1))                      # "barrel-2x1"
##   StudioRemake.spec_for(barrel_spec, "barrel-2x1", Vector2i(2, 1))  # {ok, spec}: the parts stretched across
##
## A queue entry is {id, source, size: [w, h], state, message}; the states are queued, running, done and failed.

const QUEUED := "queued"
const RUNNING := "running"
const DONE := "done"
const FAILED := "failed"


## The id a remake of `source` at `size` gets: the source's id and the footprint, "barrel-2x1".
static func id_of(source: String, size: Vector2i) -> String:
	return "%s-%dx%d" % [source, size.x, size.y]


## Whether a spec can be remade: it has a blockout to draw again. An adopted picture (a `source` render or image) has
## none until someone writes one, so the Studio offers its variants instead.
static func can_remake(spec: Dictionary) -> bool:
	return not spec.is_empty() and not spec.has("source") and spec.has("footprint")


## The spec for the remake `id` at `size`: the source's, with the new footprint. A prop's parts stretch across and back
## with the footprint and keep their heights, so it is the same thing, wider or deeper; a tree's canopy widens with it;
## a building's door moves to the new middle column (or to `door` when it is given) and its windows spread over the new
## width, never on the door. {ok: true, spec} or {ok: false, error}. `source` is not changed.
static func spec_for(source: Dictionary, id: String, size: Vector2i, door := -1) -> Dictionary:
	if not can_remake(source):
		return {"ok": false, "error": "%s is an adopted picture with no blockout to remake" % source.get("id", "it")}
	if size.x < 1 or size.y < 1:
		return {"ok": false, "error": "a footprint is at least 1 x 1"}
	var old := OverworldMap.cell_of(source.get("footprint", [1, 1]))
	if size == old:
		return {"ok": false, "error": "it is %d x %d already" % [size.x, size.y]}
	var across := float(size.x) / float(maxi(old.x, 1))
	var back := float(size.y) / float(maxi(old.y, 1))
	var spec: Dictionary = source.duplicate(true)
	spec["id"] = id
	spec["footprint"] = [size.x, size.y]
	match String(spec.get("kind", "")):
		"building":
			var middle := door if door >= 0 and door < size.x else size.x / 2
			spec["door"] = middle
			var windows: Array[int] = []
			for raw: Variant in source.get("windows", []):
				var column := clampi(roundi(float(raw) * across), 0, size.x - 1)
				if column != middle and not column in windows:
					windows.append(column)
			windows.sort()
			spec["windows"] = windows
		"tree":
			var canopy: Variant = source.get("canopy")
			if canopy is Array and (canopy as Array).size() == 2:
				spec["canopy"] = [_tidy(float(canopy[0]) * across), canopy[1]]
	if spec.get("parts") is Array:
		var parts: Array = []
		for raw: Variant in spec.parts:
			var part: Dictionary = (raw as Dictionary).duplicate(true) if raw is Dictionary else {}
			for key: String in ["at", "size"]:
				var box: Variant = part.get(key)
				if box is Array and (box as Array).size() == 3:
					part[key] = [_tidy(float(box[0]) * across), _tidy(float(box[1]) * back), box[2]]
			parts.append(part)
		spec["parts"] = parts
	return {"ok": true, "spec": spec}


## The spec as the file `pipeline/world/objects/<id>.jsonc` holds it: a comment saying where it came from, then one key
## to a line (the parts one to a line), whole numbers as integers.
static func spec_text(spec: Dictionary, source: String) -> String:
	var value: Dictionary = JsoncWriter.normalized(spec)
	var lines := PackedStringArray()
	for key: Variant in value:
		var text := JsoncWriter.compact(value[key])
		if String(key) == "parts" and value[key] is Array and not (value[key] as Array).is_empty():
			var items := PackedStringArray()
			for part: Variant in value[key]:
				items.append("  " + JsoncWriter.compact(part))
			text = "[\n" + ",\n".join(items) + "\n ]"
		lines.append(" %s: %s" % [JSON.stringify(String(key)), text])
	var header := "// A remake of %s at %s, drafted by Lanternroot Studio (Concept/v0.3/10, section 7.7).\n" % [
		source, JsoncWriter.compact(value.get("footprint", [])),
	]
	return header + "{\n" + ",\n".join(lines) + "\n}\n"


## The catalog entry of the remake: the source's (its name, kind, category, places, tags, what may flip), at `size`, in
## the source's family (the source's own id when it had none), its variant named by the size.
static func entry_for(source_id: String, source_entry: Dictionary, size: Vector2i) -> Dictionary:
	var entry: Dictionary = source_entry.duplicate(true)
	entry["size"] = [size.x, size.y]
	entry["family"] = String(source_entry.get("family", source_id))
	entry["variant"] = _size_name(size)
	entry.erase("door")
	if String(entry.get("kind", "")) == "building":
		entry["door"] = [size.x / 2, size.y - 1]
	return entry


## The source's entry as it must be for its remakes to be its variants: in a family (its own id when it had none, with
## its size as the variant's name). Unchanged when it has one already.
static func family_entry(source_id: String, source_entry: Dictionary) -> Dictionary:
	if source_entry.has("family"):
		return source_entry.duplicate(true)
	var entry: Dictionary = source_entry.duplicate(true)
	entry["family"] = source_id
	entry["variant"] = _size_name(OverworldMap.cell_of(source_entry.get("size", [1, 1])))
	return entry


# --- the queue ------------------------------------------------------------------------------------------------------


## The queue with `id` waiting to be made: added, or put back to queued when it failed or was done before. Never twice.
static func enqueue(queue: Array, id: String, source: String, size: Vector2i) -> Array:
	var out: Array = queue.duplicate(true)
	for item: Variant in out:
		if item is Dictionary and String((item as Dictionary).get("id", "")) == id:
			(item as Dictionary)["state"] = QUEUED
			(item as Dictionary)["message"] = ""
			return out
	out.append({"id": id, "source": source, "size": [size.x, size.y], "state": QUEUED, "message": ""})
	return out


## The queue with each of `ids` in `state` (and its `message`, a run's last words when it failed).
static func with_state(queue: Array, ids: Array[String], state: String, message := "") -> Array:
	var out: Array = queue.duplicate(true)
	for item: Variant in out:
		if item is Dictionary and String((item as Dictionary).get("id", "")) in ids:
			(item as Dictionary)["state"] = state
			(item as Dictionary)["message"] = message
	return out


## The ids still to be made, in the queue's order: queued, or failed (a failed one is tried again).
static func waiting(queue: Array) -> Array[String]:
	var ids: Array[String] = []
	for item: Variant in queue:
		if item is Dictionary and String((item as Dictionary).get("state", "")) in [QUEUED, FAILED]:
			ids.append(String((item as Dictionary).get("id", "")))
	return ids


static func state_of(queue: Array, id: String) -> String:
	return String(_item(queue, id).get("state", ""))


static func source_of(queue: Array, id: String) -> String:
	return String(_item(queue, id).get("source", ""))


static func _item(queue: Array, id: String) -> Dictionary:
	for item: Variant in queue:
		if item is Dictionary and String((item as Dictionary).get("id", "")) == id:
			return item as Dictionary
	return {}


static func _size_name(size: Vector2i) -> String:
	return "%d × %d" % [size.x, size.y]


## Four decimals, as the specs write them, without the float noise a product leaves (0.15 x 3 is 0.45, not 0.4499...).
static func _tidy(value: float) -> float:
	return roundf(value * 10000.0) / 10000.0
