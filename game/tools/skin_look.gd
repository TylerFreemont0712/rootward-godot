extends Node3D
## One skin on a neutral ground for look development (ADR-0029): full length or a face close-up, turned toward the
## foes as on the stage, lit by the stage's key light, optionally frozen in a clip.
##   ROOTWARD_CHARACTER=anby ROOTWARD_LOOK=face ROOTWARD_CLIP=cast-light ROOTWARD_AT=0.7 \
##     scripts/screenshot.sh res://tools/skin_look.tscn shots/look/anby-face.png 20

const TURN := 35.0


func _ready() -> void:
	var id := OS.get_environment("ROOTWARD_CHARACTER")
	var look := OS.get_environment("ROOTWARD_LOOK")
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.25, 0.25, 0.26)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.62, 0.56, 0.6)
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.basis = Basis.looking_at(-HeroView.KEY_LIGHT)
	add_child(key)
	var hero := StageCharacter.create(id)
	hero.rotation_degrees.y = TURN
	add_child(hero)
	hero.set_light_direction(HeroView.KEY_LIGHT)
	var clip := OS.get_environment("ROOTWARD_CLIP")
	if clip != "" and hero.player != null:
		# Straight into the clip: a cross-fade from the idle would not advance while the player is paused.
		hero.player.play(clip)
		hero.player.seek(float(OS.get_environment("ROOTWARD_AT")), true)
		hero.player.pause()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	if look == "face":
		camera.size = 0.42
		camera.position = Vector3(0.0, 1.38, 6)
	else:
		camera.size = 1.8
		camera.position = Vector3(0.0, 0.85, 6)
	add_child(camera)
