extends Node3D
## Every clip of the move library played in turn on a VRM skin, lit and turned as on the stage, then quits: for
## Godot's movie writer, so the reel shows the motion itself (spring-bone hair and cloth included), not frozen poses.
##   scripts/moves.sh --reel            (writes shots/moves/reel.mp4 and reel.gif)
## ROOTWARD_SKIN picks the skin (a character id); ROOTWARD_CLIPS picks and orders the clips.

const GAP := 0.35
## How long a cast holds its push before it lets go (a volley's worth).
const HOLD := 1.0

var _label: Label3D


func _ready() -> void:
	var skin := OS.get_environment("ROOTWARD_SKIN")
	if skin == "":
		skin = "dummy"
	var clips := OS.get_environment("ROOTWARD_CLIPS").split(",", false)
	if clips.is_empty():
		clips = PackedStringArray(
			["idle-breathe", "cast-light", "cast-heavy", "guard", "hurt", "channel", "victory", "death"]
		)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#231a2e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.62, 0.56, 0.6)
	environment.environment.ambient_light_energy = 0.9
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 1.1
	key.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	add_child(key)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	camera.position = Vector3(0.35, 1.05, 6)
	add_child(camera)
	_label = Label3D.new()
	_label.pixel_size = 0.0016
	_label.position = Vector3(-0.75, 0.05, 1)
	add_child(_label)
	var hero := StageCharacter.create(skin)
	hero.rotation_degrees.y = 35.0
	add_child(hero)
	hero.set_light_direction(HeroView.KEY_LIGHT)
	await get_tree().create_timer(0.6).timeout
	for clip in clips:
		_label.text = clip
		hero.play(clip)
		var facts: Dictionary = hero.moves.get(clip, {})
		var length: float = facts.get("length", 1.0)
		if clip in StageCharacter.CASTS:
			# Held for a volley's worth, then let go, as on the stage.
			await get_tree().create_timer(length + HOLD).timeout
			hero.end_cast()
			length = float(hero.moves.get(clip + "-end", {}).get("length", 0.5))
		await get_tree().create_timer(length * (2.0 if facts.get("loop", false) else 1.0) + GAP).timeout
		if clip in StageCharacter.HOLDS:
			hero.play(StageCharacter.IDLE)
			await get_tree().create_timer(0.6).timeout
	get_tree().quit()
