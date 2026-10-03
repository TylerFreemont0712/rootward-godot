class_name ScriptLoom
extends RefCounted
## A seal stitched around its circumference, one sector per function. Every visible mark belongs to a stroke;
## there is no prebuilt disc, rim, star or stack behind it. The writing tip follows actual arc length.


static func strokes(spec: Dictionary, slot: int, count: int, radius: float) -> Array[PackedVector2Array]:
	var span := TAU / maxi(1, count)
	var start := -PI * 0.5 + slot * span
	var end := start + span
	var middle := start + span * 0.5
	var paths: Array[PackedVector2Array] = []
	var border := _arc(radius, start, span)
	border.append(Vector2.from_angle(end) * radius * 0.86)
	border.append_array(_arc(radius * 0.86, end, -span))
	paths.append(border)
	# Two curved threads fold inward, meeting a small angular stitch rather than a ruled star.
	var petal := _curve(
		Vector2.from_angle(start) * radius * 0.86,
		Vector2.from_angle(start + span * 0.18) * radius * 0.48,
		Vector2.from_angle(middle - span * 0.16) * radius * 0.56,
		Vector2.from_angle(middle) * radius * 0.24
	)
	petal.append_array(
		_curve(
			Vector2.from_angle(middle) * radius * 0.24,
			Vector2.from_angle(middle + span * 0.16) * radius * 0.56,
			Vector2.from_angle(end - span * 0.18) * radius * 0.48,
			Vector2.from_angle(end) * radius * 0.86
		)
	)
	paths.append(petal)
	var seam := _arc(radius * 0.69, start + span * 0.12, span * 0.76)
	var axis := Vector2.from_angle(middle)
	var side := axis.orthogonal()
	var centre := axis * radius * 0.52
	var size := radius * minf(0.065, span * 0.06)
	var zig := -1.0 if int(spec.get("seed", 0)) % 2 else 1.0
	(
		seam
		. append_array(
			PackedVector2Array(
				[
					centre + side * size * 2.0,
					centre + axis * size + side * size,
					centre - axis * size,
					centre + axis * size * zig - side * size,
					centre - side * size * 2.0,
				]
			)
		)
	)
	paths.append(seam)
	# The final function writes the central clasp, too: releasing the cast adds no unexplained geometry.
	if slot == count - 1:
		var clasp := PackedVector2Array()
		for index in 7:
			clasp.append(Vector2.from_angle(-PI * 0.5 + index * TAU / 6.0) * radius * 0.12)
		clasp.append(Vector2.ZERO)
		paths.append(clasp)
	return paths


## LEARN: clipping by distance keeps the writing speed steady on both short stitches and long curves.
static func prefix(paths: Array[PackedVector2Array], progress: float) -> Array[PackedVector2Array]:
	var total := 0.0
	for path in paths:
		for index in range(1, path.size()):
			total += path[index - 1].distance_to(path[index])
	var remaining := total * clampf(progress, 0.0, 1.0)
	var written: Array[PackedVector2Array] = []
	for path in paths:
		if remaining <= 0.0001 or path.size() < 2:
			break
		var part := PackedVector2Array([path[0]])
		for index in range(1, path.size()):
			var length := path[index - 1].distance_to(path[index])
			if length <= 0.0001:
				continue
			part.append(path[index - 1].lerp(path[index], minf(1.0, remaining / length)))
			remaining -= length
			if remaining <= 0.0001:
				break
		if part.size() > 1:
			written.append(part)
	return written


static func draw(c: MagicCircle, radius: float, fade: float) -> void:
	var width := clampf(radius / 100.0, 0.9, 2.4)
	var pulse := 1.0 + c._flare * 0.25
	for slot in c.layers.size():
		var progress := c._layer_progress(slot)
		if progress <= 0.0:
			continue
		var written := prefix(strokes(c.layers[slot], slot, c.layers.size(), radius), progress)
		for path in written:
			c.draw_polyline(path, Color(c.mid, 0.22 * fade), width * 5.0 * pulse, true)
			c.draw_polyline(path, Color(c.mid, 0.85 * fade), width * 2.1 * pulse, true)
			c.draw_polyline(path, Color(c.hot, fade), width * 0.8, true)
		if progress < 1.0 and not c._reduced and not written.is_empty():
			var tip: Vector2 = written.back()[written.back().size() - 1]
			var ink := c.hot.lerp(Color("#ffe5a3"), 0.65)
			c.draw_circle(tip, width * 7.0, Color(ink, 0.2 * fade))
			c.draw_circle(tip, width * 2.8, Color(ink, fade))


static func _arc(radius: float, from: float, sweep: float) -> PackedVector2Array:
	var path := PackedVector2Array()
	var count := maxi(2, ceili(absf(sweep) * 20.0))
	for index in count + 1:
		path.append(Vector2.from_angle(from + sweep * index / count) * radius)
	return path


static func _curve(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array()
	for index in 33:
		var u := index / 32.0
		var v := 1.0 - u
		path.append(a * v * v * v + b * 3.0 * v * v * u + c * 3.0 * v * u * u + d * u * u * u)
	return path
