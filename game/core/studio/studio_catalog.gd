class_name StudioCatalog
extends RefCounted
## The rules of Lanternroot Studio's asset catalog (ADR-0066; Concept/v0.3/10-lanternroot-studio.md, section 8): what a
## complete catalog says, how an entry's size is named, how the category tree is counted, the families of variants and
## the Recent list. Plain data in, plain data out: no file or node is read and no input is changed. The catalog itself
## is content/packs/core/overworld/catalog.jsonc.

const FOLDERS: Array[String] = ["world", "props", "buildings"]
const PICTURE_KINDS: Array[String] = ["building", "prop", "sign"]
const REQUIRED_FIELDS: Array[String] = ["name", "kind", "category", "subcategory"]
const FOOTPRINTS: Array[String] = ["1x1", "2x1", "1x2", "2x2"]
## Pictures that are the bag's item icons (v0.4, items.jsonc's "icon"), not things to place: they need no entry.
const ICON_PREFIX := "item-"


## The problems with a catalog, as short English sentences sorted alphabetically; empty when every picture and
## townsperson has exactly one valid entry. `assets` is the catalog's `assets` object, `categories` its tree, `pictures`
## the picture ids of each folder (without `.png`) and `people` the townsfolk ids. Malformed input is skipped.
static func coverage(
	assets: Dictionary, categories: Array, pictures: Dictionary, people: Array[String]
) -> Array[String]:
	var problems: Array[String] = []
	var named: Dictionary = {}
	for folder: String in FOLDERS:
		for picture: String in _id_list(pictures.get(folder, [])):
			named[picture] = true
			if picture.begins_with(ICON_PREFIX):
				continue
			if not assets.has(picture):
				problems.append("picture %s (%s) has no catalog entry" % [picture, folder])
	var townsfolk: Dictionary = {}
	for person: String in people:
		if not _id_of(person).is_empty():
			townsfolk[person] = true
	for person: String in townsfolk:
		if not assets.has(person):
			problems.append("townsperson %s has no catalog entry" % person)
	var subcategories := _subcategories_by_category(categories)
	for raw_id: Variant in assets.keys():
		var art_id := _id_of(raw_id)
		if art_id.is_empty():
			continue
		var raw_entry: Variant = assets[raw_id]
		if typeof(raw_entry) != TYPE_DICTIONARY:
			problems.append("%s: not an object" % art_id)
			continue
		var entry: Dictionary = raw_entry
		problems.append_array(_line_problems(art_id, entry, assets))
		problems.append_array(_connection_problems(art_id, entry, assets))
		for field: String in REQUIRED_FIELDS:
			if _id_of(entry.get(field, "")).is_empty():
				problems.append("%s: missing %s" % [art_id, field])
		var kind := _string_value(entry.get("kind", ""))
		if kind == "person" and not townsfolk.has(art_id):
			problems.append("%s is a person entry but not a townsperson" % art_id)
		if PICTURE_KINDS.has(kind) and not named.has(art_id):
			problems.append("%s names no picture" % art_id)
		var category := _id_of(entry.get("category", ""))
		if category.is_empty():
			continue
		if not subcategories.has(category):
			problems.append("%s: unknown category %s" % [art_id, category])
			continue
		var subcategory := _id_of(entry.get("subcategory", ""))
		var known: Dictionary = subcategories[category]
		if not subcategory.is_empty() and not known.has(subcategory):
			problems.append("%s: unknown subcategory %s in %s" % [art_id, subcategory, category])
	problems.sort()
	return problems


