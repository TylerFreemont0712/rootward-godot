extends "res://tools/overworld_shot.gd"
## Isolated Studio review: joined corners, gates in both directions and a pending drag. Never publishes content.
## ROOTWARD_LANTERNTOWN=studio-catalog scripts/screenshot.sh res://tools/studio_boundary_shot.tscn shots/studio/boundaries.png 30


func _catalog(studio: StudioMode) -> void:
	var commands: Array = []
	for sid: int in studio.work.doc().sids:
		commands.append({"type": "remove", "sid": sid})
	studio.work.command({"type": "batch", "name": "Clear screenshot stage", "commands": commands})
	var rows: Array[String] = []
	for y: int in studio.current_map().height:
		rows.append(".".repeat(int(studio.current_map().width)))
	studio.work.command({"type": "set_map", "key": "legend", "value": {".": "grass"}})
	studio.work.command({"type": "set_map", "key": "ground", "value": rows})
	for i: int in 4:
		var material: String = ["fieldstone", "brick", "plaster", "log"][i]
		var base := "expand-" + material + "_wall"
		var origin := Vector2i(32 + i * 5, 20)
		_piece(studio, base + "_corner_se", origin)
		_piece(studio, base + "_corner_sw", origin + Vector2i(3, 0))
		_piece(studio, base + "_corner_ne", origin + Vector2i(0, 4))
		_piece(studio, base + "_corner", origin + Vector2i(3, 4))
		for x: int in [1, 2]:
			_piece(studio, base, origin + Vector2i(x, 0))
			_piece(studio, "gate" if x == 1 else base, origin + Vector2i(x, 4))
		for y: int in [1, 2, 3]:
			_piece(studio, "gate_v" if y == 2 else base + "_v", origin + Vector2i(0, y))
			_piece(studio, base + "_v", origin + Vector2i(3, y))
	for i: int in 3:
		var art: String = ["gate", "expand-arched_wood_gate", "expand-iron_garden_gate"][i]
		_piece(studio, art, Vector2i(34 + i * 5, 27))
		_piece(studio, art + "_v", Vector2i(36 + i * 5, 27))
	studio.studio_camera().shown = 2
	studio.focus(Vector2(41.5, 23.5) * OverworldScale.TILE)
	studio.set_overlay("grid", true)
	studio.set_place_list(false)
	await _frames(4)
	studio.start_place("expand-fieldstone_wall")
	var from := Vector2(33, 30)
	var to := Vector2(39, 30)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = _catcher_point(studio, from)
	studio._world_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = _catcher_point(studio, to)
	studio._world_input(motion)
	if OS.get_environment("ROOTWARD_BOUNDARY_RESULT") == "1":
		studio.arrange.cancel()
		_piece(studio, "barrel", Vector2i(36, 30))
		studio.start_place("fence")
		studio._world_input(press)
		studio._world_input(motion)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = motion.position
		release.pressed = false
		studio._world_input(release)


func _piece(studio: StudioMode, art: String, cell: Vector2i) -> void:
	studio.work.place(StudioAssets.template(art), cell)
