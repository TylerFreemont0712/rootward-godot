extends GdUnitTestSuite
## The anime look (ADR-0029): a VRM skin restyled from MToon into the anime shaders keeps its textures and its own
## painted shade, gets one flat-lit face, and ink lines on request; a skin folder is found only with a skin.json.


func test_a_vrm_skin_restyles_into_the_anime_shaders() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("shibu"))
	var made := AnimeSkin.restyle_vrm(hero.model, true, 0.35)
	# One material per source material: the hair's fifty surfaces share one.
	assert_int(made.size()).is_between(5, 20)
	var faces := made.filter(func(m: ShaderMaterial) -> bool: return AnimeSkin.is_face(m))
	assert_int(faces.size()).is_equal(1)
	var body: ShaderMaterial = made.filter(func(m: ShaderMaterial) -> bool: return not AnimeSkin.is_face(m))[0]
	assert_object(body.get_shader_parameter("diffuse")).is_not_null()
	assert_bool(body.get_shader_parameter("use_shade_map")).is_true()
	assert_object(body.next_pass).is_not_null()
	assert_object((body.next_pass as ShaderMaterial).shader).is_equal(AnimeSkin.OUTLINE)


func test_without_ink_there_is_no_line_pass() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("shibu"))
	for material in AnimeSkin.restyle_vrm(hero.model, false, 0.0):
		assert_object(material.next_pass).is_null()


func test_the_light_direction_reaches_every_anime_material() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("shibu"))
	hero.materials = AnimeSkin.restyle_vrm(hero.model, false, 0.0)
	hero.set_light_direction(Vector3(0, 2, 0))
	for material in hero.materials:
		assert_vector(material.get_shader_parameter("light_dir")).is_equal(Vector3.UP)


func test_skin_folders_need_a_skin_json() -> void:
	assert_str(AnimeSkin.folder("shibu")).is_empty()
	assert_str(AnimeSkin.folder("nobody")).is_empty()


func test_all_skins_start_with_the_shipped_ones() -> void:
	var skins := Settings.all_skins()
	assert_array(skins.slice(0, Settings.CHARACTER_SKINS.size())).is_equal(Settings.CHARACTER_SKINS)
