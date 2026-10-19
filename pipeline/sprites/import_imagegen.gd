extends SceneTree
## Pack imagegen's polished Vesper sheets into the copied skin, using the original frame bounds for placement.
## Run from the repository root: godot --headless --path . --script pipeline/sprites/import_imagegen.gd

const ORIGINAL := "game/assets/sprites/vesper/"
const OUTPUT := "game/assets/sprites/vesper-v2/"
const SOURCE := "pipeline/sprites/skins/vesper-v2/imagegen/"
const FRAME := Vector2i(400, 350)
const REVIEW := "pipeline/cache/sprites/vesper-v2/review/"


func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ORIGINAL + "clips.json"))
	manifest.id = "vesper-v2"
	manifest.name = "VesperV2.0"
	var idle_anchor: Image
	for clip: String in ["idle-breathe", "cast-light", "hurt"]:
		var info: Dictionary = manifest.clips[clip]
		var original := Image.load_from_file(ORIGINAL + clip + ".webp")
		var generated := Image.load_from_file(SOURCE + clip + ".png")
		if original == null or generated == null or generated.is_empty():
			push_error("Missing sheet: " + clip)
			quit(1)
			return
		original.convert(Image.FORMAT_RGBA8)
		generated.convert(Image.FORMAT_RGBA8)
		var columns := int(info.columns)
		var rows := ceili(float(info.frames) / columns)
		var row_edges := _row_edges(generated, rows)
		var sheet := Image.create(columns * FRAME.x, rows * FRAME.y, false, Image.FORMAT_RGBA8)
		var review_dir := REVIEW + clip
		DirAccess.make_dir_recursive_absolute(review_dir)
		for index in int(info.frames):
			var column := index % columns
			var row := index / columns
			# Generated dimensions may differ; round each boundary separately so no pixels are lost.
			var start := Vector2i(roundi(float(column) * generated.get_width() / columns), row_edges[row])
			var end := Vector2i(roundi(float(column + 1) * generated.get_width() / columns), row_edges[row + 1])
			var drawing := generated.get_region(Rect2i(start, end - start))
			var reference := original.get_region(Rect2i(Vector2i(column, row) * FRAME, FRAME))
			var bounds := _opaque_bounds(drawing)
			var target := _opaque_bounds(reference)
			if bounds.size.x == 0 or target.size.x == 0:
				push_error("Empty frame: %s %d" % [clip, index])
				quit(1)
				return
			var sprite := drawing.get_region(bounds)
			var scale := float(target.size.y) / bounds.size.y
			sprite.resize(roundi(bounds.size.x * scale), target.size.y, Image.INTERPOLATE_LANCZOS)
			var frame := Image.create(FRAME.x, FRAME.y, false, Image.FORMAT_RGBA8)
			var position := Vector2i(
				roundi(target.get_center().x - sprite.get_width() * 0.5), mini(target.end.y, 349) - sprite.get_height()
			)
			frame.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), position)
			# All clips return to the identical polished idle pose. Also repairs the generated cast's cropped last cell.
			if clip != "idle-breathe" and (index == 0 or index == int(info.frames) - 1):
				frame = idle_anchor.duplicate()
			elif clip == "idle-breathe" and index == 0:
				idle_anchor = frame.duplicate()
			sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME), Vector2i(column, row) * FRAME)
			frame.save_png(review_dir + "/%03d.png" % index)
		var error := sheet.save_webp(OUTPUT + clip + ".webp", false, 1.0)
		if error != OK:
			push_error("Could not save: " + clip)
			quit(1)
			return
		print("%s: %d frames, %s -> %s" % [clip, info.frames, generated.get_size(), sheet.get_size()])
	var file := FileAccess.open(OUTPUT + "clips.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	# A profile icon from the updated sheet; the wardrobe keeps the copied full portrait.
	var profile := idle_anchor.get_region(Rect2i(30, 10, 230, 230))
	profile.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	profile.save_png(OUTPUT + "profile.png")
	quit()


static func _row_edges(drawing: Image, rows: int) -> Array[int]:
	# Imagegen approximates grid spacing. Find the transparent gap between rows before cutting their cells.
	var edges: Array[int] = [0]
	var pitch := float(drawing.get_height()) / rows
	for row in range(1, rows):
		var nominal := roundi(row * pitch)
		var reach := roundi(pitch * 0.24)
		var best_count := drawing.get_width()
		var best_distance := reach + 1
		var edge := nominal
		for y in range(maxi(0, nominal - reach), mini(drawing.get_height(), nominal + reach)):
			var count := 0
			for x in drawing.get_width():
				if drawing.get_pixel(x, y).a > 0.5:
					count += 1
			var distance := absi(y - nominal)
			if count < best_count or (count == best_count and distance < best_distance):
				best_count = count
				best_distance = distance
				edge = y
		edges.append(edge)
	edges.append(drawing.get_height())
	print("Detected row boundaries: ", edges)
	return edges


static func _opaque_bounds(drawing: Image) -> Rect2i:
	var low := drawing.get_size()
	var high := Vector2i.ZERO
	for y in drawing.get_height():
		for x in drawing.get_width():
			if drawing.get_pixel(x, y).a > 0.5:
				low.x = mini(low.x, x)
				low.y = mini(low.y, y)
				high.x = maxi(high.x, x + 1)
				high.y = maxi(high.y, y + 1)
	return Rect2i(low, high - low) if high.x > low.x else Rect2i()
