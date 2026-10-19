extends SceneTree
## Native vector geometry, baked into registered pixel sheets by the normal world cut. No GPU or external art service.
## godot --headless --path game -s res://tools/build_gate_art.gd

const OUT := "Concept/v0.3/Update/gate-swing"
const FRAMES := 13
const TILE := 40.0
const DEPTH := 0.65
const KITS := {
	"gate": [1, 1, "horizontal", "wood"],
	"gate_v": [1, 1, "vertical", "wood"],
	"gate-wide-2": [2, 1, "horizontal", "wood"],
	"gate-wide-3": [3, 1, "horizontal", "wood"],
	"gate-wide-2-v": [1, 2, "vertical", "wood"],
	"expand-arched_wood_gate": [1, 1, "horizontal", "wood"],
	"expand-arched_wood_gate_v": [1, 1, "vertical", "wood"],
	"expand-iron_garden_gate": [1, 1, "horizontal", "steel"],
	"expand-iron_garden_gate_v": [1, 1, "vertical", "steel"],
}

var _faces: Array[Dictionary] = []
var _offset := Vector2.ZERO
var _wood: Array[Color] = []
var _steel: Array[Color] = []
var _gold: Array[Color] = []


func _initialize() -> void:
	var root_path := ProjectSettings.globalize_path("res://..")
	var folder := root_path.path_join(OUT)
	DirAccess.make_dir_recursive_absolute(folder)
	_wood = OverworldArt.ramp("wood")
	_steel = OverworldArt.ramp("steel")
	_gold = OverworldArt.ramp("gold")
	for id: String in KITS:
		var kit: Array = KITS[id]
		var footprint := Vector2i(int(kit[0]), int(kit[1]))
		var size := Vector2i((footprint.x + 2) * TILE, (footprint.y + 1.5) * TILE)
		_offset = Vector2(TILE, 1.5 * TILE)
		var images: Array[String] = []
		for frame: int in FRAMES:
			_faces.clear()
			_gate(footprint, String(kit[2]), String(kit[3]), float(frame) / (FRAMES - 1), "arched" in id)
			_faces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.depth) < float(b.depth))
			var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">' % [size.x, size.y]
			for face: Dictionary in _faces:
				svg += String(face.svg)
			svg += "</svg>"
			var image := Image.new()
			var error := image.load_svg_from_string(svg)
			if error != OK:
				push_error("Gate vector render failed: " + error_string(error))
				quit(1)
				return
			var path := OUT.path_join("%s-%02d.png" % [id, frame])
			if image.save_png(root_path.path_join(path)) != OK:
				quit(1)
				return
			images.append(path)
			if frame in [0, FRAMES - 1]:
				(
					FileAccess
					. open(folder.path_join("%s-%s.svg" % [id, "closed" if frame == 0 else "open"]), FileAccess.WRITE)
					. store_string(svg)
				)
		var spec_path := root_path.path_join("pipeline/world/objects/%s.jsonc" % id)
		var spec: Dictionary = Jsonc.parse(FileAccess.get_file_as_string(spec_path)).value
		spec.footprint = [footprint.x, footprint.y]
		spec.pad = 1
		spec.above = 1.5
		spec.source = {"registered": true, "images": images}
		spec.swing = {"axis": kit[2], "material": kit[3]}
		# Registered native frames replace the earlier blockout or independently fitted gate poses.
		spec.erase("parts")
		spec.erase("restyle")
		FileAccess.open(spec_path, FileAccess.WRITE).store_string(JSON.stringify(spec, "  ") + "\n")
		print("Built %s: %d registered hinge frames" % [id, FRAMES])
	quit()


func _gate(size: Vector2i, axis: String, material: String, amount: float, arched: bool) -> void:
	var vertical := axis == "vertical"
	var ramp := _steel if material == "steel" else _wood
	var first := Vector2(size.x * TILE / 2.0, 4.0 / DEPTH) if vertical else Vector2(4, (size.y - 0.5) * TILE / DEPTH)
	var last := Vector2(first.x, (size.y * TILE - 4) / DEPTH) if vertical else Vector2(size.x * TILE - 4, first.y)
	var length := first.distance_to(last)
	var double_leaf := (size.y if vertical else size.x) > 1
	var span := length / 2.0 - 0.5 if double_leaf else length - 3.5
	var angle := PI / 2.0 if vertical else 0.0
	var opening := -PI / 2.0 * amount
	_leaf(first, span, angle + opening, ramp, material == "steel", arched)
	if double_leaf:
		_leaf(last, span, angle + PI - opening, ramp, material == "steel", arched)
	for point: Vector2 in [first, last]:
		_box(Vector3(point.x - 3.5, point.y - 3.5, 0), Vector3(7, 7, 41), ramp, 1)
		_box(Vector3(point.x - 4.5, point.y - 4.5, 40), Vector3(9, 9, 3), ramp, 0)
		_box(Vector3(point.x - 2.5, point.y + 3.6, 5), Vector3(1, 0.3, 29), ramp, 2)


