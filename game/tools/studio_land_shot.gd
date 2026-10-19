extends "res://tools/overworld_shot.gd"
## Isolated Land/area-selection review. ROOTWARD_LANTERNTOWN=studio-catalog ROOTWARD_LAND_SHOT=surfaces|area|cleared


func _catalog(studio: StudioMode) -> void:
	var commands: Array = []
	for sid: int in studio.work.doc().sids:
		commands.append({"type": "remove", "sid": sid})
	studio.work.command({"type": "batch", "name": "Clear review stage", "commands": commands})
	var rows: Array[String] = []
	for y in int(studio.current_map().height):
		rows.append(".".repeat(int(studio.current_map().width)))
	studio.work.command({"type": "set_map", "key": "legend", "value": {".": "grass"}})
	studio.work.command({"type": "set_map", "key": "ground", "value": rows})
	for option: String in ["grid", "footprints", "solid", "doors", "talk", "labels", "player"]:
		studio.set_overlay(option, false)
	studio.set_place_list(false)
	if OS.get_environment("ROOTWARD_LAND_SHOT") in ["joins", "joins-close"]:
		await _joins(studio)
	elif OS.get_environment("ROOTWARD_LAND_SHOT") in ["area", "cleared"]:
		await _forest(studio)
	else:
		await _surfaces(studio)
	await _frames(5)


func _joins(studio: StudioMode) -> void:
	studio.studio_camera().shown = 2 if OS.get_environment("ROOTWARD_LAND_SHOT") == "joins-close" else 1
	studio.focus(Vector2(40, 26) * OverworldScale.TILE)
	studio.set_tab("land")
	studio.work.paint(StudioLand.rect(Vector2i(21, 14), Vector2i(60, 39)), "meadow")
	var lanes: Array[Dictionary] = [
		{"kind": "path", "y": 18},
		{"kind": "brick_path", "y": 23},
		{"kind": "stone_path", "y": 29},
		{"kind": "wood_path", "y": 34},
	]
	for lane: Dictionary in lanes:
		var kind := String(lane.kind)
		var y := int(lane.y)
		studio.work.paint(StudioLand.rect(Vector2i(24, y), Vector2i(56, y)), kind)
		# A short, three-wide spur makes it easy to check that only the outside of a connected path is rimmed.
		studio.work.paint(StudioLand.rect(Vector2i(38, y - 1), Vector2i(47, y + 1)), kind)
		var label := Label.new()
		label.text = "Dirt path" if kind == "path" else kind.replace("_", " ").capitalize()
		label.position = Vector2(24, y) * OverworldScale.TILE + Vector2(4, -25)
		label.scale = Vector2.ONE / studio.camera().zoom.x
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("#fff4dc"))
		label.add_theme_color_override("font_shadow_color", Color("#2a1d2b"))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.z_index = 100
		studio.map_view().add_child(label)
	studio.set_ground("path")
	studio.set_brush(3)
	await _park_mouse()
	studio.say("Four road materials share connected edges; three-wide centers remain unframed.", false)


func _surfaces(studio: StudioMode) -> void:
	studio.studio_camera().shown = 1
	studio.focus(Vector2(40, 25) * OverworldScale.TILE)
	studio.studio_camera().fit_map()
	studio.set_tab("land")
	var kinds := studio.land.grounds()
	for index in kinds.size():
		var at := Vector2i(21 + (index % 4) * 8, 11 + (index / 4) * 6)
		studio.work.paint(StudioLand.rect(at, at + Vector2i(5, 3)), kinds[index])
		var label := Label.new()
		label.text = "Dirt path" if kinds[index] == "path" else kinds[index].replace("_", " ").capitalize()
		label.position = Vector2(at * OverworldScale.TILE) + Vector2(4, -25)
		label.scale = Vector2.ONE / studio.camera().zoom.x
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("#fff4dc"))
		label.add_theme_color_override("font_shadow_color", Color("#2a1d2b"))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.z_index = 100
		studio.map_view().add_child(label)
	studio.set_ground("tilled_soil")
	studio.set_land_tool("rect")
	await _park_mouse()
	studio.say("Nineteen outdoor surfaces, eight stable texture variants each.", false)


func _forest(studio: StudioMode) -> void:
	studio.studio_camera().shown = 2
	studio.focus(Vector2(40, 25) * OverworldScale.TILE)
	studio.set_tab("objects")
	for y in 2:
		for x in 4:
			studio.work.place(StudioAssets.template("oak" if (x + y) % 2 == 0 else "birch"), Vector2i(33 + x * 4, 23 + y * 4))
	studio.work.place(StudioAssets.template("barrel"), Vector2i(39, 25))
	studio.start_area_select()
	studio.set_area_filter("trees")
	await _frames(3)
	_move_cursor(studio, Vector2i(33, 23))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = studio.get("_cursor")
	studio._world_input(press)
	_move_cursor(studio, Vector2i(41, 27))
	await _frames(2)
	if OS.get_environment("ROOTWARD_LAND_SHOT") == "cleared":
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = studio.get("_cursor")
		studio._world_input(release)
		studio.request_delete()
		studio.say("Six trees cleared in one undo step. The barrel and trees outside the area remain.", false)


func _move_cursor(studio: StudioMode, cell: Vector2i) -> void:
	var world := (Vector2(cell) + Vector2(0.5, 0.5)) * OverworldScale.TILE
	var view := studio.pixel_view()
	var catcher := studio.get("_catcher") as Control
	studio._set_cursor(catcher.get_global_transform().affine_inverse() * view.get_global_transform() * view.to_screen(world))
	studio.arrange.update()


func _park_mouse() -> void:
	Input.warp_mouse(Vector2(1900, 600))
	await _frames(3)
