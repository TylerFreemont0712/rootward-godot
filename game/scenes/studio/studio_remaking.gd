class_name StudioRemaking
extends Node
## Resizing by remaking (Concept/v0.3/10, section 7.7), the Studio's side: the footprint handles of a selected thing
## whose picture has a blockout, the question "Remake it at 6 x 5?", and the answer. A yes drafts the remake: its
## catalog entry (and its source's family) in the catalog's draft, the thing in the map's draft with the new art and
## size at once (TownMapView draws the source's picture stretched to it, the overlay hatches it), and its spec in the
## queue (StudioRemakes). Run remakes draws the queued ones; when a picture lands the placeholder gives way to it.
##
## A remake of a remake is a remake of the original (barrel-2x1 dragged to 3 x 1 is barrel-3x1), and dragging back to
## the original's size gives the original back. A size whose picture exists already is only a swap, like a variant.

## The queue, the catalog's draft or a run changed: the tools column shows them again.
signal changed

const HANDLE := 7.0

var remakes: StudioRemakes
var catalog: StudioCatalogSession

var _studio: StudioMode
var _ask: ConfirmationDialog
var _asked_sid := -1
var _asked_size := Vector2i.ONE


func _init(studio: StudioMode) -> void:
	_studio = studio
	name = "Remaking"


func _ready() -> void:
	remakes = StudioRemakes.new()
	remakes.queue_path = StudioMode.drafts_dir.trim_suffix("/").get_base_dir().path_join("remakes.json")
	remakes.log_path = StudioMode.drafts_dir.trim_suffix("/").get_base_dir().path_join("remakes.log")
	add_child(remakes)
	remakes.progress.connect(func(line: String) -> void:
		_studio.say(line, false)
		changed.emit()
	)
	remakes.finished.connect(_finished)
	_ask = ConfirmationDialog.new()
	_ask.title = StudioText.t("remake_title")
	_ask.confirmed.connect(func() -> void: remake(_asked_sid, _asked_size))
	add_child(_ask)
	catalog = StudioCatalogSession.open(StudioMode.drafts_dir, StudioMode.content_dir)
	_show_draft()
	_register_stand_ins()


func _exit_tree() -> void:
	# The town outlives the Studio's stand-ins only in the Studio's runs.
	for id: String in remakes.waiting():
		OverworldArt.stand_ins.erase(id)


## Whether the dialog asking about a remake is open (editor keys wait meanwhile).
func asking() -> bool:
	return _ask != null and _ask.visible


# --- handles ------------------------------------------------------------------------------------------------------


## The world pipeline's spec of `art`, {} when there is none.
static func spec_of(art: String) -> Dictionary:
	var text := StudioFiles.read_text(StudioFiles.world_objects_dir().path_join(art + ".jsonc"))
	var parsed := Jsonc.parse(text) if text != "" else {}
	return parsed.value as Dictionary if bool(parsed.get("ok", false)) and parsed.value is Dictionary else {}


## The art a remake was made from (the original), or `art` itself.
func base_of(art: String) -> String:
	var source := StudioRemake.source_of(remakes.queue, art) if remakes != null else ""
	if source != "":
		return source
	var entry := StudioAssets.entry_of(art)
	var family := String(entry.get("family", ""))
	if family != "" and family != art and art.begins_with(family + "-") and not StudioAssets.entry_of(family).is_empty():
		return family
	return art


## Whether a placed thing can be dragged to another size: a building or prop whose original has a blockout.
func can_resize(object: Dictionary) -> bool:
	return String(object.get("kind", "")) in ["building", "prop"]


## The handles of a thing (world rectangles): the middle of its right edge, the middle of its bottom edge, and its
## bottom-right corner, each as {rect, kind}.
func handles_for(object: Dictionary, zoom: float) -> Array[Dictionary]:
	var box := StudioPick.footprint(object)
	var area := Rect2(Vector2(box.position) * OverworldScale.TILE, Vector2(box.size) * OverworldScale.TILE)
	# A handle stays a few screen pixels across, but never more than a fifth of a tile: zoomed out, a thing's middle
	# is still for moving it.
	var half := minf(HANDLE / maxf(zoom, 0.25), OverworldScale.TILE * 0.2)
	var points := {
		"right": Vector2(area.end.x, area.get_center().y), "bottom": Vector2(area.get_center().x, area.end.y),
		"corner": area.end,
	}
	var out: Array[Dictionary] = []
	for kind: String in points:
		out.append({"kind": kind, "rect": Rect2(points[kind] - Vector2(half, half), Vector2(half, half) * 2.0)})
	return out


## The size a handle dragged to `cell` proposes for a thing at `at` of `size`: whole cells, at least 1 x 1.
static func dragged_size(kind: String, at: Vector2i, size: Vector2i, cell: Vector2i) -> Vector2i:
	var wide := maxi(1, cell.x - at.x + 1) if kind in ["right", "corner"] else size.x
	var deep := maxi(1, cell.y - at.y + 1) if kind in ["bottom", "corner"] else size.y
	return Vector2i(wide, deep)


## Asks "Remake it at w x h?" for the thing `sid`.
func ask(sid: int, size: Vector2i) -> void:
	var object := _studio.work.raw(_studio.work.index_of(sid))
	if object.is_empty():
		return
	_asked_sid = sid
	_asked_size = size
	_ask.dialog_text = StudioText.t("remake_ask") % [StudioDiff.name_of(object), size.x, size.y]
	_ask.popup_centered()


