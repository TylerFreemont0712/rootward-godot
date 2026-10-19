extends SceneTree
## Register the imagegen atlas on the town's shared rail and ground anchors before the world palette cut.

const SOURCE := "Concept/v0.3/Update/town-polish/sources/boundaries.png"
const OUT := "Concept/v0.3/Update/town-polish/registered"
const CONNECTIONS := {
	0: "fencepost", 1: "fence-end-n", 2: "fence-end-e", 3: "fence-corner-ne",
	4: "fence-end-s", 5: "fence_v", 6: "fence-corner-se", 7: "fence-tee-e",
	8: "fence-end-w", 9: "fence-corner-nw", 10: "fence", 11: "fence-tee-n",
	12: "fence-corner-sw", 13: "fence-tee-w", 14: "fence-tee-s", 15: "fence-cross",
}
## The authored atlas has slight grid drift. These reviewed source regions keep neighboring caps out of each cut.
const REGIONS: Array[Rect2] = [
	Rect2(0, 0, 0.365, 0.334), Rect2(0.4, 0, 0.2, 0.334), Rect2(0.75, 0, 0.17, 0.334),
	Rect2(0, 0.34, 0.365, 0.28), Rect2(0.365, 0.34, 0.3, 0.28),
	Rect2(0.74, 0.34, 0.16, 0.29), Rect2(0.13, 0.64, 0.18, 0.34),
]

var _root := ""
var _tile := OverworldScale.TILE


func _initialize() -> void:
	_root = ProjectSettings.globalize_path("res://..")
	DirAccess.make_dir_recursive_absolute(_root.path_join(OUT))
	var source := Image.load_from_file(_root.path_join(SOURCE))
	source.convert(Image.FORMAT_RGBA8)
	var definitions := [
		["fence", 0, Rect2(0, 1.0, 1.0, 1.0)],
		["fence_v", 1, Rect2(0.375, 0.5, 0.25, 2.0)],
		["fencepost", 2, Rect2(0.375, 1.0, 0.25, 1.0)],
		["gate-closed", 3, Rect2(0, 0.7, 1.0, 1.3)],
		["gate-open", 4, Rect2(0, 0.7, 1.0, 1.3)],
		["gate_v-closed", 5, Rect2(0.325, 0.1, 0.55, 2.4)],
		["gate_v-open", 6, Rect2(0.3, 0.1, 0.7, 2.4)],
	]
	var made: Dictionary = {}
	for definition: Array in definitions:
		var cell := _cell(source, int(definition[1]))
		var bounds := cell.get_used_rect()
		var cut := cell.get_region(bounds)
		var box: Rect2 = definition[2]
		var rectangle := Rect2i(box.position * _tile, box.size * _tile)
		cut.resize(rectangle.size.x, rectangle.size.y, Image.INTERPOLATE_NEAREST)
		var frame := _blank()
		frame.blit_rect(cut, Rect2i(Vector2i.ZERO, cut.get_size()), rectangle.position)
		_save(frame, String(definition[0]))
		made[String(definition[0])] = frame
	var depth := Image.load_from_file(_root.path_join("Concept/v0.3/Update/town-polish/sources/vertical.png"))
	depth.convert(Image.FORMAT_RGBA8)
	var used := depth.get_used_rect()
	var face := depth.get_region(Rect2i(used.position + Vector2i(used.size.x * 0.55, used.size.y * 0.2), Vector2i(used.size.x * 0.15, used.size.y * 0.2)))
	for mask: int in CONNECTIONS:
		_save(_junction(made.fence, made.fencepost, face, mask), String(CONNECTIONS[mask]))
	for width: int in [2, 3]:
		for state: String in ["closed", "open"]:
			_save(_wide_horizontal(made["gate-" + state], width, state == "open"), "gate-wide-%d-%s" % [width, state])
	for state: String in ["closed", "open"]:
		_save(_wide_vertical(made["gate_v-" + state]), "gate-wide-2-v-" + state)
	print("Registered fences, four connected corners, and both gate states.")
	quit()


