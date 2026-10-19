extends GdUnitTestSuite
## StudioRemake (Concept/v0.3/10, section 7.7): a remake's id, its world-pipeline spec drawn from the source's, its
## catalog entry as a variant of the source, and the remake queue's bookkeeping. Pure: plain data in and out.

const BARREL := {
	"id": "barrel",
	"kind": "prop",
	"what": "an oak barrel with iron hoops",
	"footprint": [1, 1],
	"ramps": {"staves": "wood", "hoops": "steel"},
	"parts": [
		{"shape": "cylinder", "at": [0.15, 0.15, 0], "size": [0.7, 0.7, 0.9], "ramp": "staves"},
		{"shape": "cylinder", "at": [0.12, 0.12, 0.18], "size": [0.76, 0.76, 0.08], "ramp": "hoops"},
	],
}
const COTTAGE := {
	"id": "cottage",
	"kind": "building",
	"what": "a small cottage",
	"footprint": [5, 5],
	"walls": 2.4,
	"roof": "gable",
	"door": 2,
	"windows": [0, 4],
	"ramps": {"walls": "plaster", "roof": "thatch"},
}
const ADOPTED := {"id": "inn", "kind": "building", "footprint": [6, 6], "source": {"picture": "ow-building-inn", "pick": 1}}


func test_id_names_the_source_and_the_size() -> void:
	assert_str(StudioRemake.id_of("barrel", Vector2i(2, 1))).is_equal("barrel-2x1")
	assert_str(StudioRemake.id_of("cottage", Vector2i(6, 6))).is_equal("cottage-6x6")


func test_only_a_spec_with_a_blockout_can_be_remade() -> void:
	assert_bool(StudioRemake.can_remake(BARREL)).is_true()
	assert_bool(StudioRemake.can_remake(COTTAGE)).is_true()
	assert_bool(StudioRemake.can_remake(ADOPTED)).is_false()
	assert_bool(StudioRemake.can_remake({})).is_false()


func test_a_prop_stretches_across_and_back_and_keeps_its_heights() -> void:
	var made := StudioRemake.spec_for(BARREL, "barrel-2x1", Vector2i(2, 1))
	assert_bool(made.ok).is_true()
	var spec: Dictionary = made.spec
	assert_str(spec.id).is_equal("barrel-2x1")
	assert_array(spec.footprint).is_equal([2, 1])
	assert_str(spec.what).is_equal(BARREL.what)
	var staves: Dictionary = spec.parts[0]
	assert_array(staves.at).is_equal([0.3, 0.15, 0])
	assert_array(staves.size).is_equal([1.4, 0.7, 0.9])
	assert_dict(spec.ramps).is_equal(BARREL.ramps)
	# The source is not changed.
	assert_array(BARREL.parts[0].at).is_equal([0.15, 0.15, 0])


func test_a_building_moves_its_door_to_the_new_middle_and_spreads_its_windows() -> void:
	var made := StudioRemake.spec_for(COTTAGE, "cottage-6x6", Vector2i(6, 6))
	assert_bool(made.ok).is_true()
	assert_int(made.spec.door).is_equal(3)
	assert_array(made.spec.windows).is_equal([0, 5])
	assert_array(made.spec.footprint).is_equal([6, 6])
	var chosen := StudioRemake.spec_for(COTTAGE, "cottage-6x6", Vector2i(6, 6), 1)
	assert_int(chosen.spec.door).is_equal(1)


func test_an_adopted_picture_or_a_bad_size_is_refused_with_a_reason() -> void:
	var adopted := StudioRemake.spec_for(ADOPTED, "inn-7x6", Vector2i(7, 6))
	assert_bool(adopted.ok).is_false()
	assert_str(adopted.error).contains("adopted")
	assert_bool(StudioRemake.spec_for(BARREL, "barrel-0x1", Vector2i(0, 1)).ok).is_false()
	assert_bool(StudioRemake.spec_for(BARREL, "barrel", Vector2i(1, 1)).ok).is_false()


func test_the_catalog_entry_is_a_variant_of_the_source_at_its_size() -> void:
	var source := {"name": "Barrel", "kind": "prop", "category": "farm_and_work", "subcategory": "containers", "place": ["outdoor"], "tags": ["wood"], "size": [1, 1], "flippable": true}
	var entry := StudioRemake.entry_for("barrel", source, Vector2i(2, 1))
	assert_str(entry.name).is_equal("Barrel")
	assert_array(entry.size).is_equal([2, 1])
	assert_str(entry.family).is_equal("barrel")
	assert_str(entry.variant).is_equal("2 × 1")
	assert_str(entry.category).is_equal("farm_and_work")
	assert_bool(entry.flippable).is_true()
	var family := StudioRemake.family_entry("barrel", source)
	assert_str(family.family).is_equal("barrel")
	assert_str(family.variant).is_equal("1 × 1")
	assert_bool(source.has("family")).is_false()
	var oak := {"name": "Oak", "kind": "prop", "size": [1, 1], "family": "oak", "variant": "Round"}
	assert_str(StudioRemake.entry_for("oak", oak, Vector2i(2, 2)).family).is_equal("oak")
	assert_dict(StudioRemake.family_entry("oak", oak)).is_equal(oak)


func test_the_queue_keeps_one_entry_per_id_and_tracks_states() -> void:
	var queue: Array = []
	queue = StudioRemake.enqueue(queue, "barrel-2x1", "barrel", Vector2i(2, 1))
	queue = StudioRemake.enqueue(queue, "barrel-2x1", "barrel", Vector2i(2, 1))
	queue = StudioRemake.enqueue(queue, "bench-3x1", "bench", Vector2i(3, 1))
	assert_int(queue.size()).is_equal(2)
	assert_array(StudioRemake.waiting(queue)).is_equal(["barrel-2x1", "bench-3x1"])
	queue = StudioRemake.with_state(queue, ["barrel-2x1"], "running")
	assert_array(StudioRemake.waiting(queue)).is_equal(["bench-3x1"])
	queue = StudioRemake.with_state(queue, ["barrel-2x1"], "failed", "ComfyUI did not start")
	assert_str(StudioRemake.state_of(queue, "barrel-2x1")).is_equal("failed")
	assert_str(queue[0].message).is_equal("ComfyUI did not start")
	assert_array(StudioRemake.waiting(queue)).is_equal(["barrel-2x1", "bench-3x1"])
	queue = StudioRemake.with_state(queue, ["barrel-2x1", "bench-3x1"], "done")
	assert_array(StudioRemake.waiting(queue)).is_empty()
	assert_str(StudioRemake.source_of(queue, "bench-3x1")).is_equal("bench")
	assert_str(StudioRemake.state_of(queue, "nothing")).is_equal("")


func test_spec_text_has_a_header_and_whole_numbers() -> void:
	var made := StudioRemake.spec_for(BARREL, "barrel-2x1", Vector2i(2, 1))
	var text := StudioRemake.spec_text(made.spec, "barrel")
	assert_bool(text.begins_with("// ")).is_true()
	assert_str(text).contains("barrel")
	var parsed := Jsonc.parse(text)
	assert_bool(parsed.ok).is_true()
	assert_str(text).contains('"footprint": [2, 1]')
	assert_str(text).not_contains("2.0")
