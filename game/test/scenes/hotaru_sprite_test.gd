extends GdUnitTestSuite
## Hotaru's brightness (Concept/v0.4/05, section 2.2): the town can set how bright her halo and light are, and -1 brings
## the slow breathing back.

var hotaru: HotaruSprite


func before_test() -> void:
	hotaru = HotaruSprite.new()
	add_child(hotaru)
	await await_idle_frame()


func after_test() -> void:
	hotaru.free()


func test_brightness_sets_her_halo_and_light_at_once() -> void:
	var light := hotaru.get("_light") as PointLight2D
	var halo := hotaru.get("_glow") as Sprite2D
	hotaru.set_brightness(0.0)
	assert_float(light.energy).is_equal_approx(HotaruSprite.LIGHT_ENERGY * HotaruSprite.DIM_BRIGHTNESS, 0.0001)
	assert_float(halo.modulate.a).is_equal_approx(HotaruSprite.DIM_BRIGHTNESS, 0.0001)
	hotaru.set_brightness(1.0)
	assert_float(light.energy).is_equal_approx(HotaruSprite.LIGHT_ENERGY, 0.0001)
	assert_float(halo.modulate.a).is_equal_approx(1.0, 0.0001)


func test_the_brightness_holds_over_a_frame() -> void:
	hotaru.set_brightness(0.5)
	await await_idle_frame()
	var light := hotaru.get("_light") as PointLight2D
	# Halfway between the dimmest (0.15) and full (1.0): 0.575 of the normal energy.
	assert_float(light.energy).is_equal_approx(HotaruSprite.LIGHT_ENERGY * 0.575, 0.0001)


func test_minus_one_brings_the_breathing_back() -> void:
	hotaru.set_brightness(0.0)
	hotaru.set_brightness(-1.0)
	await await_idle_frame()
	var light := hotaru.get("_light") as PointLight2D
	# The breathing pulse is 0.9 plus or minus 0.1, so the light stays between 0.8 and 1.0 of its normal energy.
	assert_float(light.energy).is_between(HotaruSprite.LIGHT_ENERGY * 0.8, HotaruSprite.LIGHT_ENERGY * 1.0001)
