extends SceneTree
## Conservative repairs of the copied original skin. Healthy frames and all playback metadata stay original.

const CUT := preload("import_imagegen.gd")
const ORIGINAL := "game/assets/sprites/vesper/"
const OUTPUT := "game/assets/sprites/vesper-v1-5/"
const SOURCE := "pipeline/sprites/skins/vesper-v1-5/repairs/"
const CACHE := "pipeline/cache/sprites/vesper-v1-5/"
const FRAME := Vector2i(400, 350)
const MULTIPLIER := 8
const KEYS := {"cast-light": [13, 16, 20, 26], "hurt": [1, 3, 8, 17, 19]}
const REPAIRS := {"cast-light": [[14, 25], [40, 46]], "hurt": [[2, 18]]}
const RETURN_POSES := {40: 12, 41: 10, 42: 8, 43: 6, 44: 4, 45: 2, 46: 47}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE)
	if "--finish" in OS.get_cmdline_user_args():
		_finish()
	else:
		_prepare()
	quit()


func _prepare() -> void:
	var config := {}
	for clip: String in KEYS:
		var sheet := Image.load_from_file(ORIGINAL + clip + ".webp")
		var frames: Array[Image] = []
		for index: int in KEYS[clip]:
			var frame := _frame(sheet, index)
			var prefix := "cast" if clip == "cast-light" else "hurt"
			var edited_path := SOURCE + "%s-%03d-edited.png" % [prefix, index]
			if FileAccess.file_exists(edited_path):
				var edited := Image.load_from_file(edited_path)
				frame = _align(edited, frame)
			frames.append(frame)
			frame.save_png(CACHE + "%s-key-%03d.png" % [clip, index])
		var rgba := _grid(frames)
		var white := Image.create(rgba.get_width(), rgba.get_height(), false, Image.FORMAT_RGBA8)
		white.fill(Color.WHITE)
		white.blend_rect(rgba, Rect2i(Vector2i.ZERO, rgba.get_size()), Vector2i.ZERO)
		white.convert(Image.FORMAT_RGB8)
		white.save_png(CACHE + clip + "-repair-keys.png")
		config[clip] = {"keys": frames.size(), "multiplier": MULTIPLIER}
	_write_json(CACHE + "config.json", config)
	print("Prepared only the damaged cast and hurt spans, using original neighboring frames as anchors.")


func _align(edited: Image, original: Image) -> Image:
	var bounds := CUT._opaque_bounds(edited)
	var target := CUT._opaque_bounds(original)
	assert(bounds.has_area() and target.has_area(), "Empty repair frame")
	var sprite := edited.get_region(bounds)
	var scale := float(target.size.y) / bounds.size.y
	sprite.resize(roundi(sprite.get_width() * scale), target.size.y, Image.INTERPOLATE_LANCZOS)
	var position := Vector2i(roundi(_boots(original) - _boots(sprite)), target.end.y - sprite.get_height())
	# Repair the clipped hat without introducing a new crop at the cell edge.
	position.x = clampi(position.x, 4, FRAME.x - sprite.get_width() - 4)
	var placed := Image.create(FRAME.x, FRAME.y, false, Image.FORMAT_RGBA8)
	placed.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), position)
	return placed


func _boots(image: Image) -> float:
	var bounds := CUT._opaque_bounds(image)
	var mass := 0.0
	var sum_x := 0.0
	for y in range(bounds.position.y + roundi(bounds.size.y * 0.8), bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.5:
				mass += alpha
				sum_x += x * alpha
	assert(mass > 0, "Repair frame has no boots")
	return sum_x / mass


func _finish() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ORIGINAL + "clips.json"))
	manifest.id = "vesper-v1-5"
	manifest.name = "Vesper 1.5"
	# Copy these bytes exactly; no repair was needed.
	for filename: String in ["idle-breathe.webp", "profile.png"]:
		assert(DirAccess.copy_absolute(ORIGINAL + filename, OUTPUT + filename) == OK)
	var changes := {}
	for clip: String in KEYS:
		var original := Image.load_from_file(ORIGINAL + clip + ".webp")
		var repaired := original.duplicate()
		var interpolation := Image.load_from_file(CACHE + clip + "-repair-finished.png")
		assert(interpolation != null and not interpolation.is_empty(), "Missing repair interpolation")
		var expected_count: int = (KEYS[clip].size() - 1) * MULTIPLIER + 1
		assert(interpolation.get_size() == Vector2i(FRAME.x * 8, ceili(float(expected_count) / 8) * FRAME.y))
		var changed: Array[int] = []
		for span: Array in REPAIRS[clip]:
			for index in range(span[0], span[1] + 1):
				var frame := (
					_frame(original, RETURN_POSES[index])
					if clip == "cast-light" and index in RETURN_POSES
					else _frame(interpolation, _interpolated_index(clip, index))
				)
				repaired.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME), Vector2i(index % 8, index / 8) * FRAME)
				changed.append(index)
		assert(repaired.save_webp(OUTPUT + clip + ".webp", false, 1.0) == OK)
		changes[clip] = changed
		DirAccess.make_dir_recursive_absolute(CACHE + "review/" + clip)
		for index in int(manifest.clips[clip].frames):
			_frame(repaired, index).save_png(CACHE + "review/%s/%03d.png" % [clip, index])
		print("%s: repaired %s; all other frame cells retained." % [clip, changed])
	_write_json(OUTPUT + "clips.json", manifest)
	_write_json(SOURCE + "changed-frames.json", changes)
	var original_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ORIGINAL + "clips.json"))
	var preview := FileAccess.open("pipeline/sprites/skins/vesper-v1-5/preview-manifests.js", FileAccess.WRITE)
	preview.store_string(
		(
			"window.vesperPreview = "
			+ JSON.stringify({"original": original_manifest, "updated": manifest, "changedFrames": changes})
			+ ";\n"
		)
	)


func _interpolated_index(clip: String, index: int) -> int:
	var keys: Array = KEYS[clip]
	for key in range(keys.size() - 1):
		if index <= keys[key + 1]:
			var fraction: float = float(index - keys[key]) / (keys[key + 1] - keys[key])
			return roundi((key + fraction) * MULTIPLIER)
	return (keys.size() - 1) * MULTIPLIER


func _frame(sheet: Image, index: int) -> Image:
	return sheet.get_region(Rect2i(Vector2i(index % 8, index / 8) * FRAME, FRAME))


func _grid(frames: Array[Image]) -> Image:
	var sheet := Image.create(FRAME.x * 8, FRAME.y * ceili(float(frames.size()) / 8), false, Image.FORMAT_RGBA8)
	for index in frames.size():
		sheet.blit_rect(frames[index], Rect2i(Vector2i.ZERO, FRAME), Vector2i(index % 8, index / 8) * FRAME)
	return sheet


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not write " + path)
	file.store_string(JSON.stringify(data, "  ") + "\n")
