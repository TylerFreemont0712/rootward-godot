extends Node3D
## The move library on a VRM skin, for review: one row per clip, the clip frozen at even steps across its length
## (the last column is its end), turned toward the foes as on the stage. The release frame is ringed in gold.
##   ROOTWARD_SKIN=res://characters/<id>/<id>.vrm ROOTWARD_CLIPS=cast-light,cast-heavy \
##     scripts/screenshot.sh res://tools/moves_sheet.tscn shots/moves/cast.png 20
## Spring bones do not settle in a frozen frame; watch `scripts/moves.sh --reel` for the motion itself.

const LIBRARY := "res://characters/moves/rootward.glb"
const COLUMNS := 7
const SPACING := Vector2(1.25, 2.35)

var _meta: Dictionary = {}


func _ready() -> void:
	var skin := OS.get_environment("ROOTWARD_SKIN")
	var clips := OS.get_environment("ROOTWARD_CLIPS").split(",", false)
	var file := FileAccess.open("res://characters/moves/moves.json", FileAccess.READ)
	_meta = JSON.parse_string(file.get_as_text()) as Dictionary
	if clips.is_empty():
		clips = PackedStringArray((_meta.clips as Dictionary).keys())
	_stage()
	var library := load(LIBRARY) as AnimationLibrary
	for row in clips.size():
		var clip: String = clips[row]
		var facts: Dictionary = _meta.clips.get(clip, {})
		var length: float = facts.get("length", 1.0)
		var release: Variant = facts.get("release")
		for column in COLUMNS:
			var at := length * column / (COLUMNS - 1)
			var near_release := release != null and absf(at - float(release)) < length / (COLUMNS - 1) * 0.5
			if near_release:
				at = float(release)
			var where := Vector3((column - (COLUMNS - 1) / 2.0) * SPACING.x, -row * SPACING.y, 0)
			_pose(skin, library, clip, at, where)
			var label := Label3D.new()
			label.text = "%s  %.2fs" % [clip, at] if column == 0 else "%.2fs" % at
			label.modulate = Color(1.0, 0.85, 0.3) if near_release else Color(0.85, 0.85, 0.9)
			label.pixel_size = 0.0022
			label.position = where + Vector3(0, -0.12, 0.6)
			add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = SPACING.y * clips.size() + 0.3
	camera.position = Vector3(0, 1.05 - (clips.size() - 1) * SPACING.y / 2.0, 8)
	add_child(camera)


func _stage() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.2, 0.19, 0.25)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.6, 0.6, 0.66)
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)


func _pose(skin: String, library: AnimationLibrary, clip: String, at: float, where: Vector3) -> void:
	var model := (load(skin) as PackedScene).instantiate() as Node3D
	model.position = where
	model.rotation_degrees.y = 35.0
	add_child(model)
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	player.add_animation_library("moves", library)
	player.play("moves/" + clip)
	player.seek(at, true)
	player.pause()
