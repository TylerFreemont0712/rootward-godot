class_name CardWear
extends Control
## Small, purely visual edge wear.

const CHIP := Color("#101a1d")

var quality := 1.0
var _marks: Array[Dictionary] = []


static func create(accent: Color) -> CardWear:
	var wear := CardWear.new()
	wear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var seed_source := RandomNumberGenerator.new()
	seed_source.randomize()
	wear._arrange_marks(seed_source.randi(), accent)
	return wear


func _arrange_marks(instance_seed: int, accent: Color) -> void:
	# LEARN: Assign the visible card its own seed once. Its finish stays fixed while drawn or hovered, but repeated copies
	# of the same shard can have different wear without consuming the run's random stream.
	var random := RandomNumberGenerator.new()
	random.seed = instance_seed
	var roll := random.randf()
	var count := 0
	if roll >= 0.12:
		count = 1
		quality = random.randf_range(0.9, 0.985)
	if roll >= 0.72:
		count = 2
		quality = random.randf_range(0.82, 0.93)
	if roll >= 0.96:
		count = 3
		quality = random.randf_range(0.74, 0.87)
	for index in count:
		var side := random.randi_range(0, 3)
		# A nick on the top edge survives the layered hand, where the side and bottom edges are often covered.
		if random.randf() < 0.5:
			side = 2
		var along := random.randf_range(0.12, 0.88)
		var wear_factor := 1.0 - quality
		var span := random.randf_range(10.0, 17.0) * (0.92 + wear_factor * 1.4)
		var depth := random.randf_range(5.0, 7.0) * (0.92 + wear_factor * 1.25)
		var point_count := random.randi_range(4, 7)
		var tip := random.randi_range(0, point_count - 1)
		var offsets := PackedVector2Array()
		for point in point_count:
			var progress := (float(point) + 1.0) / (point_count + 1.0)
			progress += random.randf_range(-0.38, 0.38) / float(point_count + 1)
			var point_depth := random.randf_range(0.24, 0.68)
			if point == tip:
				point_depth = random.randf_range(0.76, 1.18)
			offsets.append(Vector2((progress - 0.5) * span, point_depth * depth))
		(
			_marks
			. append(
				{
					"side": side,
					"along": along,
					"span": span,
					"offsets": offsets,
					"bevel": random.randi_range(1, point_count - 1),
					"accent": Color(accent.lightened(0.68), random.randf_range(0.5, 0.7)),
					"chip_alpha": random.randf_range(0.9, 0.98),
					"line_width": random.randf_range(1.2, 1.65),
				}
			)
		)
	queue_redraw()


func _draw() -> void:
	for mark: Dictionary in _marks:
		var shape := _shape(mark)
		draw_colored_polygon(shape, Color(CHIP, float(mark.chip_alpha)))
		var bevel_index := int(mark.bevel)
		var bevel := PackedVector2Array([shape[bevel_index], shape[bevel_index + 1]])
		draw_polyline(bevel, mark.accent, float(mark.line_width), true)


func _shape(mark: Dictionary) -> PackedVector2Array:
	var side := int(mark.side)
	var along := float(mark.along)
	var span := float(mark.span)
	var edge := Vector2.ZERO
	var tangent := Vector2.ZERO
	var inward := Vector2.ZERO
	match side:
		0:
			edge = Vector2(0, size.y * along)
			tangent = Vector2.DOWN
			inward = Vector2.RIGHT
		1:
			edge = Vector2(size.x, size.y * along)
			tangent = Vector2.DOWN
			inward = Vector2.LEFT
		2:
			edge = Vector2(size.x * along, 0)
			tangent = Vector2.RIGHT
			inward = Vector2.DOWN
		_:
			edge = Vector2(size.x * along, size.y)
			tangent = Vector2.RIGHT
			inward = Vector2.UP
	var offsets: PackedVector2Array = mark.offsets
	var points := PackedVector2Array([edge - tangent * span * 0.5])
	for offset: Vector2 in offsets:
		points.append(edge + tangent * offset.x + inward * offset.y)
	points.append(edge + tangent * span * 0.5)
	return points