## Modular line pairs are editor metadata, never map fields. Check both orientations before Publish can save a
## catalog that would preview a missing picture or silently switch an instance to another footprint.
static func _line_problems(art: String, entry: Dictionary, entries: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if not entry.has("line"):
		return problems
	if not entry.line is Dictionary:
		return ["%s: line must name horizontal and vertical pieces" % art]
	for axis: String in ["horizontal", "vertical"]:
		var target := _string_value((entry.line as Dictionary).get(axis, ""))
		var other: Variant = entries.get(target)
		if not other is Dictionary:
			problems.append("%s: line %s names no entry" % [art, axis])
		elif String((other as Dictionary).get("kind", "")) != "prop" or _dimensions((other as Dictionary).get("size", [1, 1])) != Vector2i.ONE:
			problems.append("%s: line %s must name a 1 x 1 prop" % [art, axis])
	return problems


## The footprint a catalog size names: "1x1", "2x1" (width by height), "1x2", "2x2", or "bigger" for any other valid
## size. A size that is missing or malformed is "1x1". A valid size is a pair of whole numbers of at least 1, as a
## JSON array (its numbers may be floats such as 2.0) or as a Vector2i.
static func footprint_class(size: Variant) -> String:
	var dimensions := _dimensions(size)
	if dimensions == Vector2i.ZERO:
		return "1x1"
	var label := "%dx%d" % [dimensions.x, dimensions.y]
	return label if FOOTPRINTS.has(label) else "bigger"


## A connected material needs every mask and valid one-cell pictures; gates can restrict their exposed sockets.
static func _connection_problems(art: String, entry: Dictionary, entries: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if entry.has("sockets"):
		var sockets: Variant = entry.sockets
		if typeof(sockets) not in [TYPE_INT, TYPE_FLOAT] or float(sockets) != floorf(float(sockets)) or float(sockets) < 0 or float(sockets) > 15:
			problems.append("%s: sockets must be a whole neighbor mask from 0 to 15" % art)
	if entry.has("join"):
		var root: Variant = entries.get(_id_of(entry.join))
		if not root is Dictionary or not (root as Dictionary).get("connections") is Dictionary:
			problems.append("%s: join names no connected material" % art)
	if not entry.has("connections"):
		return problems
	if not entry.connections is Dictionary:
		problems.append("%s: connections must map all sixteen neighbor masks" % art)
		return problems
	var connections: Dictionary = entry.connections
	for mask: int in 16:
		var target := _id_of(connections.get(str(mask), ""))
		var other: Variant = entries.get(target)
		if not other is Dictionary:
			problems.append("%s: connection %d names no entry" % [art, mask])
		elif String((other as Dictionary).get("kind", "")) != "prop" or _dimensions((other as Dictionary).get("size", [1, 1])) != Vector2i.ONE or _id_of((other as Dictionary).get("join", "")) != art:
			problems.append("%s: connection %d must name a 1 x 1 prop of this material" % [art, mask])
	return problems


## The categories, in the given order, that have at least one entry, each with its entry count and its subcategories
## that have entries, in the given order. An entry counts toward its category and toward its subcategory; an entry
## whose category is not in the tree is not listed. A missing name is shown as the id.
static func tree(categories: Array, entries: Dictionary) -> Array[Dictionary]:
	var category_counts: Dictionary = {}
	var subcategory_counts: Dictionary = {}
	for raw_id: Variant in entries.keys():
		var raw_entry: Variant = entries[raw_id]
		if _id_of(raw_id).is_empty() or typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		var category := _id_of(entry.get("category", ""))
		var subcategory := _id_of(entry.get("subcategory", ""))
		category_counts[category] = int(category_counts.get(category, 0)) + 1
		if not subcategory_counts.has(category):
			subcategory_counts[category] = {}
		var by_subcategory: Dictionary = subcategory_counts[category]
		by_subcategory[subcategory] = int(by_subcategory.get(subcategory, 0)) + 1
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_category: Variant in categories:
		if typeof(raw_category) != TYPE_DICTIONARY:
			continue
		var category: Dictionary = raw_category
		var category_id := _id_of(category.get("id", ""))
		var count := int(category_counts.get(category_id, 0))
		if category_id.is_empty() or count == 0 or seen.has(category_id):
			continue
		seen[category_id] = true
		var by_subcategory: Dictionary = subcategory_counts[category_id]
		var subcategories: Array[Dictionary] = []
		var seen_subcategories: Dictionary = {}
		for raw_subcategory: Variant in _dictionaries(category.get("subcategories", [])):
			var subcategory: Dictionary = raw_subcategory
			var subcategory_id := _id_of(subcategory.get("id", ""))
			var subcategory_count := int(by_subcategory.get(subcategory_id, 0))
			if subcategory_id.is_empty() or subcategory_count == 0 or seen_subcategories.has(subcategory_id):
				continue
			seen_subcategories[subcategory_id] = true
			subcategories.append(
				{"id": subcategory_id, "name": _name_of(subcategory, subcategory_id), "count": subcategory_count}
			)
		out.append(
			{
				"id": category_id,
				"name": _name_of(category, category_id),
				"count": count,
				"subcategories": subcategories,
			}
		)
	return out


## Family id -> the art ids of its variants, in the entries' order. Entries without a non-empty `family` are not listed.
static func families(entries: Dictionary) -> Dictionary:
	var found: Dictionary = {}
	for raw_id: Variant in entries.keys():
		var raw_entry: Variant = entries[raw_id]
		var art_id := _id_of(raw_id)
		if art_id.is_empty() or typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var family := _id_of((raw_entry as Dictionary).get("family", ""))
		if family.is_empty():
			continue
		if not found.has(family):
			var fresh: Array[String] = []
			found[family] = fresh
		var members: Array[String] = found[family]
		members.append(art_id)
	return found


## The art `step` places along `art`'s family (wrapping round, in the entries' order), or "" when `art` has no family,
## its family has no other variant, or `step` is 0. `[` and `]` in the Studio (Concept/v0.3/10, section 7.7).
static func variant_of(entries: Dictionary, art: String, step: int) -> String:
	var raw_entry: Variant = entries.get(art, null)
	if step == 0 or typeof(raw_entry) != TYPE_DICTIONARY:
		return ""
	var family := _id_of((raw_entry as Dictionary).get("family", ""))
	if family.is_empty():
		return ""
	var members: Array[String] = []
	members.assign(families(entries).get(family, []))
	if members.size() < 2:
		return ""
	return members[posmod(members.find(art) + step, members.size())]


## Where a thing at `at` with footprint `from` stands as footprint `to` with its feet (the bottom-middle cell, the one
## StudioWork.footing takes) kept: a variant of another size swapped in place.
static func keep_feet(at: Vector2i, from: Vector2i, to: Vector2i) -> Vector2i:
	var feet := at + Vector2i(from.x / 2, from.y - 1)
	return feet - Vector2i(to.x / 2, to.y - 1)


## `recent` with `art` first, without duplicates or empty ids, and at most `limit` items. An empty `art` returns a copy
## of `recent`. `recent` is not changed.
static func remember(recent: Array[String], art: String, limit := 12) -> Array[String]:
	var out: Array[String] = []
	if art.strip_edges().is_empty():
		out.assign(recent)
		return out
	if limit <= 0:
		return out
	out.append(art)
	for item: String in recent:
		if out.size() >= limit:
			break
		if item.is_empty() or out.has(item):
			continue
		out.append(item)
	return out


## The subcategory ids of each category id in the tree; a category given twice keeps both lists.
static func _subcategories_by_category(categories: Array) -> Dictionary:
	var found: Dictionary = {}
	for raw_category: Variant in _dictionaries(categories):
		var category: Dictionary = raw_category
		var category_id := _id_of(category.get("id", ""))
		if category_id.is_empty():
			continue
		if not found.has(category_id):
			found[category_id] = {}
		var known: Dictionary = found[category_id]
		for raw_subcategory: Variant in _dictionaries(category.get("subcategories", [])):
			var subcategory_id := _id_of((raw_subcategory as Dictionary).get("id", ""))
			if not subcategory_id.is_empty():
				known[subcategory_id] = true
	return found


## The Dictionary members of a value that should be an Array; anything else is none.
static func _dictionaries(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	var listed: Array = value
	for item: Variant in listed:
		if typeof(item) == TYPE_DICTIONARY:
			out.append(item)
	return out


## The non-empty string members of a value that should be an Array of ids.
static func _id_list(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return out
	var listed: Array = value
	for item: Variant in listed:
		var id := _id_of(item)
		if not id.is_empty() and not out.has(id):
			out.append(id)
	return out


## A string id, unchanged, or "" when the value is not a string or is only spaces.
static func _id_of(value: Variant) -> String:
	var text := _string_value(value)
	return text if not text.strip_edges().is_empty() else ""


static func _name_of(source: Dictionary, fallback: String) -> String:
	var name := _string_value(source.get("name", "")).strip_edges()
	return name if not name.is_empty() else fallback


static func _dimensions(size: Variant) -> Vector2i:
	var parts: Array = []
	if typeof(size) == TYPE_VECTOR2I:
		var vector: Vector2i = size
		parts = [vector.x, vector.y]
	elif typeof(size) == TYPE_ARRAY:
		parts = size
	if parts.size() != 2:
		return Vector2i.ZERO
	var sides: Array[int] = []
	for part: Variant in parts:
		if typeof(part) != TYPE_INT and typeof(part) != TYPE_FLOAT:
			return Vector2i.ZERO
		var number := float(part)
		if not is_finite(number) or number < 1.0 or number != floorf(number):
			return Vector2i.ZERO
		sides.append(int(number))
	return Vector2i(sides[0], sides[1])


static func _string_value(value: Variant) -> String:
	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		return String(value)
	return ""
