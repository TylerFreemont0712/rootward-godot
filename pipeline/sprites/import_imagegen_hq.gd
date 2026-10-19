extends SceneTree
## Prepare consistent imagegen keyframes, then pack the RIFE animation output. See skins/vesper-v2/README.md.

const CUT := preload("import_imagegen.gd")
const SOURCE := "pipeline/sprites/skins/vesper-v2/imagegen/touch-up/"
const CACHE := "pipeline/cache/sprites/vesper-v2/touch-up/"
const OUTPUT := "game/assets/sprites/vesper-v2/"
const FRAME := Vector2i(640, 560)
const BASELINE := 538
const BOOT_CENTER := 243
const HEIGHT := 478
const HEAD_WIDTH := 208
const HEAD_HEIGHT := 180
const MULTIPLIERS := {"idle-breathe": 8, "cast-light": 4, "hurt": 4}
const IDLE_TIMES: Array[int] = [0, 8, 16, 24, 32, 40, 48, 56, 64]
const HANDS := {
	"idle-breathe":
	[[345, 325], [345, 325], [345, 324], [345, 324], [345, 324], [345, 325], [345, 325], [345, 325], [345, 325]],
	"cast-light":
	[
		[345, 325],
		[294, 251],
		[314, 208],
		[312, 161],
		[397, 208],
		[415, 181],
		[415, 181],
		[415, 181],
		[415, 181],
		[415, 181],
		[397, 208],
		[312, 161],
		[314, 208],
		[294, 251],
		[345, 325]
	],
	"hurt": [[180, 325], [180, 325], [296, 219], [296, 211], [296, 219], [309, 291], [180, 325], [180, 325]],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE)
	if "--inspect" in OS.get_cmdline_user_args():
		_inspect()
	elif "--finish" in OS.get_cmdline_user_args():
		_pack()
	else:
		_prepare()
	quit()


func _inspect() -> void:
	for clip: String in ["idle-breathe", "cast-start", "cast-anticipation", "hurt"]:
		if not FileAccess.file_exists(SOURCE + clip + ".png"):
			continue
		var frames: Array[Image] = []
		var heights: Array[int] = []
		for drawing in _cut(clip):
			var placed := _place(drawing)
			frames.append(placed)
			heights.append(CUT._opaque_bounds(placed).size.y)
		_grid(frames).save_png(CACHE + clip + "-review.png")
		print(clip + " aligned figure heights with constant hat width: ", heights)
		if clip == "cast-start":
			frames[5].save_png(SOURCE + "cast-release-reference.png")
			frames[3].save_png(SOURCE + "cast-anticipation-reference.png")


func _prepare() -> void:
	var cast_start := _cut("cast-start")
	var anticipation := _cut("cast-anticipation")
	var hurt := _cut("hurt")
	var anchor := Image.load_from_file(SOURCE + "neutral.png")
	assert(anchor.get_size() == FRAME)
	anchor.convert(Image.FORMAT_RGBA8)
	anchor.save_png(CACHE + "anchor.png")
	var sequences := {"idle-breathe": [], "cast-light": [], "hurt": hurt}
	# Keep just the first quarter of the initial inhale: a few pixels of motion, with no hip or head sway.
	var idle_names := ["idle-rest", "idle-inhale-1", "idle-inhale-2"]
	for frame_index: int in [0, 1, 2, 2, 2, 1, 0, 0, 0]:
		sequences["idle-breathe"].append(Image.load_from_file(SOURCE + idle_names[frame_index] + ".png"))
	# Redrawn belt/chest keys keep the same arm. Recovery retraces the complete path and retains its palette.
	sequences["cast-light"] = [
		anchor,
		anticipation[0],
		anticipation[1],
		cast_start[3],
		cast_start[4],
		cast_start[5],
		cast_start[6],
		cast_start[7],
		cast_start[6],
		cast_start[5],
		cast_start[4],
		cast_start[3],
		anticipation[1],
		anticipation[0],
		anchor
	]
	var config := {}
	for clip: String in sequences:
		var sequence: Array = sequences[clip]
		var frames: Array[Image] = []
		for index in sequence.size():
			var frame: Image = sequence[index].duplicate() if clip == "idle-breathe" else _place(sequence[index])
			if index == 0 or index == sequence.size() - 1:
				frame = anchor.duplicate()
			frames.append(frame)
			frame.save_png(CACHE + "%s-key-%02d.png" % [clip, index])
		# RIFE takes RGB. Composite the generated alpha onto white before interpolation and restore alpha afterward.
		var sheet := _grid(frames)
		var white := Image.create(sheet.get_width(), sheet.get_height(), false, Image.FORMAT_RGBA8)
		white.fill(Color.WHITE)
		white.blend_rect(sheet, Rect2i(Vector2i.ZERO, sheet.get_size()), Vector2i.ZERO)
		white.convert(Image.FORMAT_RGB8)
		white.save_png(CACHE + clip + "-keys.png")
		config[clip] = {"keys": frames.size(), "multiplier": MULTIPLIERS[clip], "width": FRAME.x, "height": FRAME.y}
		print("%s: %d selected keys, foot anchor %d,%d" % [clip, frames.size(), BOOT_CENTER, BASELINE])
	_write_json(CACHE + "config.json", config)