func _cell(source: Image, index: int) -> Image:
	var region := REGIONS[index]
	var extent := Vector2(source.get_size())
	var cell := source.get_region(Rect2i(region.position * extent, region.size * extent))
	for y in cell.get_height():
		for x in cell.get_width():
			var color := cell.get_pixel(x, y)
			color.a = 1.0 if color.a >= 0.8 else 0.0
			cell.set_pixel(x, y, color if color.a > 0.0 else Color.TRANSPARENT)
	return cell


func _blank() -> Image:
	return Image.create_empty(_tile, roundi(_tile * 2.5), false, Image.FORMAT_RGBA8)


func _junction(fence: Image, post: Image, depth: Image, mask: int) -> Image:
	var frame := _blank()
	var half := _tile / 2
	# LEARN: every orientation uses the same post and timber faces. Port geometry, rather than a separate fit for
	# each pose, fixes rail weights and cell-center joins across ends, corners, tees and crossings.
	for rail in 2:
		var y := roundi(_tile * (1.225 if rail == 0 else 1.625))
		var horizontal := fence.get_region(Rect2i(_tile / 4, y, half, _tile / 5))
		if mask & 2:
			frame.blend_rect(horizontal, Rect2i(Vector2i.ZERO, horizontal.get_size()), Vector2i(half, y))
		if mask & 8:
			frame.blend_rect(horizontal, Rect2i(Vector2i.ZERO, horizontal.get_size()), Vector2i(0, y))
		for bit: int in [1, 4]:
			if not mask & bit:
				continue
			var timber: Image = depth.duplicate()
			timber.resize(roundi(_tile * 0.125), half + _tile / 5, Image.INTERPOLATE_NEAREST)
			var x := roundi(_tile * (0.275 if rail == 0 else 0.575))
			frame.blend_rect(timber, Rect2i(Vector2i.ZERO, timber.get_size()), Vector2i(x, y - (half if bit == 1 else 0)))
	frame.blend_rect(post, Rect2i(Vector2i.ZERO, post.get_size()), Vector2i.ZERO)
	return frame


func _save(frame: Image, name: String) -> void:
	var path := _root.path_join(OUT).path_join(name + ".png")
	var error := frame.save_png(path)
	if error != OK:
		push_error("Could not write %s: %s" % [path, error_string(error)])
		quit(1)


func _wide_horizontal(source: Image, tiles: int, open: bool) -> Image:
	var width := _tile * tiles
	var frame := Image.create_empty(width, source.get_height(), false, Image.FORMAT_RGBA8)
	if open:
		# Preserve the hinges, swung panel and both end posts; the extra width is a clear passage.
		frame.blit_rect(source, Rect2i(0, 0, _tile / 2, source.get_height()), Vector2i.ZERO)
		frame.blit_rect(source, Rect2i(_tile * 3 / 4, 0, _tile / 4, source.get_height()), Vector2i(width - _tile / 4, 0))
	else:
		var cap := _tile / 5
		frame.blit_rect(source, Rect2i(0, 0, cap, source.get_height()), Vector2i.ZERO)
		frame.blit_rect(source, Rect2i(_tile - cap, 0, cap, source.get_height()), Vector2i(width - cap, 0))
		var panel := source.get_region(Rect2i(cap, 0, _tile - cap * 2, source.get_height()))
		panel.resize(width - cap * 2, source.get_height(), Image.INTERPOLATE_NEAREST)
		frame.blit_rect(panel, Rect2i(Vector2i.ZERO, panel.get_size()), Vector2i(cap, 0))
	return frame


func _wide_vertical(source: Image) -> Image:
	var frame := Image.create_empty(_tile, source.get_height() + _tile, false, Image.FORMAT_RGBA8)
	frame.blit_rect(source, Rect2i(0, 0, _tile, _tile), Vector2i.ZERO)
	frame.blit_rect(source, Rect2i(0, source.get_height() - _tile, _tile, _tile), Vector2i(0, frame.get_height() - _tile))
	var panel := source.get_region(Rect2i(0, _tile, _tile, source.get_height() - _tile * 2))
	panel.resize(_tile, frame.get_height() - _tile * 2, Image.INTERPOLATE_NEAREST)
	frame.blit_rect(panel, Rect2i(Vector2i.ZERO, panel.get_size()), Vector2i(0, _tile))
	return frame