# --- the remake ---------------------------------------------------------------------------------------------------


## Drafts the remake of thing `sid` at `size` (see the class's comment). {ok, reason}.
func remake(sid: int, size: Vector2i, free := false) -> Dictionary:
	var index := _studio.work.index_of(sid)
	var object := _studio.work.raw(index)
	if object.is_empty() or catalog == null:
		return {"ok": false, "reason": "nothing to remake"}
	var base := base_of(String(object.get("art", "")))
	var base_entry := catalog.entry(base)
	var base_size := OverworldMap.cell_of(base_entry.get("size", [1, 1]))
	var spec := spec_of(base)
	if not StudioRemake.can_remake(spec):
		_studio.say(StudioText.t("remake_adopted") % StudioAssets.name_of(base), true)
		return {"ok": false, "reason": "adopted"}
	var id := base if size == base_size else StudioRemake.id_of(base, size)
	var kind := String(object.get("kind", "prop"))
	var moved := object.duplicate(true)
	var reshaped := StudioResize.object_at_size(object, size)
	if bool(reshaped.ok):
		for key: String in ["solid_rows", "solid_cells"]:
			if (reshaped.object as Dictionary).has(key):
				moved[key] = reshaped.object[key]
	moved.erase("art_size")
	moved.erase("art_shape")
	moved["art"] = id
	moved["size"] = size
	moved["at"] = OverworldMap.cell_of(object.get("at", [0, 0]))
	var fit := StudioFit.check(_studio.current_map(), _studio.pick(), [moved], [index])
	if not fit.ok and not free:
		_studio.say(StudioText.t("remake_no_fit") % String(fit.reason), true)
		return {"ok": false, "reason": String(fit.reason)}
	var exists := OverworldArt.index("world").has(id) or id == base
	if not exists:
		var made := StudioRemake.spec_for(spec, id, size)
		if not bool(made.ok):
			_studio.say(String(made.error), true)
			return {"ok": false, "reason": String(made.error)}
		catalog.set_entry(base, StudioRemake.family_entry(base, base_entry))
		catalog.set_entry(id, StudioRemake.entry_for(base, base_entry, size))
		catalog.save()
		_show_draft()
		remakes.request(id, base, size, StudioRemake.spec_text(made.spec, base))
		_register_stand_ins()
	var commands: Array = [{"type": "set", "sid": sid, "key": "art", "value": id}]
	for key: String in ["art_size", "art_shape"]:
		if object.has(key):
			commands.append({"type": "set", "sid": sid, "key": key, "value": null})
	for key: String in ["solid_rows", "solid_cells"]:
		if moved.get(key) != object.get(key):
			commands.append({"type": "set", "sid": sid, "key": key, "value": moved.get(key)})
	var written: Variant = [size.x, size.y] if kind == "building" or size != Vector2i.ONE else null
	commands.append({"type": "set", "sid": sid, "key": "size", "value": written})
	if kind == "building":
		commands.append({"type": "set", "sid": sid, "key": "door", "value": [size.x / 2, size.y - 1]})
	var done := _studio.work.command({"type": "batch", "name": "Remake %s at %d x %d" % [base, size.x, size.y], "commands": commands})
	if not bool(done.get("ok", false)):
		return {"ok": false, "reason": String(done.get("error", ""))}
	if id == base:
		_studio.say(StudioText.t("remake_back") % StudioAssets.name_of(base), false)
	elif exists:
		_studio.say(StudioText.t("variant_of") % [StudioAssets.name_of(base), size.x, size.y], false)
	else:
		_studio.say(StudioText.t("remake_queued") % [StudioAssets.name_of(base), size.x, size.y], false)
	changed.emit()
	return {"ok": true, "reason": "", "id": id}


## Starts the queued remakes (Run remakes). False when there is nothing to run or one is running.
func run() -> bool:
	var started := remakes.run()
	if started:
		_studio.say(StudioText.t("remake_running"), false)
	changed.emit()
	return started


func waiting() -> Array[String]:
	return remakes.waiting() if remakes != null else [] as Array[String]


func _finished(made: Array[String], failed: Array[String]) -> void:
	OverworldArt.forget(made)
	StudioThumbs.clear()
	_register_stand_ins()
	# The town draws the new pictures: a whole redraw, since no object of the map changed.
	_studio.map_rebuilt(_studio.current_map(), {})
	if not failed.is_empty():
		_studio.say(StudioText.t("remake_failed") % remakes.last_line, true)
	elif not made.is_empty():
		_studio.say(StudioText.t("remake_done") % ", ".join(made), false)
	changed.emit()


## The catalog's draft is what the Studio browses and swaps variants in, until Publish.
func _show_draft() -> void:
	StudioAssets.draft_entries = catalog.doc().data.get("assets", {}) if catalog != null and catalog.changes() > 0 else {}


## Each waiting remake drawn as its source (OverworldArt.stand_ins), and the reviews told they wait.
func _register_stand_ins() -> void:
	var ids := waiting()
	for item: Variant in remakes.queue:
		if not item is Dictionary:
			continue
		var id := String((item as Dictionary).get("id", ""))
		var source := String((item as Dictionary).get("source", ""))
		if id in ids:
			OverworldArt.stand_ins[id] = {"source": source, "from": catalog.entry(source).get("size", [1, 1]) if catalog != null else [1, 1]}
		else:
			OverworldArt.stand_ins.erase(id)
	if _studio.publish_tools != null:
		_studio.publish_tools.set_remakes_waiting(ids)
