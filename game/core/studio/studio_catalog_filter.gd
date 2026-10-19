class_name StudioCatalogFilter
extends RefCounted
## Search and filter the Studio's catalog entries without changing the catalog data.
##
## Entries are keyed by art id. Every key combines with the others by AND, and within one Array key the values are
## any-of. A missing key, a value of the wrong type, or (except `ids`) an empty Array leaves that dimension unrestricted.
## Words and values are normalised (lowercase, underscores as spaces); art ids are matched exactly.
##
## - `text` (String): every word must match the entry's id, name, tags, category or subcategory.
## - `category`, `subcategory` (String): the entry's category or subcategory id.
## - `place` (String, "indoor" or "outdoor"): one of the entry's places. `places` (Array): any of them.
## - `kind` (String, "building", "prop", "person", "marker" (a warp or the start), "warp" or "start").
## - `footprints` (Array): "1x1", "2x1", "1x2", "2x2" or "bigger", as StudioCatalog.footprint_class gives the entry's size.
## - `solidity` (Array): "solid" or "walkable"; an entry is walkable when its `solid` is false.
## - `flat` (bool): true keeps only entries drawn on the ground layer (`draw_layer` "ground").
## - `code` (bool): true keeps only entries with a non-empty `interactive` field (they take code).
## - `sources` (Array): "new" or "old", against the `source` field the caller adds to its copy of an entry. An entry
##   with no `source` never passes.
## - `ids` (Array of art ids): the result is only those ids. Present, even empty, it restricts; absent, it does not.
## - `order` (Array of art ids): the result comes in this order, and the other ids follow in the default order.
## - `build_groups` (Array): construction groups from StudioBuildCatalog; unset leaves Objects unrestricted.
## The optional caller `scope` uses the same criteria and is intersected before the user's filters.

const KINDS: Array[String] = ["building", "prop", "person", "marker", "warp", "start"]


## The art ids that pass every filter, sorted by display name and then art id; with `order`, the listed ids first.
static func query(entries: Dictionary, filters: Dictionary = {}, scope: Dictionary = {}) -> Array[String]:
	var criteria: Dictionary = _criteria(filters)
	var scoped: Dictionary = _criteria(scope)
	var positions: Dictionary = criteria["order"]
	var ids: Array[String] = []
	var names: Dictionary = {}
	var seen_ids: Dictionary = {}
	for raw_id: Variant in entries.keys():
		var art_id: String = _string_value(raw_id)
		if art_id.is_empty() or seen_ids.has(art_id):
			continue
		seen_ids[art_id] = true
		var raw_entry: Variant = entries[raw_id]
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		# LEARN: caller scope is a separate intersection, so Recent, search and Reset cannot escape a workspace.
		if not _in_ids(art_id, scoped) or not _matches(entry, art_id, scoped):
			continue
		if not _in_ids(art_id, criteria) or not _matches(entry, art_id, criteria):
			continue
		ids.append(art_id)
		names[art_id] = _display_name(entry, art_id)
	ids.sort_custom(
		func(first_id: String, second_id: String) -> bool:
			var first_rank: int = _rank(positions, first_id)
			var second_rank: int = _rank(positions, second_id)
			if first_rank != second_rank:
				return first_rank < second_rank
			var name_order: int = String(names[first_id]).naturalnocasecmp_to(String(names[second_id]))
			if name_order != 0:
				return name_order < 0
			var id_order: int = first_id.naturalnocasecmp_to(second_id)
			if id_order != 0:
				return id_order < 0
			return first_id < second_id
	)
	return ids


## The filters read once: each value normalised, and each Array key reduced to its strings.
static func _criteria(filters: Dictionary) -> Dictionary:
	var criteria: Dictionary = {
		"words": _words(_filter_value(filters, "text")),
		"category": _filter_value(filters, "category"),
		"subcategory": _filter_value(filters, "subcategory"),
		"place": _filter_value(filters, "place"),
		"kind": _filter_value(filters, "kind"),
		"places": _values(filters, "places"),
		"footprints": _values(filters, "footprints"),
		"solidity": _values(filters, "solidity"),
		"flat": _flag(filters, "flat"),
		"code": _flag(filters, "code"),
		"sources": _values(filters, "sources"),
		"build_groups": _values(filters, "build_groups"),
		"order": _order(filters),
	}
	var raw_ids: Variant = filters.get("ids", null)
	if typeof(raw_ids) == TYPE_ARRAY:
		var listed: Array = raw_ids
		criteria["ids"] = _id_set(listed)
	return criteria


