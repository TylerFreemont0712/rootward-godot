extends Node3D
## One pose from four sides at once, for pose work (ADR-0030): as on the stage, from the front, from her side and from
## behind her shoulder, on a floor with stride lines, the feet planted as in a fight.
##   ROOTWARD_CHARACTER=dummy ROOTWARD_CLIP=idle-breathe ROOTWARD_AT=0 \
##     scripts/screenshot.sh res://tools/pose_views.tscn shots/pose.png 20
## ROOTWARD_REST=1 shows the model as built (no clip, no leg IK); ROOTWARD_ZOOM=1 frames the upper body only.

const VIEWS: Array[Array] = [["stage", 35.0], ["front", 0.0], ["her side", 90.0], ["behind", 150.0]]
const GAP := 1.15


func _ready() -> void:
	var id := OS.get_environment("ROOTWARD_CHARACTER")
	if id == "":
		id = "dummy"
	var clip := OS.get_environment("ROOTWARD_CLIP")
	if clip == "":
		clip = "idle-breathe"
	var at := float(OS.get_environment("ROOTWARD_AT"))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#1d1722")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.62, 0.56, 0.6)
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.basis = Basis.looking_at(-HeroView.KEY_LIGHT)
	add_child(key)
	for i in VIEWS.size():
		var view: Array = VIEWS[i]
		var spot := Vector3((i - 1.5) * GAP * (0.55 if OS.get_environment("ROOTWARD_ZOOM") != "" else 1.0), 0.0, 0.0)
		var hero := StageCharacter.create(id)
		hero.position = spot
		hero.rotation_degrees.y = float(view[1])
		add_child(hero)
		hero.set_light_direction(HeroView.KEY_LIGHT)
		hero.set_limited(0.0)
		if OS.get_environment("ROOTWARD_REST") != "" and hero.player != null:
			# The model as built, no clip and no leg IK.
			hero.player.active = false
			for ik in hero.skeleton.find_children("*", "TwoBoneIK3D", false, false):
				(ik as TwoBoneIK3D).active = false
		elif hero.player != null:
			hero.player.play(clip)
			hero.player.seek(at, true)
			hero.player.pause()
		_floor(spot)
		var label := Label3D.new()
		label.text = String(view[0])
		label.pixel_size = 0.002
		label.position = spot + Vector3(0, -0.12, 0.8)
		add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	# A little above her, looking down, so the stride lines on the floor show where the feet stand.
	camera.position = Vector3(0, 1.85, 6)
	camera.rotation_degrees.x = -9.0
	if OS.get_environment("ROOTWARD_ZOOM") != "":
		# The upper body only, for hands and faces.
		camera.size = 1.15
		camera.position = Vector3(0, 1.25, 6)
		camera.rotation_degrees.x = 0.0
	add_child(camera)


func _floor(spot: Vector3) -> void:
	var lines := StandardMaterial3D.new()
	lines.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lines.albedo_color = Color("#5a4b66")
	for i in range(-3, 4):
		for across: bool in [false, true]:
			var line := MeshInstance3D.new()
			var bar := BoxMesh.new()
			bar.size = Vector3(0.004, 0.004, 1.5) if not across else Vector3(1.0, 0.004, 0.004)
			line.mesh = bar
			line.material_override = lines
			line.position = spot + (Vector3(i * 0.15, 0, 0) if not across else Vector3(0, 0, i * 0.2))
			add_child(line)
