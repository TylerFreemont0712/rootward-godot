extends SceneTree
## Reproducible sprite registration: slice imagegen's complete figures, register their head center and feet,
## and pack them as single sheets. This does not synthesize poses or split anatomy into runtime layers.

const FACINGS: Array[String] = ["down", "up", "left", "right"]
const FRAME := Vector2i(64, 96)
const GROUND := 93

var _root := ""
var _report: Dictionary = {}


func _initialize() -> void:
	_root = ProjectSettings.globalize_path("res://..")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_root.path_join("pipeline/animation/player_sources.json")))
	for model: String in config.models:
		var sheet := Image.create_empty(FRAME.x * 12, FRAME.y * 4, false, Image.FORMAT_RGBA8)
		for row in FACINGS.size():
			var way := FACINGS[row]
			var entry: Dictionary = config.models[model][way]
			var source := Image.load_from_file(_root.path_join(String(entry.source)))
			var cells := _cells(source, 4, 3)
			var scale_factor := _scale_for(cells.slice(8, 12), float(config.player_height))
			var flip: Array[int] = []
			for value: Variant in entry.get("flip_frames", []):
				flip.append(int(value))
			for index in cells.size():
				if flip.has(index):
					cells[index].flip_x()
				var frame := _registered(cells[index], scale_factor)
				var column := index - 8 if index >= 8 else index + 4
				sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME), Vector2i(column * FRAME.x, row * FRAME.y))
			_report[model + "/" + way] = {"source": entry.source, "scale": scale_factor, "flip_frames": flip}
		_save(sheet, "res://assets/overworld/player/" + model + ".png")
	var officer: Dictionary = config.commander
	var officer_cells := _cells(Image.load_from_file(_root.path_join(String(officer.source))), 4, 2)
	var officer_sheet := Image.create_empty(FRAME.x * 2, FRAME.y * 4, false, Image.FORMAT_RGBA8)
	for row in FACINGS.size():
		var pair: Array[Image] = [officer_cells[row], officer_cells[row + 4]]
		var scale_factor := _scale_for(pair, float(officer.height))
		for column in 2:
			officer_sheet.blit_rect(_registered(pair[column], scale_factor), Rect2i(Vector2i.ZERO, FRAME), Vector2i(column * FRAME.x, row * FRAME.y))
	_save(officer_sheet, String(officer.output))
	var report := FileAccess.open(_root.path_join("Concept/v0.3/animation/player/registration.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(_report, "  ") + "\n")
	quit()


func _cells(source: Image, columns: int, rows: int) -> Array[Image]:
	source.convert(Image.FORMAT_RGBA8)
	var cells: Array[Image] = []
	for row in rows:
		for column in columns:
			var start := Vector2i(floori(float(column) * source.get_width() / columns), floori(float(row) * source.get_height() / rows))
			var end := Vector2i(floori(float(column + 1) * source.get_width() / columns), floori(float(row + 1) * source.get_height() / rows))
			var cell := source.get_region(Rect2i(start, end - start))
			# Source alpha has a faint colored matte at its edge; retain opaque art and binary alpha for pixel art.
			for y in cell.get_height():
				for x in cell.get_width():
					var pixel := cell.get_pixel(x, y)
					pixel.a = 1.0 if pixel.a >= 0.8 else 0.0
					cell.set_pixel(x, y, pixel if pixel.a > 0.0 else Color.TRANSPARENT)
			cells.append(cell)
	return cells


## One scale for a direction's entire clip preserves its authored bob and proportions. Fitting every pose to a
## separate bounding box would stretch the head and boots throughout the cycle.
func _scale_for(cells: Array[Image], height: float) -> float:
	var heights: Array[float] = []
	for cell in cells:
		heights.append(float(cell.get_used_rect().size.y))
	heights.sort()
	return height / maxf(1.0, heights[heights.size() / 2])


func _registered(source: Image, scale_factor: float) -> Image:
	var picture: Image = source.duplicate()
	picture.resize(roundi(picture.get_width() * scale_factor), roundi(picture.get_height() * scale_factor), Image.INTERPOLATE_NEAREST)
	var used: Rect2i = picture.get_used_rect()
	# The head is the stable horizontal anchor. The whole silhouette's center shifts as a boot or arm swings.
	var sum := 0.0
	var count := 0
	for y in range(used.position.y, used.position.y + roundi(used.size.y * 0.42)):
		for x in range(used.position.x, used.end.x):
			if picture.get_pixel(x, y).a > 0.0:
				sum += x
				count += 1
	var head_x := sum / maxf(1.0, count)
	var offset := Vector2i(roundi(FRAME.x / 2.0 - head_x), GROUND - used.end.y)
	var frame := Image.create_empty(FRAME.x, FRAME.y, false, Image.FORMAT_RGBA8)
	frame.blit_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), offset)
	return frame


func _save(sheet: Image, path: String) -> void:
	var error := sheet.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		quit(1)
	print("Packed %s (%s)" % [path, sheet.get_size()])