func _leaf(hinge: Vector2, span: float, angle: float, ramp: Array[Color], iron: bool, arched: bool) -> void:
	# All boards, braces and hardware turn around exactly the same hinge in the ground plane. Height never rotates.
	var direction := Vector2(cos(angle), sin(angle))
	var across := Vector2(-direction.y, direction.x)
	var low := 5.0
	var high := 36.0
	var count := maxi(3, roundi(span / (7.0 if not iron else 9.0)))
	for plank: int in count:
		var along := 3.0 + plank * (span - 3.0) / count
		var width := (span - 3.0) / count - (2.7 if iron else 0.4)
		var height := high + (sin(float(plank + 0.5) / count * PI) * 5.0 if arched else 0.0)
		_oriented_box(
			hinge, direction, across, Vector3(along, -1.7, low), Vector3(width, 3.4, height - low), ramp, 1 + plank % 2
		)
		if not iron:
			_oriented_box(
				hinge, direction, across, Vector3(along + width * 0.3, 1.8, low + 5), Vector3(0.55, 0.1, 11), ramp, 2
			)
	for height: float in [low, high - 4]:
		_oriented_box(
			hinge, direction, across, Vector3(2, -2.7, height), Vector3(span - 2, 5.4, 4), ramp, 0 if not iron else 1
		)
	for along: float in [2.0, span - 3.0]:
		_oriented_box(hinge, direction, across, Vector3(along, -2.8, low), Vector3(3.0, 5.6, high - low), ramp, 1)
	if not iron:
		for side: float in [-3.0, 3.0]:
			_brace(hinge, direction, across, span, side, ramp[0])
	for side: float in [-1.0, 1.0]:
		for height: float in [10.0, 30.0]:
			_oriented_box(
				hinge,
				direction,
				across,
				Vector3(0, side * 3.5 - 0.5, height),
				Vector3(minf(9, span * 0.35), 1.0, 2.5),
				_steel,
				3
			)
			_oriented_box(
				hinge, direction, across, Vector3(2.5, side * 4.1, height + 0.5), Vector3(1, 0.2, 1), _steel, 0
			)
		_oriented_box(hinge, direction, across, Vector3(span - 7, side * 4 - 1, 21), Vector3(4, 2, 2), _gold, 1)


func _brace(origin: Vector2, direction: Vector2, across: Vector2, span: float, side: float, color: Color) -> void:
	var start := Vector2(4, 10)
	var end := Vector2(span - 3, 29)
	var normal := (end - start).orthogonal().normalized() * 1.5
	var polygon := ""
	var depth := 0.0
	for point: Vector2 in [start + normal, end + normal, end - normal, start - normal]:
		var ground := origin + direction * point.x + across * side
		var projected := _offset + Vector2(ground.x, ground.y * DEPTH - point.y)
		polygon += "%.2f,%.2f " % [projected.x, projected.y]
		depth += ground.y + point.y * 0.001
	_faces.append(
		{
			"depth": depth / 4.0,
			"svg":
			'<polygon points="%s" fill="#%s" stroke="#2a1d2b" stroke-width="0.65"/>' % [polygon, color.to_html(false)]
		}
	)


func _box(at: Vector3, extent: Vector3, ramp: Array[Color], shade: int) -> void:
	_oriented_box(Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, at, extent, ramp, shade)


func _oriented_box(
	origin: Vector2, direction: Vector2, across: Vector2, at: Vector3, extent: Vector3, ramp: Array[Color], shade: int
) -> void:
	var points: Array[Vector3] = []
	for z: int in 2:
		for y: int in 2:
			for x: int in 2:
				var ground := origin + direction * (at.x + x * extent.x) + across * (at.y + y * extent.y)
				points.append(Vector3(ground.x, ground.y, at.z + z * extent.z))
	# Back and bottom faces cannot be seen by the camera; the two visible side faces depend on the hinge angle.
	var faces: Array = [[4, 5, 7, 6]]
	faces.append([2, 3, 7, 6] if across.y >= 0 else [0, 1, 5, 4])
	faces.append([1, 3, 7, 5] if direction.y >= 0 else [0, 2, 6, 4])
	for i: int in faces.size():
		var polygon := ""
		var depth := 0.0
		for index: int in faces[i]:
			var point := points[index]
			var projected := _offset + Vector2(point.x, point.y * DEPTH - point.z)
			polygon += "%.2f,%.2f " % [projected.x, projected.y]
			depth += point.y + point.z * 0.001
		var color := ramp[clampi(shade + (-1 if i == 0 else (1 if i == 2 else 0)), 0, ramp.size() - 1)]
		_faces.append(
			{
				"depth": depth / 4.0,
				"svg":
				(
					'<polygon points="%s" fill="#%s" stroke="#2a1d2b" stroke-width="0.65" stroke-linejoin="round"/>'
					% [polygon, color.to_html(false)]
				)
			}
		)
