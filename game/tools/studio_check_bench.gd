extends SceneTree
## Times what Lanternroot Studio does after a placement, on the real town copied to a temporary folder: the live
## whole-world check (and its parts) and the draft save, as p50 / p95 / max over many runs.
##   godot --headless --path game -s res://tools/studio_check_bench.gd < /dev/null
## Content, drafts, playtest and saves all live under user://studio_bench/<stamp>/ and are removed at the end.

const ROOT := "user://studio_bench"
const TOWN := "lanternroot"
const PLACEMENTS := 20
const FRAMED := 10
const WINDOW := 3.0
const LOOK := {"outfit": "outfit/tunic", "hair": "hair/short", "colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"}}
const BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true}

var _root := ""
var _times: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_root = ROOT.path_join(str(Time.get_ticks_usec()))
	var old_drafts := StudioMode.drafts_dir
	var old_playtest := StudioMode.playtest_dir
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
	var screen := (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	root.add_child(screen)
	await _frames(6)
	var studio := screen.get("_studio") as StudioMode
	studio.set_editing(true)
	await _frames(3)
	studio.studio_camera().toggle_overview()
	await _frames(3)
	print("map objects: %d, content: %s" % [(studio.work.doc().data.objects as Array).size(), StudioMode.content_dir])
	await _measure(studio)
	screen.queue_free()
	await _frames(4)
	Background.finish_all()
	Game.reset()
	StudioMode.drafts_dir = old_drafts
	StudioMode.playtest_dir = old_playtest
	StudioMode.content_dir = old_content
	_remove_tree(_root)
	quit()


func _measure(studio: StudioMode) -> void:
	var tools := studio.publish_tools
	var cells := _free_cells(studio)
	var at := 0
	# Phase 1: what each step costs, called directly (the whole-world review taken apart; the save and the check as
	# the Studio calls them).
	for placed: int in PLACEMENTS:
		var t0 := Time.get_ticks_usec()
		var result := studio.work.place(StudioAssets.template("barrel"), cells[at])
		at += 1
		_note("place (command, rebuild, redraw)", Time.get_ticks_usec() - t0)
		if not bool(result.ok):
			continue
		_probe_check(studio)
		var t1 := Time.get_ticks_usec()
		tools.refresh_now()
		_note("live check: refresh_now, synchronous", Time.get_ticks_usec() - t1)
		var t2 := Time.get_ticks_usec()
		studio.work.flush()
		_note("draft save: flush, synchronous", Time.get_ticks_usec() - t2)
		await process_frame
	# Phase 2: real frames. After each placement the Studio runs on its own for WINDOW seconds: the 0.2 s check timer,
	# the check, the 2 s draft save. Every frame's duration is noted, and how long until the check's answer arrived.
	await _frames(10)
	for placed: int in FRAMED:
		var result := studio.work.place(StudioAssets.template("barrel"), cells[at])
		at += 1
		if not bool(result.ok):
			continue
		var before: Variant = tools.review_data.get("sessions")
		var begun := Time.get_ticks_usec()
		var last := begun
		var answered := false
		while Time.get_ticks_usec() - begun < WINDOW * 1000000:
			await process_frame
			var now := Time.get_ticks_usec()
			_note("frame after a placement (all frames in the %d s)" % int(WINDOW), now - last)
			last = now
			if not answered and not is_same(tools.review_data.get("sessions"), before):
				answered = true
				_note("placement to live status shown (latency)", now - begun)
	print("")
	print("%d placements timed step by step, %d followed through %d s of frames; ms" % [PLACEMENTS, FRAMED, int(WINDOW)])
	_table()


## The live check taken apart: what StudioPublish.review does, step by step.
func _probe_check(studio: StudioMode) -> void:
	var service := StudioPublish.new()
	service.content_root = studio.content_root()
	service.drafts_dir = StudioMode.drafts_dir
	var sessions := studio.work.sessions()
	var t := Time.get_ticks_usec()
	var problems: Array[Dictionary] = []
	var all_sessions := service._collect(sessions, problems)
	t = _lap("  review: collect (drafts on disk + sessions)", t)
	var drafts: Dictionary = {}
	var sids: Dictionary = {}
	for id: String in all_sessions:
		var session: StudioSession = all_sessions[id]
		if session.doc().to_text() == session.base_doc.to_text():
			continue
		drafts[session.path] = session.doc().data
		sids[session.path] = session.doc().sids
	t = _lap("  review: changed-or-not (two to_text per map)", t)
	for id: String in all_sessions:
		var session: StudioSession = all_sessions[id]
		if session.doc().to_text() != session.base_doc.to_text():
			StudioDiff.summary(session.base_doc, session.doc())
			StudioDiff.lines(session.base_doc, session.doc())
			StudioFiles.read_text(session.path).sha256_text()
	t = _lap("  review: diff summary + lines + disk hash", t)
	var maps := service._maps(drafts, sids, problems)
	t = _lap("  review: maps not drafted (read + parse)", t)
	var loaded := OverworldContent.load_world(service.content_root, drafts)
	t = _lap("  review: load_world (all content + builds)", t)
	var art := service._art()
	t = _lap("  review: art index (folders + world.json)", t)
	var context := {"maps": maps, "sids": sids, "terrain": loaded.catalog.terrain, "townsfolk": loaded.catalog.townsfolk,
		"art": art.pictures, "footprints": art.footprints}
	StudioRules.check(context)
	t = _lap("  review: StudioRules.check (schema + build + rules)", t)
	var session := studio.work.session()
	session.changes()
	t = _lap("  refresh_now: session.changes() (diff) for the top bar", t)
	session.build(studio.catalog().terrain)
	t = _lap("  place: session.build (schema check + OverworldMap.build)", t)
	session.status()
	t = _lap("  place: session.status() (the top bar's draft text)", t)
	var doc := session.doc()
	var text := ""
	text = JSON.stringify({"base_text": session.base_text, "data": doc.data, "sids": doc.sids}, "\t", false, true)
	t = _lap("  save: JSON.stringify of the draft", t)
	doc.copy()
	t = _lap("  doc.copy() (a snapshot by copying)", t)
	text.length()


func _lap(label: String, from: int) -> int:
	var now := Time.get_ticks_usec()
	_note(label, now - from)
	return Time.get_ticks_usec()


func _note(label: String, usec: int) -> void:
	if not _times.has(label):
		_times[label] = []
	(_times[label] as Array).append(usec)


func _table() -> void:
	print("%-62s %9s %9s %9s %5s %6s" % ["step", "p50 ms", "p95 ms", "max ms", "runs", ">16ms"])
	for label: String in _times:
		var values: Array = _times[label]
		values.sort()
		var n := values.size()
		var slow := values.filter(func(usec: int) -> bool: return usec > 16667).size()
		print("%-62s %9.2f %9.2f %9.2f %5d %6d" % [label, values[n / 2] / 1000.0, values[mini(n - 1, int(n * 0.95))] / 1000.0, values[n - 1] / 1000.0, n, slow])


## Walkable, unclaimed cells of the town, scattered so each placement is its own.
func _free_cells(studio: StudioMode) -> Array[Vector2i]:
	var map := studio.current_map()
	var out: Array[Vector2i] = []
	var size := OverworldMap.size_of(map)
	for y: int in range(2, size.y - 2, 3):
		for x: int in range(2, size.x - 2, 3):
			var cell := Vector2i(x, y)
			if not OverworldMap.blocked(map, cell) and not OverworldMap.blocked(map, cell + Vector2i(1, 0)):
				out.append(cell)
	return out


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