func _cut(name: String) -> Array[Image]:
	var path := SOURCE + name + "-matte.png"
	if not FileAccess.file_exists(path):
		path = SOURCE + name + ".png"
	var sheet := Image.load_from_file(path)
	assert(sheet != null and not sheet.is_empty(), "Missing imagegen sheet: " + name)
	sheet.convert(Image.FORMAT_RGBA8)
	var columns := 2 if name == "cast-anticipation" else 4
	var count := 2 if name == "cast-anticipation" else 8
	var edges := CUT._row_edges(sheet, 1 if count == 2 else 2)
	var frames: Array[Image] = []
	for index in count:
		var column := index % columns
		var row := index / columns
		var left := roundi(float(column) * sheet.get_width() / columns)
		var right := roundi(float(column + 1) * sheet.get_width() / columns)
		frames.append(sheet.get_region(Rect2i(left, edges[row], right - left, edges[row + 1] - edges[row])))
	return frames


func _place(drawing: Image) -> Image:
	var bounds := CUT._opaque_bounds(drawing)
	assert(bounds.size.x > 0, "Empty keyframe")
	var sprite := drawing.get_region(bounds)
	# Register scale by the hat/head, so a recoil cannot enlarge the head as the body compresses.
	var head_bounds := _head_bounds(sprite)
	var scale := float(HEAD_WIDTH) / head_bounds.size.x
	var height := roundi(sprite.get_height() * scale)
	sprite.resize(roundi(sprite.get_width() * scale), height, Image.INTERPOLATE_LANCZOS)
	# Preserve the head pixels and correct torso/leg length separately. A compressed torso must not inflate the head.
	var body := sprite.get_region(Rect2i(0, HEAD_HEIGHT, sprite.get_width(), height - HEAD_HEIGHT))
	body.resize(sprite.get_width(), HEIGHT - HEAD_HEIGHT, Image.INTERPOLATE_LANCZOS)
	var normalized := Image.create(sprite.get_width(), HEIGHT, false, Image.FORMAT_RGBA8)
	normalized.blit_rect(sprite, Rect2i(0, 0, sprite.get_width(), HEAD_HEIGHT), Vector2i.ZERO)
	normalized.blit_rect(body, Rect2i(Vector2i.ZERO, body.get_size()), Vector2i(0, HEAD_HEIGHT))
	sprite = normalized
	height = HEIGHT
	# The lower fifth contains only the boots. Their mass anchors placement independently of arms, cape and hat.
	var sum_x := 0.0
	var mass := 0.0
	for y in range(roundi(height * 0.8), height):
		for x in sprite.get_width():
			var alpha := sprite.get_pixel(x, y).a
			if alpha > 0.5:
				sum_x += x * alpha
				mass += alpha
	assert(mass > 0, "Keyframe has no boots")
	var placed := Image.create(FRAME.x, FRAME.y, false, Image.FORMAT_RGBA8)
	placed.blit_rect(
		sprite,
		Rect2i(Vector2i.ZERO, sprite.get_size()),
		Vector2i(roundi(BOOT_CENTER - sum_x / mass), BASELINE - height)
	)
	return placed


func _head_bounds(sprite: Image) -> Rect2i:
	# In the upper portion, a raised casting hand is separate from the much larger hat/head component.
	var width := sprite.get_width()
	var height := roundi(sprite.get_height() * 0.28)
	var visited := PackedByteArray()
	visited.resize(width * height)
	var largest := 0
	var result := Rect2i()
	for y in height:
		for x in width:
			var start := y * width + x
			if visited[start] or sprite.get_pixel(x, y).a <= 0.5:
				continue
			var queue: Array[Vector2i] = [Vector2i(x, y)]
			visited[start] = 1
			var cursor := 0
			var low := Vector2i(x, y)
			var high := low
			while cursor < queue.size():
				var point := queue[cursor]
				cursor += 1
				low = low.min(point)
				high = high.max(point)
				for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next := point + direction
					if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height:
						continue
					var slot := next.y * width + next.x
					if not visited[slot] and sprite.get_pixelv(next).a > 0.5:
						visited[slot] = 1
						queue.append(next)
			if queue.size() > largest:
				largest = queue.size()
				result = Rect2i(low, high - low + Vector2i.ONE)
	return result