static func _in_ids(art_id: String, criteria: Dictionary) -> bool:
	if not criteria.has("ids"):
		return true
	var allowed: Dictionary = criteria["ids"]
	return allowed.has(art_id)


static func _matches(entry: Dictionary, art_id: String, criteria: Dictionary) -> bool:
	var build_groups: Array[String] = criteria["build_groups"]
	if not build_groups.is_empty() and not build_groups.has(StudioBuildCatalog.group(entry)):
		return false
	var words: Array[String] = criteria["words"]
	if not _matches_text(entry, art_id, words):
		return false
	var category_filter: String = criteria["category"]
	if not category_filter.is_empty() and _normalized(_string_value(entry.get("category", ""))) != category_filter:
		return false
	var subcategory_filter: String = criteria["subcategory"]
	if (
		not subcategory_filter.is_empty()
		and _normalized(_string_value(entry.get("subcategory", ""))) != subcategory_filter
	):
		return false
	var place_filter: String = criteria["place"]
	if not _matches_place(entry.get("place", null), place_filter):
		return false
	var kind_filter: String = criteria["kind"]
	if not _matches_kind(entry.get("kind", ""), kind_filter):
		return false
	var places: Array[String] = criteria["places"]
	if not _matches_places(entry.get("place", null), places):
		return false
	var footprints: Array[String] = criteria["footprints"]
	if not _matches_footprints(entry, footprints):
		return false
	var solidity: Array[String] = criteria["solidity"]
	if not _matches_solidity(entry, solidity):
		return false
	var flat: bool = criteria["flat"]
	if flat and _normalized(_string_value(entry.get("draw_layer", ""))) != "ground":
		return false
	var code: bool = criteria["code"]
	if code and not _takes_code(entry.get("interactive", null)):
		return false
	var sources: Array[String] = criteria["sources"]
	if not _matches_sources(entry, sources):
		return false
	return true


static func _matches_text(entry: Dictionary, art_id: String, words: Array[String]) -> bool:
	if words.is_empty():
		return true
	var parts: PackedStringArray = PackedStringArray()
	parts.append(_normalized(art_id))
	parts.append(_normalized(_display_name(entry, art_id)))
	parts.append(_normalized(_string_value(entry.get("category", ""))))
	parts.append(_normalized(_string_value(entry.get("subcategory", ""))))
	var raw_tags: Variant = entry.get("tags", [])
	if typeof(raw_tags) == TYPE_ARRAY:
		for raw_tag: Variant in raw_tags:
			var tag: String = _string_value(raw_tag)
			if not tag.is_empty():
				parts.append(_normalized(tag))
	var haystack: String = " ".join(parts)
	for word: String in words:
		if not haystack.contains(word):
			return false
	return true


static func _matches_place(value: Variant, place_filter: String) -> bool:
	if place_filter.is_empty():
		return true
	if place_filter != "indoor" and place_filter != "outdoor":
		return false
	if typeof(value) != TYPE_ARRAY:
		return false
	for raw_place: Variant in value:
		if _normalized(_string_value(raw_place)) == place_filter:
			return true
	return false


static func _matches_places(value: Variant, places: Array[String]) -> bool:
	if places.is_empty():
		return true
	if typeof(value) != TYPE_ARRAY:
		return false
	for raw_place: Variant in value:
		if places.has(_normalized(_string_value(raw_place))):
			return true
	return false


static func _matches_kind(value: Variant, kind_filter: String) -> bool:
	if kind_filter.is_empty():
		return true
	if not kind_filter in KINDS:
		return false
	var kind := _normalized(_string_value(value))
	# "marker" is the warps and the start flag together.
	if kind_filter == "marker":
		return kind == "warp" or kind == "start"
	return kind == kind_filter


