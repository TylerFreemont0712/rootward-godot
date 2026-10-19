extends GdUnitTestSuite
## Lanternroot's full map (v0.4, Concept/v0.4/01 section 9.3): it opens and closes (Esc, M, a click on the shade), its
## legend lists every ground the player's colours cover, and the map takes the largest whole-number scale that fits.

const TERRAIN := {"grass": {"walk": true}, "water": {"walk": false}}
const COLOURS := {
	"grass": Color("#6fbf5b"),
	"flowers": Color("#ec8fb3"),
	"water": Color("#4a90d9"),
	"building": Color("#8a4f2c"),
	"tree": Color("#2f6b34"),
	"thing": Color("#e2c04f"),
}
const DATA := {
	"id": "small",
	"name": "Small",
	"legend": {".": "grass", "~": "water"},
	"ground": ["......", ".~~~..", "......"],
	"objects": [],
	"start": [0, 0],
}

var full: FullMap
var map: Dictionary


func before_test() -> void:
	map = OverworldMap.build(DATA, TERRAIN).map
	full = FullMap.new()
	add_child(full)
	await get_tree().process_frame


func after_test() -> void:
	Sound.silence()
	full.free()


func _open() -> void:
	var people: Array[Vector2i] = [Vector2i(4, 2)]
	full.open(map, COLOURS, [{"name": "The Pond", "x": 1, "y": 1, "w": 3, "h": 1}], Vector2i(0, 0), people, Vector2i(5, 0))
	await get_tree().process_frame


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		get_tree().root.push_input(event)


func test_it_opens_and_closes_and_says_so() -> void:
	var closed := [0]
	full.closed.connect(func() -> void: closed[0] += 1)
	assert_bool(full.is_open()).is_false()
	assert_bool(full.visible).is_false()
	await _open()
	assert_bool(full.is_open()).is_true()
	assert_bool(full.visible).is_true()
	full.close()
	assert_bool(full.is_open()).is_false()
	assert_int(closed[0]).is_equal(1)
	full.close()
	assert_int(closed[0]).override_failure_message("closing twice says so once").is_equal(1)


func test_escape_closes_it() -> void:
	await _open()
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	assert_bool(full.is_open()).is_false()


func test_m_closes_it() -> void:
	await _open()
	_key(KEY_M)
	await get_tree().process_frame
	assert_bool(full.is_open()).is_false()


func test_the_legend_lists_every_ground_with_its_colour() -> void:
	await _open()
	var grounds := full.legend_grounds()
	for ground: String in COLOURS:
		assert_bool(grounds.has(ground)).override_failure_message("%s is in the legend" % ground).is_true()
		assert_object(full.find_child("Row_" + ground, true, false)).is_not_null()
	assert_int(grounds.size()).is_equal(COLOURS.size())
	assert_str((full.find_child("Note", true, false) as Label).text).is_equal("Drawn with your map_colour()")


func test_the_legend_names_the_colours_when_the_players_code_gave_names() -> void:
	full.set_colour_names({"water": "blue", "grass": "green"})
	await _open()
	assert_str((full.find_child("Row_water", true, false) as Label).text).is_equal("water: blue")
	assert_str((full.find_child("Row_flowers", true, false) as Label).text).is_equal("flowers")


func test_the_map_takes_the_largest_whole_number_scale_that_fits() -> void:
	assert_int(FullMap.scale_for(Vector2(880, 700), Vector2i(80, 56))).is_equal(11)
	assert_int(FullMap.scale_for(Vector2(879, 700), Vector2i(80, 56))).is_equal(10)
	assert_int(FullMap.scale_for(Vector2(900, 500), Vector2i(80, 56))).is_equal(8)
	assert_int(FullMap.scale_for(Vector2(10, 10), Vector2i(80, 56))).is_equal(1)
	await _open()
	await get_tree().process_frame
	var view := full.find_child("View", true, false) as Control
	assert_int(full.current_scale()).is_equal(FullMap.scale_for(view.size, Vector2i(6, 3)))
	assert_int(full.current_scale()).is_greater(3)