func _pack() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CACHE + "config.json"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("game/assets/sprites/vesper/clips.json"))
	manifest.id = "vesper-v2"
	manifest.name = "VesperV2.0"
	manifest.frame = {"width": FRAME.x, "height": FRAME.y}
	manifest.baseline = float(BASELINE) / FRAME.y
	manifest.center = float(BOOT_CENTER) / FRAME.x
	manifest.figure = float(HEIGHT) / FRAME.y
	manifest.clips = {}
	var anchor: Image
	for clip: String in ["idle-breathe", "cast-light", "hurt"]:
		var multiplier := int(config[clip].multiplier)
		var total := (int(config[clip].keys) - 1) * multiplier + 1
		var sheet := Image.load_from_file(CACHE + clip + "-finished.png")
		assert(sheet != null and not sheet.is_empty(), "Missing interpolated clip: " + clip)
		sheet.convert(Image.FORMAT_RGBA8)
		assert(
			sheet.get_width() == FRAME.x * 8 and sheet.get_height() == FRAME.y * ceili(float(total) / 8),
			"Wrong interpolation dimensions"
		)
		var count := total - 1 if clip == "idle-breathe" else total
		var frames: Array[Image] = []
		var review := CACHE + "review/" + clip
		DirAccess.make_dir_recursive_absolute(review)
		for index in count:
			var source_index := _idle_frame_at(index) if clip == "idle-breathe" else index
			var frame := sheet.get_region(
				Rect2i((source_index % 8) * FRAME.x, (source_index / 8) * FRAME.y, FRAME.x, FRAME.y)
			)
			if clip == "idle-breathe" and index == 0:
				anchor = frame.duplicate()
			elif clip != "idle-breathe" and (index == 0 or index == count - 1):
				frame = anchor.duplicate()
			frames.append(frame)
			frame.save_png(review + "/%03d.png" % index)
		var saved := _grid(frames).save_webp(OUTPUT + clip + ".webp", false, 1.0)
		assert(saved == OK, "Could not save " + clip)
		var info := {
			"frames": count,
			"columns": 8,
			"fps": 24.0,
			"loop": clip == "idle-breathe",
			"hand": _hands(clip, count, multiplier)
		}
		if clip != "idle-breathe":
			info.after = "idle-breathe"
		if clip == "cast-light":
			info.fps = 64.0
			info.releaseFrame = 5 * multiplier
			info.phases = {
				"anticipate": [0, info.releaseFrame - 1],
				"release": [info.releaseFrame, 8 * multiplier - 1],
				"recover": [8 * multiplier, count - 1]
			}
		manifest.clips[clip] = info
		print("Packed %s: %d frames @ %s fps, %s" % [clip, count, info.fps, FRAME])
	_write_json(OUTPUT + "clips.json", manifest)
	var preview := FileAccess.open("pipeline/sprites/skins/vesper-v2/preview-manifests.js", FileAccess.WRITE)
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("game/assets/sprites/vesper/clips.json"))
	var previous_path := "pipeline/cache/sprites/vesper-v2/before-touch-up/clips.json"
	var previous: Dictionary = (
		JSON.parse_string(FileAccess.get_file_as_string(previous_path)) if FileAccess.file_exists(previous_path) else {}
	)
	preview.store_string(
		(
			"window.vesperPreview = "
			+ JSON.stringify({"original": original, "updated": manifest, "previous": previous})
			+ ";\n"
		)
	)
	var profile := anchor.get_region(Rect2i(100, 50, 330, 330))
	profile.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	profile.save_png(OUTPUT + "profile.png")


func _idle_frame_at(index: int) -> int:
	for key in range(IDLE_TIMES.size() - 1):
		if index < IDLE_TIMES[key + 1]:
			var fraction := float(index - IDLE_TIMES[key]) / (IDLE_TIMES[key + 1] - IDLE_TIMES[key])
			return roundi((key + fraction) * 8)
	return 64


func _hands(clip: String, count: int, multiplier: int) -> Array:
	var keys: Array = HANDS[clip]
	var track: Array = []
	for index in count:
		var source_index := _idle_frame_at(index) if clip == "idle-breathe" else index
		var low := mini(source_index / multiplier, keys.size() - 1)
		var high := mini(low + 1, keys.size() - 1)
		var point := Vector2(keys[low][0], keys[low][1]).lerp(
			Vector2(keys[high][0], keys[high][1]), float(source_index % multiplier) / multiplier
		)
		track.append([snappedf(point.x / FRAME.x - 0.5, 0.0001), snappedf(1.0 - point.y / FRAME.y, 0.0001)])
	return track


func _grid(frames: Array[Image]) -> Image:
	var sheet := Image.create(8 * FRAME.x, ceili(float(frames.size()) / 8) * FRAME.y, false, Image.FORMAT_RGBA8)
	for index in frames.size():
		sheet.blit_rect(frames[index], Rect2i(Vector2i.ZERO, FRAME), Vector2i(index % 8, index / 8) * FRAME)
	return sheet


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not write " + path)
	file.store_string(JSON.stringify(value, "  ") + "\n")
