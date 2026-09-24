extends GdUnitTestSuite

const FOE := {
	"type": "object",
	"fields":
	{
		"id": Schema.ID,
		"hp": {"type": "int", "min": 1},
		"weak": {"type": "list", "item": {"type": "enum", "values": ["fire", "frost"]}, "default": []},
		"note": {"type": "text", "optional": true},
	},
}


func test_fills_defaults_and_makes_whole_numbers_ints() -> void:
	var result := Schema.check(FOE, {"id": "wisp", "hp": 20.0})
	assert_array(result.errors).is_empty()
	assert_that(result.value).is_equal({"id": "wisp", "hp": 20, "weak": []})
	assert_bool(result.value.hp is int).is_true()


func test_reports_every_problem_with_its_path() -> void:
	var result := Schema.check(FOE, {"id": "Wisp!", "hp": 0, "weak": ["fire", "arcane"], "extra": true})
	var errors: Array = result.errors
	assert_int(errors.size()).is_equal(4)
	assert_str(" | ".join(errors)).contains('id: "Wisp!" is not an id').contains("hp: must be at least 1")
	assert_str(" | ".join(errors)).contains("weak[1]: must be one of fire, frost").contains('unknown field "extra"')


func test_required_fields() -> void:
	assert_str(" ".join(Schema.check(FOE, {"id": "wisp"}).errors)).contains("hp: is required")


func test_unions_pick_by_kind() -> void:
	var intent := Schema.union({"strike": {"power": {"type": "int", "min": 1}}, "stoke": {}})
	assert_array(Schema.check(intent, {"kind": "strike", "power": 3}).errors).is_empty()
	assert_array(Schema.check(intent, {"kind": "stoke"}).errors).is_empty()
	assert_str(" ".join(Schema.check(intent, {"kind": "stoke", "power": 1}).errors)).contains("unknown field")
	assert_str(" ".join(Schema.check(intent, {"kind": "dance"}).errors)).contains("must be one of strike, stoke")


func test_exhaustive_records() -> void:
	var weights := Schema.record({"type": "number", "min": 0.0}, ["common", "rare"])
	assert_array(Schema.check(weights, {"common": 1, "rare": 0.5}).errors).is_empty()
	assert_str(" ".join(Schema.check(weights, {"common": 1}).errors)).contains("rare: is required")
	assert_str(" ".join(Schema.check(weights, {"common": 1, "rare": 1, "epic": 1}).errors)).contains("unknown key")
