extends GdUnitTestSuite
## Lanternroot's catalog against the real content (ADR-0066, Concept/v0.3/10-lanternroot-studio.md section 8): every
## picture a map can use and every townsperson has exactly one valid entry, and every building or prop entry has a
## source the Studio can show: new (drawn for the 40 px tile) or old (enlarged until it is remade).

const CATALOG := "res://content/packs/core/overworld/catalog.jsonc"
const TOWNSFOLK := "res://content/packs/core/overworld/townsfolk.jsonc"
const PICTURE_FOLDERS: Array[String] = ["world", "props", "buildings"]


## The parsed JSONC object at `path`, or {} when it does not parse.
static func _parsed(path: String) -> Dictionary:
	var parsed: Dictionary = Jsonc.parse(FileAccess.get_file_as_string(path))
	var value: Variant = parsed.get("value", null)
	return value as Dictionary if parsed.get("ok", false) and value is Dictionary else {}


## Every picture id per folder: the .png files on disk, each unioned with the folder's index where one exists.
static func _pictures() -> Dictionary:
	var pictures: Dictionary = {}
	for folder: String in PICTURE_FOLDERS:
		var ids: Array[String] = []
		for file: String in DirAccess.get_files_at("res://assets/overworld/%s/" % folder):
			if file.ends_with(".png"):
				ids.append(file.get_basename())
		for id: Variant in OverworldArt.index(folder).keys():
			if not ids.has(String(id)):
				ids.append(String(id))
		pictures[folder] = ids
	return pictures


static func _people() -> Array[String]:
	var people: Array[String] = []
	for id: Variant in _parsed(TOWNSFOLK).keys():
		people.append(String(id))
	return people


func test_every_picture_and_townsperson_has_exactly_one_valid_entry() -> void:
	var catalog := _parsed(CATALOG)
	assert_dict(catalog).override_failure_message("the catalog did not parse").is_not_empty()

	var problems := StudioCatalog.coverage(catalog["assets"], catalog["categories"], _pictures(), _people())
	assert_array(problems).override_failure_message("the catalog has problems: %s" % [problems]).is_empty()


func test_a_picture_without_an_entry_fails_the_check() -> void:
	var catalog := _parsed(CATALOG)
	var pictures := _pictures()
	var props: Array = pictures["props"]
	props.append("no-such-entry")

	var problems := StudioCatalog.coverage(catalog["assets"], catalog["categories"], pictures, _people())
	assert_array(problems).override_failure_message("problems: %s" % [problems]).has_size(1)
	assert_str(problems[0]).contains("no-such-entry")


func test_an_entry_naming_a_missing_picture_fails_the_check() -> void:
	var catalog := _parsed(CATALOG)
	var assets: Dictionary = (catalog["assets"] as Dictionary).duplicate(true)
	assets["ghost-prop"] = {"name": "Ghost", "kind": "prop", "category": "nature", "subcategory": "trees"}

	var problems := StudioCatalog.coverage(assets, catalog["categories"], _pictures(), _people())
	assert_array(problems).is_equal(["ghost-prop names no picture"])


func test_old_and_new_sources_are_known_for_every_placeable_picture() -> void:
	var assets: Dictionary = _parsed(CATALOG).get("assets", {})
	var new_count := 0
	var old_count := 0
	var bad: Array[String] = []
	for art: String in assets:
		var entry: Dictionary = assets[art]
		var kind := String(entry.get("kind", ""))
		if kind != "building" and kind != "prop":
			continue
		var folder := "buildings" if kind == "building" else "props"
		var scale: float = OverworldArt.art_scale(folder, art)
		if not is_finite(scale) or scale < 1.0:
			bad.append("%s (%s) has scale %s" % [art, kind, scale])
		elif scale == 1.0:
			new_count += 1
		else:
			old_count += 1
	print("catalog sources: %d new (40 px), %d old (enlarged)" % [new_count, old_count])
	assert_array(bad).override_failure_message("pictures without a usable source: %s" % [bad]).is_empty()
