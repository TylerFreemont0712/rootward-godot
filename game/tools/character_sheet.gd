extends Node3D
## A character on a plain background for checking an export: the top row turns it (front, three-quarter, side, back),
## the rows below freeze every clip at `POSE_AT` of its length. Screenshot it with
##   scripts/screenshot.sh res://tools/character_sheet.tscn shots/emberfox-sheet.png
## The character is `ROOTWARD_CHARACTER` from the environment, Emberfox by default.

const SPACING := 1.35
## Where the top row stands; the clip rows are below it.
const TOP := 1.85
const POSE_AT := 0.45
const PER_ROW := 6


func _ready() -> void:
	var id := OS.get_environment("ROOTWARD_CHARACTER")
	if id == "":
		id = "emberfox"
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.24, 0.23, 0.29)
	add_child(environment)

	if OS.get_environment("ROOTWARD_SHEET") == "close":
		_close_up(id)
		return
	var turns: Array[float] = [0.0, 35.0, 90.0, 180.0]
	for i in turns.size():
		var fox := _place(id, Vector3((i - 1.5) * SPACING, TOP, 0))
		fox.rotation_degrees.y = turns[i]
	var probe := StageCharacter.create(id)
	var clips: PackedStringArray = probe.player.get_animation_list() if probe.player != null else PackedStringArray()
	probe.free()
	for i in clips.size():
		var column := i % PER_ROW
		var row := i / PER_ROW
		var fox := _place(id, Vector3((column - (PER_ROW - 1) / 2.0) * SPACING, -0.1 - row * 1.95, 0))
		fox.rotation_degrees.y = 35.0
		_freeze(fox, clips[i])
		var label := Label3D.new()
		label.text = clips[i]
		label.pixel_size = 0.0022
		label.position = Vector3(0, -0.12, 0.3)
		fox.add_child(label)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.6
	camera.position = Vector3(0, 0.15, 6)
	add_child(camera)


## One character, large, in the three-quarter view the stage uses, for judging shading and ink up close.
func _close_up(id: String) -> void:
	var fox := _place(id, Vector3.ZERO)
	fox.rotation_degrees.y = 35.0
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.7
	camera.position = Vector3(0.15, 0.8, 6)
	add_child(camera)


func _place(id: String, at: Vector3) -> StageCharacter:
	var fox := StageCharacter.create(id)
	fox.position = at
	add_child(fox)
	return fox


func _freeze(fox: StageCharacter, clip: String) -> void:
	if fox.player == null:
		return
	fox.player.play(clip)
	fox.player.seek(fox.player.get_animation(clip).length * POSE_AT, true)
	fox.player.pause()
