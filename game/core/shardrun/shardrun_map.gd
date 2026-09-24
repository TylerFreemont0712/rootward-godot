class_name ShardrunMap
extends RefCounted
## Layer maps (old ADR-0013), in the spirit of Slay the Spire: several paths climb from the bottom row to the top, each
## step moving up one row and at most one column sideways, and no path crosses another. The rooms they touch are the
## map, so branches and merges come out of the walk itself. The boss waits alone above the top row.
##
## A map is {nodes: [{id, row, col, kind}], edges: [[from, to]]}.

const ROOM_KINDS: Array[String] = ["fight", "elite", "rest", "forge", "treasure"]
## Kinds that should not follow themselves along a path: two rests or two elites in a row waste a choice.
const NO_REPEAT: Array[String] = ["elite", "rest", "forge", "treasure"]
## Attempts to find a kind that does not repeat its parent before settling for a fight.
const KIND_ATTEMPTS := 8


static func room_id(layer: int, row: int, col: int) -> String:
	return "l%d-r%d-c%d" % [layer, row, col]


static func boss_id(layer: int) -> String:
	return "l%d-boss" % layer


static func generate(seed: String, layer_index: int, layer: Dictionary) -> Dictionary:
	var rng := Rng.create(seed, "map:%d" % layer_index)
	var rows := int(layer.rows)
	var columns := int(layer.columns)
	var cells := {}  # id -> [row, col], in the order first visited
	var edges := {}  # "from>to" -> [from, to]
	var moves := {}  # "row:from>to", column moves already drawn
	var columns_list: Array = range(columns)
	var starts := rng.shuffled(columns_list)
	for path in int(layer.paths):
		# The first paths start in different columns, so the bottom row always offers a real choice.
		var col: int = starts[path] if path < starts.size() else floori(rng.next() * columns)
		var from := _visit(cells, layer_index, 0, col)
		for row in rows - 1:
			var options: Array[int] = []
			for next: int in [col - 1, col, col + 1]:
				if next >= 0 and next < columns and not _crosses(moves, row, col, next):
					options.append(next)
			var index := floori(rng.next() * options.size())
			var next_col: int = options[index] if index < options.size() else col
			var to := _visit(cells, layer_index, row + 1, next_col)
			edges["%s>%s" % [from, to]] = [from, to]
			moves["%d:%d>%d" % [row, col, next_col]] = true
			col = next_col
			from = to

	var parents := {}
	for edge: Array in edges.values():
		if not parents.has(edge[1]):
			parents[edge[1]] = []
		(parents[edge[1]] as Array).append(edge[0])
	var ordered: Array = cells.keys()
	ordered.sort_custom(
		func(a: String, b: String) -> bool:
			var ca: Array = cells[a]
			var cb: Array = cells[b]
			return ca[0] < cb[0] or (ca[0] == cb[0] and ca[1] < cb[1])
	)
	var kinds := {}
	var nodes: Array = []
	for id: String in ordered:
		var cell: Array = cells[id]
		var kind := _fixed_kind(layer, cell[0])
		if kind == "":
			kind = _pick_kind(layer, cell[0], parents.get(id, []), kinds, rng)
		kinds[id] = kind
		nodes.append({"id": id, "row": cell[0], "col": cell[1], "kind": kind})

	var boss := {"id": boss_id(layer_index), "row": rows, "col": (columns - 1) / 2, "kind": "boss"}
	var all_edges: Array = edges.values()
	for node: Dictionary in nodes:
		if node.row == rows - 1:
			all_edges.append([node.id, boss.id])
	nodes.append(boss)
	return {"nodes": nodes, "edges": all_edges}


## The rooms that can be entered next: the bottom row before the first room of a layer, then the rooms above.
static func next_rooms(map: Dictionary, position: Variant) -> Array:
	if position == null:
		return (map.nodes as Array).filter(func(node: Dictionary) -> bool: return int(node.row) == 0)
	var targets := {}
	for edge: Array in map.edges:
		if edge[0] == position:
			targets[edge[1]] = true
	return (map.nodes as Array).filter(func(node: Dictionary) -> bool: return targets.has(node.id))


static func _visit(cells: Dictionary, layer_index: int, row: int, col: int) -> String:
	var id := room_id(layer_index, row, col)
	if not cells.has(id):
		cells[id] = [row, col]
	return id


## LEARN: two paths cross when one steps right exactly where a neighbour steps left. Checking the mirror move before
## drawing is enough; going straight up can never cross anything, so every step has at least one legal choice.
static func _crosses(moves: Dictionary, row: int, from: int, to: int) -> bool:
	if to == from + 1 and moves.has("%d:%d>%d" % [row, from + 1, from]):
		return true
	return to == from - 1 and moves.has("%d:%d>%d" % [row, from - 1, from])


static func _fixed_kind(layer: Dictionary, row: int) -> String:
	var fixed: Dictionary = layer.get("fixed_rows", {})
	var kind: Variant = fixed.get(str(row))
	if kind == null:
		kind = fixed.get(str(row - int(layer.rows)))
	return "" if kind == null else kind


static func _pick_kind(layer: Dictionary, row: int, parents: Array, kinds: Dictionary, rng: Rng) -> String:
	var candidates: Array[String] = []
	var weights: Array[float] = []
	for kind in ROOM_KINDS:
		if kind != "elite" or row >= int(layer.get("elite_from_row", 3)):
			candidates.append(kind)
			weights.append(float(layer.weights[kind]))
	for attempt in KIND_ATTEMPTS:
		var index := Rng.pick_weighted(weights, rng.next())
		var kind := "fight" if index < 0 else candidates[index]
		var repeats := false
		if kind in NO_REPEAT:
			for parent: String in parents:
				if kinds.get(parent) == kind:
					repeats = true
		if not repeats:
			return kind
	return "fight"
