extends SceneTree
## How long one edit of Lanternroot Studio takes on the main thread, stage by stage, on the real town (a copy of it in a
## temporary folder; the real content and the player's drafts are never touched):
##   flock /tmp/rootward-godot.lock godot --headless --path game -s res://tools/studio_place_bench.gd < /dev/null
## It mounts the overworld with the Studio, enters Edit, then times 50 barrels placed, 20 cottages placed, 20 moves,
## 20 flips, a batch of 10 barrels at once, 20 deletes, 20 undos and 10 redos. Each edit's stages (the command, the
## map build, the town redraw, the pick index, the overlay, the selection, the panels, ...) come from StudioMode.lap;
## "total" is the whole call, and "next frame" the frame after it (any value over 16 ms is a dropped frame). Prints
## p50, p95 and max in milliseconds. ROOTWARD_BENCH_SCALE=0.2 runs a fifth as many edits.

const TEST_ROOT := "user://studio_test/bench"
const TOWN := "lanternroot"
const LOOK := {
	"outfit": "outfit/tunic",
	"hair": "hair/short",
	"colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"}
}
const BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true}
const STAGES: Array[String] = [
	"apply", "build", "town", "pick", "overlay", "set_placed", "selection", "hover", "panels", "schedule"
]

var _studio: StudioMode
var _screen: OverworldScreen
var _root := ""
var _used: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_root = TEST_ROOT.path_join(str(Time.get_ticks_usec()))
	var old_content := StudioMode.content_dir
	StudioMode.drafts_dir = _root.path_join("drafts")
	StudioMode.playtest_dir = _root.path_join("playtest")
	StudioMode.content_dir = _root.path_join("content")
	_copy_tree("res://content/packs/core/overworld", StudioMode.content_dir.path_join("packs/core/overworld"))
	OS.set_environment("ROOTWARD_STUDIO", "1")
	Game.reset(_root.path_join("saves"))
	Game.boot()
	Game.profile.needs_name = false
	Game.profile.preferred_language = "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	OverworldStore.for_profile().delete_state()
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var map: Dictionary = OverworldScreen.catalog_of().maps[TOWN]
	var state := OverworldState.fresh(TOWN, map.start, "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Bench"
	state.flags = BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	_screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	root.add_child(_screen)
	await _frames(6)
	_studio = _screen.get("_studio") as StudioMode
	_studio.set_editing(true)
	await _frames(6)
	_studio.work.flush()
	var objects := ((_studio.current_map().get("objects", []) as Array).size())
	print("town objects: %d, nodes: %d" % [objects, _studio.map_view().things.get_child_count() + _studio.map_view().underfoot.get_child_count()])
	var scale := float(OS.get_environment("ROOTWARD_BENCH_SCALE")) if OS.get_environment("ROOTWARD_BENCH_SCALE") != "" else 1.0
	_studio.profiling = true

	var barrels: Array[int] = []
	var cottages: Array[int] = []
	var rows := {}
	rows["place barrel"] = await _series(int(50 * scale), func(i: int) -> void:
		var cell := _free_cell(Vector2i.ONE)
		var done := _studio.work.place(StudioAssets.template("barrel"), cell, true)
		barrels.append(int(done.sid)))
	rows["place cottage"] = await _series(int(20 * scale), func(i: int) -> void:
		var cell := _free_cell(Vector2i(3, 3))
		var done := _studio.work.place(StudioAssets.template("cottage"), cell + Vector2i(1, 2), true)
		cottages.append(int(done.sid)))
	rows["move"] = await _series(int(20 * scale), func(i: int) -> void:
		_studio.work.move([barrels[i % barrels.size()]], Vector2i(0, 1), true))
	rows["flip"] = await _series(int(20 * scale), func(i: int) -> void:
		_studio.work.flip([barrels[i % barrels.size()]]))
	rows["row of 10"] = await _series(int(5 * scale), func(i: int) -> void:
		var cells: Array[Vector2i] = []
		for n: int in 10:
			cells.append(_free_cell(Vector2i.ONE))
		_studio.work.place_row(StudioAssets.template("barrel"), cells, true))
	rows["delete barrel"] = await _series(int(20 * scale), func(i: int) -> void:
		_studio.work.delete([barrels[i]], true))
	rows["delete cottage"] = await _series(int(10 * scale), func(i: int) -> void:
		_studio.work.delete([cottages[i]], true))
	rows["undo"] = await _series(int(20 * scale), func(_i: int) -> void:
		_studio.work.undo())
	rows["redo"] = await _series(int(10 * scale), func(_i: int) -> void:
		_studio.work.redo())
	_studio.profiling = false
	_report(rows)

	_screen.queue_free()
	await _frames(4)
	Background.finish_all()
	Game.reset()
	StudioMode.content_dir = old_content
	_remove_tree(_root)
	quit()


## Runs `edit` n times, one per frame pair, and returns {stage: Array[int] microseconds, "total": ..., "next frame": ...}.
func _series(n: int, edit: Callable) -> Dictionary:
	var out := {"total": [] as Array[int], "next frame": [] as Array[int]}
	for stage: String in STAGES:
		out[stage] = [] as Array[int]
	await _frames(2)
	for i: int in n:
		_studio.stage_usec.clear()
		var started := Time.get_ticks_usec()
		edit.call(i)
		var finished := Time.get_ticks_usec()
		(out["total"] as Array[int]).append(finished - started)
		for stage: String in STAGES:
			(out[stage] as Array[int]).append(int(_studio.stage_usec.get(stage, 0)))
		await process_frame
		(out["next frame"] as Array[int]).append(Time.get_ticks_usec() - finished)
		await process_frame
	return out


func _report(rows: Dictionary) -> void:
	var columns: Array[String] = ["total"]
	columns.append_array(STAGES)
	columns.append("next frame")
	for name: String in rows:
		var series: Dictionary = rows[name]
		var line := "%-15s n=%-3d" % [name, (series["total"] as Array[int]).size()]
		print(line)
		for column: String in columns:
			var values: Array[int] = series[column]
			if values.is_empty():
				continue
			var ordered := values.duplicate()
			ordered.sort()
			var over := 0
			for v: int in values:
				over += 1 if v > 16000 else 0
			print(
				"    %-11s p50 %7.2f   p95 %7.2f   max %7.2f ms%s"
				% [
					column,
					ordered[ordered.size() / 2] / 1000.0,
					ordered[mini(ordered.size() - 1, int(ordered.size() * 0.95))] / 1000.0,
					ordered[ordered.size() - 1] / 1000.0,
					("   (%d over 16 ms)" % over) if over > 0 and column in ["total", "next frame"] else ""
				]
			)


## A cell where something of `size` fits on free ground near the start, not used yet. Returns the top-left cell.
func _free_cell(size: Vector2i) -> Vector2i:
	var map := _studio.current_map()
	var pick := _studio.pick()
	var around: Vector2i = map.start
	for radius: int in range(2, 40):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := around + Vector2i(dx * 2, dy * 2)
				if _fits(map, pick, cell, size):
					for y: int in size.y:
						for x: int in size.x:
							_used[cell + Vector2i(x, y)] = true
					return cell
	return around


func _fits(map: Dictionary, pick: StudioPick, cell: Vector2i, size: Vector2i) -> bool:
	for y: int in range(-1, size.y + 1):
		for x: int in range(-1, size.x + 1):
			var at := cell + Vector2i(x, y)
			if OverworldMap.blocked(map, at) or _used.has(at) or not pick.objects_at_cell(at).is_empty():
				return false
	return true


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _copy_tree(source: String, target: String) -> void:
	DirAccess.make_dir_recursive_absolute(target)
	for directory: String in DirAccess.get_directories_at(source):
		_copy_tree(source.path_join(directory), target.path_join(directory))
	for file: String in DirAccess.get_files_at(source):
		DirAccess.copy_absolute(source.path_join(file), target.path_join(file))


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
