extends "res://tools/overworld_shot.gd"
## A connected enclosure drawn through the real mouse controls, in an isolated Studio draft. Never publishes.
## ROOTWARD_LANTERNTOWN=studio-catalog ROOTWARD_FENCE_SHOT=preview|placed|undo|removed|moved|restored


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
	studio.studio_camera().shown = 2
	studio.focus(Vector2(41, 22) * OverworldScale.TILE)
	studio.set_overlay("grid", true)
	studio.set_place_list(false)
	await _frames(3)
	for line: Array in [
		[Vector2(34, 20), Vector2(44, 20)], [Vector2(44, 20), Vector2(44, 26)],
		[Vector2(44, 26), Vector2(34, 26)], [Vector2(34, 26), Vector2(34, 20)],
		[Vector2(39, 20), Vector2(39, 17)], [Vector2(37, 23), Vector2(46, 23)],
	]:
		await _stroke(studio, "fence", line[0], line[1])
	await _stroke(studio, "gate", Vector2(39, 26), Vector2(39, 26))
	await _stroke(studio, "gate_v", Vector2(44, 25), Vector2(44, 25))
	var moment := OS.get_environment("ROOTWARD_FENCE_SHOT")
	if moment in ["removed", "moved", "restored"]:
		for index: int in studio.work.doc().sids.size():
			if OverworldMap.cell_of(studio.work.raw(index).get("at", [])) == Vector2i(39, 20):
				var sid := studio.work.sid_at(index)
				if moment == "moved":
					studio.work.move([sid], Vector2i.DOWN)
				else:
					studio.work.delete([sid], true)
					if moment == "restored":
						studio.work.undo()
				break
	studio.start_place("fence")
	_mouse(studio, Vector2(48, 18), true)
	_motion(studio, Vector2(48, 19))
	_motion(studio, Vector2(51, 25))
	if moment != "preview":
		_mouse(studio, Vector2(51, 25), false)
		studio.arrange.stop_placing()
		if moment == "undo":
			studio.work.undo()
	await _frames(3)


func _stroke(studio: StudioMode, art: String, from: Vector2, to: Vector2) -> void:
	studio.start_place(art)
	_mouse(studio, from, true)
	_motion(studio, to)
	_mouse(studio, to, false)
	await _frames(1)


func _mouse(studio: StudioMode, cell: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = _catcher_point(studio, cell)
	studio._world_input(event)


func _motion(studio: StudioMode, cell: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _catcher_point(studio, cell)
	studio._world_input(event)