static func _matches_footprints(entry: Dictionary, footprints: Array[String]) -> bool:
	if footprints.is_empty():
		return true
	return footprints.has(StudioCatalog.footprint_class(entry.get("size", [1, 1])))


static func _matches_solidity(entry: Dictionary, solidity: Array[String]) -> bool:
	if solidity.is_empty():
		return true
	var solid: Variant = entry.get("solid", true)
	var state := "walkable" if typeof(solid) == TYPE_BOOL and not bool(solid) else "solid"
	return solidity.has(state)


## An entry takes code when its `interactive` field is a non-empty Array, Dictionary or String.
static func _takes_code(value: Variant) -> bool:
	if typeof(value) == TYPE_ARRAY:
		return not (value as Array).is_empty()
	if typeof(value) == TYPE_DICTIONARY:
		return not (value as Dictionary).is_empty()
	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		return not String(value).strip_edges().is_empty()
	return false


static func _matches_sources(entry: Dictionary, sources: Array[String]) -> bool:
	if sources.is_empty():
		return true
	return sources.has(_normalized(_string_value(entry.get("source", ""))))


static func _display_name(entry: Dictionary, art_id: String) -> String:
	var name: String = _string_value(entry.get("name", "")).strip_edges()
	return name if not name.is_empty() else art_id


static func _filter_value(filters: Dictionary, key: String) -> String:
	return _normalized(_string_value(filters.get(key, "")))


## The normalised, non-empty string values of an Array key, each once. Empty when the key is missing, is not an Array,
## or holds no strings, so it leaves the dimension unrestricted.
static func _values(filters: Dictionary, key: String) -> Array[String]:
	var values: Array[String] = []
	var raw: Variant = filters.get(key, [])
	if typeof(raw) != TYPE_ARRAY:
		return values
	for item: Variant in raw:
		var value: String = _normalized(_string_value(item))
		if not value.is_empty() and not values.has(value):
			values.append(value)
	return values


## A boolean key: true only when the key holds the boolean true. Anything else leaves the dimension open.
static func _flag(filters: Dictionary, key: String) -> bool:
	var raw: Variant = filters.get(key, false)
	return typeof(raw) == TYPE_BOOL and bool(raw)


## The art ids an `ids` key lists, matched exactly. Values that are not strings match nothing.
static func _id_set(listed: Array) -> Dictionary:
	var allowed: Dictionary = {}
	for raw_id: Variant in listed:
		var art_id: String = _string_value(raw_id)
		if not art_id.is_empty():
			allowed[art_id] = true
	return allowed


## The `order` key as art id -> position, each id at the first place it is listed. Empty when the key is not an Array.
static func _order(filters: Dictionary) -> Dictionary:
	var positions: Dictionary = {}
	var raw: Variant = filters.get("order", [])
	if typeof(raw) != TYPE_ARRAY:
		return positions
	var listed: Array = raw
	for raw_id: Variant in listed:
		var art_id: String = _string_value(raw_id)
		if not art_id.is_empty() and not positions.has(art_id):
			positions[art_id] = positions.size()
	return positions


## An id's place in `order`; an id that is not listed comes after every listed one.
static func _rank(positions: Dictionary, art_id: String) -> int:
	return int(positions.get(art_id, positions.size()))


static func _words(value: String) -> Array[String]:
	var words: Array[String] = []
	for word: String in _normalized(value).split(" ", false):
		if not word.is_empty():
			words.append(word)
	return words


static func _normalized(value: String) -> String:
	var prepared: String = value.to_lower().replace("_", " ").replace("\t", " ").replace("\n", " ").replace("\r", " ")
	var words: PackedStringArray = PackedStringArray()
	for part: String in prepared.split(" ", false):
		var word: String = part.strip_edges()
		if not word.is_empty():
			words.append(word)
	return " ".join(words)


static func _string_value(value: Variant) -> String:
	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		return String(value)
	return ""
