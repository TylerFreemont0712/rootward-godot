extends GdUnitTestSuite
## The game's own content loads clean, and loads into exactly the catalog the old engine built from its YAML
## (fixture shardrun-catalog.json), defaults and all.

const SCRATCH := "user://test-content"


func test_the_content_loads_without_errors() -> void:
	var loaded := ContentLoader.load_shardrun()
	var messages: Array = loaded.diagnostics.map(func(d: Dictionary) -> String: return ContentLoader.describe(d))
	assert_bool(loaded.ok).override_failure_message("\n".join(messages)).is_true()
	assert_int((loaded.catalog.shards as Dictionary).size()).is_equal(77)
	assert_int((loaded.catalog.relics as Dictionary).size()).is_equal(47)
	assert_int((loaded.catalog.foes as Dictionary).size()).is_equal(15)
	# The program run's own foes live beside the Shardrun's, never among them (ADR-0017).
	assert_int((loaded.catalog.programs.foes as Dictionary).size()).is_equal(2)


func test_the_catalog_is_the_old_engines() -> void:
	var catalog: Dictionary = ContentLoader.load_shardrun().catalog
	var want: Dictionary = Fixtures.load_json("shardrun-catalog")
	for part: String in ["config", "shards", "foes", "relics", "balance"]:
		var difference := Fixtures.diff(catalog[part], want[part], part)
		assert_str(difference).override_failure_message(difference).is_empty()


func test_broken_content_is_reported() -> void:
	var root := _scratch_copy()
	_write(root + "/packs/core/shardrun/shards/adapt.jsonc", '{"id": "adapted", "name": "Adapt"}')
	_write(root + "/packs/core/shardrun/relics/patch-kit.jsonc", "{ nope")
	var run := FileAccess.get_file_as_string(root + "/packs/core/shardrun/run.jsonc").replace('"fork"', '"forkk"')
	_write(root + "/packs/core/shardrun/run.jsonc", run)
	DirAccess.remove_absolute(root + "/packs/core/shardrun/shards/amplify.js")
	var loaded := ContentLoader.load_shardrun(root)
	var text := "\n".join(loaded.diagnostics.map(func(d: Dictionary) -> String: return ContentLoader.describe(d)))
	assert_bool(loaded.ok).is_false()
	assert_str(text).contains("[schema] rarity: is required")  # adapt.jsonc lost its fields
	assert_str(text).contains("[parse] line 1")  # patch-kit.jsonc is not JSON
	assert_str(text).contains('unknown shard "forkk"')  # the starting inventory names a shard that does not exist
	assert_str(text).contains('shard "amplify" has no javascript code')


func _scratch_copy() -> String:
	var root := ProjectSettings.globalize_path(SCRATCH)
	OS.execute("rm", ["-rf", root])
	OS.execute("cp", ["-r", ProjectSettings.globalize_path(ContentLoader.ROOT), root])
	return root


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_every_shard_keeps_its_worked_examples() -> void:
	var catalog: Dictionary = ContentLoader.load_shardrun().catalog
	var diagnostics := ShardExamples.check(catalog)
	var messages: Array = diagnostics.map(func(d: Dictionary) -> String: return ContentLoader.describe(d))
	assert_array(messages).override_failure_message("\n".join(messages)).is_empty()
