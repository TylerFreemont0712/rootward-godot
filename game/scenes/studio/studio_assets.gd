class_name StudioAssets
extends RefCounted
## The pictures a map can use, read from the overworld's catalog.jsonc (Concept/v0.3/10, section 8): the Studio's plain
## list for placing in phase S1, and what a flip may do. A missing or broken catalog gives an empty list and the
## S1 rules (props flip, buildings and people do not), so the Studio still works.
##
##   StudioAssets.placeable()            # ["apple", "banner", "barrel", ...] by name
##   StudioAssets.template("barrel")     # {"kind": "prop", "art": "barrel"}: the object a new barrel starts as
##   StudioAssets.template("pell")       # {"kind": "person", "id": "pell", "facing": "down"}

const PATH := "res://content/packs/core/overworld/catalog.jsonc"
const KINDS: Array[String] = ["building", "prop"]
## The kinds the place panel lists: pictures, townspeople and the map's markers (S6).
const PLACEABLE_KINDS: Array[String] = ["building", "prop", "person", "warp", "start"]
## Cards that are not in catalog.jsonc: a warp and the start flag (Concept/v0.3/10, section 9). The catalog file stays
## as it is (Publish checks the file, not these); `entries()` and `categories()` add them.
const MARKERS := {
	"marker-warp":
	{
		"name": "Warp",
		"kind": "warp",
		"category": "markers",
		"subcategory": "warps",
		"place": ["indoor", "outdoor"],
		"tags": ["door", "exit", "link"],
	},
	"marker-start":
	{
		"name": "Start",
		"kind": "start",
		"category": "markers",
		"subcategory": "start",
		"place": ["indoor", "outdoor"],
		"tags": ["flag", "spawn", "arrive"],
	},
}
const MARKER_CATEGORY := {
	"id": "markers",
	"name": "Markers",
	"icon": "flag",
	"subcategories": [{"id": "warps", "name": "Warps"}, {"id": "start", "name": "Start"}],
}

static var _entries: Dictionary = {}
static var _categories: Array[Dictionary] = []
static var _loaded_from := ""
## The catalog draft's entries while the Studio holds one (a remake's entry before Publish); {} for the file's.
static var draft_entries: Dictionary = {}


## Art id -> the catalog entry (name, kind, size, door, solid, draw_layer, flippable ...): the draft's while there is
## one, else the catalog file of the Studio's content (`path`, when given, reads that file instead).
static func entries(path := "") -> Dictionary:
	if path == "" and not draft_entries.is_empty():
		return draft_entries.merged(MARKERS.duplicate(true))
	if path == "":
		path = StudioCatalogSession.path_of(StudioMode.content_dir)
	if _loaded_from != path:
		_loaded_from = path
		_entries = {}
		_categories = []
		var parsed := Jsonc.parse(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
		if parsed.get("ok", false) and parsed.value is Dictionary:
			var assets: Variant = (parsed.value as Dictionary).get("assets", {})
			if assets is Dictionary:
				_entries = JsoncWriter.normalized(assets)
			var tree: Variant = (parsed.value as Dictionary).get("categories", [])
			if tree is Array:
				for category: Variant in tree:
					if category is Dictionary:
						_categories.append((category as Dictionary).duplicate(true))
		_entries.merge(MARKERS.duplicate(true))
	return _entries


## Reads the catalog file again next time (after Publish wrote it).
static func reload() -> void:
	_loaded_from = ""
	draft_entries = {}


## The catalog's named category/subcategory tree for browsing; callers receive a copy.
static func categories() -> Array[Dictionary]:
	entries(StudioCatalogSession.path_of(StudioMode.content_dir))
	var all := _categories.duplicate(true)
	all.append(MARKER_CATEGORY.duplicate(true))
	return all


static func entry_of(art: String) -> Dictionary:
	var entry: Variant = entries().get(art, {})
	return entry as Dictionary if entry is Dictionary else {}


## The art ids that can be placed from the list (buildings, props, people and the two markers), by name.
static func placeable() -> Array[String]:
	var ids: Array[String] = []
	for art: String in entries():
		if String(entry_of(art).get("kind", "")) in PLACEABLE_KINDS:
			ids.append(art)
	# LEARN: by name, then by id, as the catalog's filter sorts (StudioCatalogFilter.query): one name that begins another
	# ("Fieldstone wall", "Fieldstone wall (end on)") comes first in both.
	ids.sort_custom(
		func(a: String, b: String) -> bool:
			var by_name := name_of(a).naturalnocasecmp_to(name_of(b))
			return by_name < 0 if by_name != 0 else a.naturalnocasecmp_to(b) < 0
	)
	return ids


static func name_of(art: String) -> String:
	return String(entry_of(art).get("name", art))


## The object a new placement of `art` starts as, with no `at` yet: the catalog entry's kind, its size when it is not
## 1 x 1, its door (buildings), solid only when false, and its draw layer. Keys come in the files' order.
static func template(art: String) -> Dictionary:
	var entry := entry_of(art)
	var kind := String(entry.get("kind", "prop"))
	match kind:
		"person":
			return {"kind": "person", "id": art, "facing": "down"}
		"warp", "start":
			return {"kind": kind}
	var object := {"kind": kind, "art": art}
	var size: Variant = entry.get("size", [1, 1])
	if kind == "building" or (size is Array and size != [1, 1]):
		object["size"] = size
	if kind == "building" and entry.has("door"):
		object["door"] = entry["door"]
	if entry.has("solid") and not bool(entry["solid"]):
		object["solid"] = false
	if entry.has("draw_layer"):
		object["draw_layer"] = entry["draw_layer"]
	for key: String in ["sink", "group"]:
		if entry.has(key):
			object[key] = entry[key]
	return object


## Whether an object (its kind and art) may be flipped. The catalog decides when it has an entry; without one, any
## prop may flip, and buildings, signs and people may not.
static func can_flip(object: Dictionary) -> bool:
	var entry := entry_of(String(object.get("art", "")))
	if not entry.is_empty() and entry.has("flippable"):
		return bool(entry["flippable"]) and not String(object.get("kind", "")) in ["building", "person", "warp"]
	return String(object.get("kind", "")) == "prop" and String(object.get("art", "")) != "sign"
