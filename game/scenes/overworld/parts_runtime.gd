class_name PartsRuntime
extends Node
## The parts of the game the player built, running (Concept/v0.4/01, section 3): each part's function, the program
## that last passed its task (Parts.program), answers the game's questions. Most answer once into a table, in one
## sandbox job on a thread: every key, every notch, every ground, every minute, so the game reads them and never waits.
## The menu, the music box's titles, the bag and the credits are called live, on a thread, when they are needed. Every
## answer is checked before it is used; one that fails is not used (the stand-in answers instead), and the problem is
## said once (`problem`). The overworld owns the state; this only reads it (`state_of`) and answers.
##
##   runtime.setup(catalog, func() -> Dictionary: return state)
##   runtime.refresh()                      # after a part is built or its code changes, and on load
##   runtime.shortcut("escape")             # "menu", or "" for nothing (or not built yet)
##   runtime.volume_at(7)                   # 0.49, or -1.0 when not built
##   var added: Dictionary = await runtime.bag_add("apple")   # {ok, bag, words}

## A part's tables or live answer landed: redraw what shows it.
signal changed(part: String)
## Something in a part's code went wrong for the game: Hotaru says it (once per part and problem).
signal problem(part: String, words: String)

const PHASES: Array[String] = ["night", "morning", "afternoon", "evening"]
## The stand-in colours of the minimap before the map part is built (it is not shown then; tests and shots use them).
const STAND_IN := {"water": Color("#57546a"), "building": Color("#383447"), "tree": Color("#555066")}
const STAND_IN_GROUND := Color("#82808f")

var catalog: Dictionary = {}
var _state_of: Callable = func() -> Dictionary: return {}
## part -> {stage index -> {args key -> answer}}: the answers that passed the game's checks.
var _tables: Dictionary = {}
## part -> the source the tables were made from, so a refresh with the same code does nothing.
var _made_from: Dictionary = {}
## Each refresh of a part takes a serial; only the newest run's answers land.
var _serial: Dictionary = {}
## map id -> {source, cells: PackedStringArray (one place name per cell, row by row)} for the map part's stage 2.
var _places: Dictionary = {}
## The menu's list, and the town's items it was made for.
var _menu_items: Array[String] = []
var _menu_for: Array[String] = []
var _menu_running := false
var _told: Dictionary = {}


func setup(world: Dictionary, state_of: Callable) -> void:
	catalog = world
	_state_of = state_of


func _state() -> Dictionary:
	var now: Variant = _state_of.call()
	return now if now is Dictionary else {}


func task(part: String) -> Dictionary:
	return (catalog.get("tasks", {}) as Dictionary).get(part, {})


func built(part: String) -> bool:
	return Parts.built(_state(), part)


func passed(part: String) -> int:
	return Parts.passed(_state(), part)


## Remakes the tables of `part`, or of every built part, in the background, unless they were made from the same
## program. A part that is not built (any more) loses its tables.
func refresh(part := "") -> void:
	var parts: Array[String] = []
	if part == "":
		parts = Parts.IDS.duplicate()
	else:
		parts.append(part)
	for id in parts:
		if not Parts.built(_state(), id):
			_tables.erase(id)
			_made_from.erase(id)
			if id == Parts.MAP:
				_places.clear()
			continue
		var program := Parts.program(_state(), id)
		var key := "%s|%d|%s" % [program.language, Parts.passed(_state(), id), program.source]
		if String(_made_from.get(id, "")) == key:
			continue
		_made_from[id] = key
		if id == Parts.MAP:
			_places.clear()
		if id == Parts.MENU:
			_menu_for = []
		_make_tables(id, program)
	_update_menu()


## Whether a part's tables are in (a part with no table is ready once built).
func has_tables(part: String) -> bool:
	return _tables.has(part) or (built(part) and part in [Parts.MENU, Parts.BAG, Parts.CREDITS])


func _make_tables(part: String, program: Dictionary) -> void:
	var serial := int(_serial.get(part, 0)) + 1
	_serial[part] = serial
	var the_task := task(part)
	if the_task.is_empty():
		return
	var stages := mini(Parts.passed(_state(), part), Tasks.stage_count(the_task))
	var jobs: Array = []
	for stage in stages:
		var domain := Parts.domain(part, stage, catalog)
		if part == Parts.MAP and stage >= 1:
			continue
		# Past the ends (below 0, above 10) is the volume's stage 2. Until it passes, the town never asks there
		# (volume_at keeps a notch in 0..10), so a stage 1 knob is not told off for notches it was never taught.
		if part == Parts.VOLUME and stages < 2:
			domain = domain.filter(func(args: Array) -> bool: return int(args[0]) >= 0 and int(args[0]) <= 10)
		if not domain.is_empty():
			jobs.append({"stage": stage, "domain": domain})
	if jobs.is_empty():
		_tables[part] = {}
		changed.emit(part)
		return
	var language := String(program.language)
	var source := String(program.source)
	var ran: Variant = await Background.run(
		func() -> Array:
			var out: Array = []
			for job: Dictionary in jobs:
				out.append({"stage": job.stage, "domain": job.domain, "table": TaskRun.table(the_task, int(job.stage), language, source, job.domain)})
			return out
	)
	if int(_serial.get(part, 0)) != serial or not ran is Array:
		return
	var made := {}
	for result: Dictionary in ran:
		made[int(result.stage)] = _kept_answers(part, int(result.stage), result.domain, result.table)
	_tables[part] = made
	changed.emit(part)


## The answers of a table that the game may use, keyed by their arguments; the rest are dropped, and the first
## problem is said.
func _kept_answers(part: String, stage: int, domain: Array, table: Dictionary) -> Dictionary:
	var kept := {}
	var problem_problem: Dictionary = table.get("problem", {})
	if not problem_problem.is_empty():
		_say(part, "run", Text.f("Your %s didn't run: %s", [_name_of(part, stage), _error_words(problem_problem)]))
		return kept
	var values: Array = table.get("values", [])
	var errors: Array = table.get("errors", [])
	if not errors.is_empty():
		var first: Dictionary = errors[0]
		var args: Array = domain[int(first.index)]
		_say(part, "error", Text.f("Your %s tripped on %s: %s", [_name_of(part, stage), _args_words(args), _error_words(first)]))
	var refused := 0
	var first_refused := -1
	for i in mini(values.size(), domain.size()):
		var args: Array = domain[i]
		var value: Variant = values[i]
		if value == null and _errored(errors, i):
			continue
		if _usable(part, stage, args, value):
			kept[_key(args)] = value
		else:
			refused += 1
			if first_refused < 0:
				first_refused = i
	if first_refused >= 0:
		var args: Array = domain[first_refused]
		var value: Variant = values[first_refused]
		_say(part, "refused", Text.f("Your %s gave %s for %s. The town can't use that, so it uses its own.", [_name_of(part, stage), Tasks.shown(value, String(Parts.program(_state(), part).get("language", "python"))), _args_words(args)]))
	return kept


func _errored(errors: Array, index: int) -> bool:
	for error: Dictionary in errors:
		if int(error.index) == index:
			return true
	return false


## Whether one answer may be used: the part's own rule for one answer (the whole-stage judges check the rest).
func _usable(part: String, stage: int, args: Array, value: Variant) -> bool:
	match part:
		Parts.SHORTCUTS:
			return value == null or (value is String and (value == "" or String(value) in Parts.PANELS))
		Parts.OPTIONS:
			var verdicts := TaskJudges.judge("options_rows", [{"args": []}], [{"ok": true, "value": value}])
			return not verdicts.is_empty() and bool(verdicts[0].ok)
		Parts.VOLUME:
			return Tasks.is_number(value) and float(value) >= -0.0001 and float(value) <= 1.0001
		Parts.MUSIC:
			return Tasks.is_whole(value) and int(value) >= 0 and int(value) < int(args[1])
		Parts.MAP:
			return Parts.colour_of(value) != null
		Parts.PROGRESS:
			return Tasks.is_whole(value) and int(value) >= 0 and int(value) <= 100
		Parts.GLOW:
			return Tasks.is_number(value) and float(value) >= -0.0001 and float(value) <= 1.0001
		Parts.WEATHER:
			return value is String and String(value) in Parts.WEATHERS
		Parts.HOURS:
			return value is String and String(value) in Parts.SPOTS
		Parts.CLOCK:
			if stage == 0:
				return value is String and String(value) in PHASES
			# The clock's text is judged as its task judges it: the right time, two digits for the minutes.
			var minute := int(args[0])
			var case_data := {"args": args, "want": "%d:%02d" % [floori(minute / 60.0), minute % 60]}
			var verdicts := TaskJudges.judge("clock_text", [case_data], [{"ok": true, "value": value}])
			return not verdicts.is_empty() and bool(verdicts[0].ok)
	return true


static func _key(args: Array) -> String:
	return JSON.stringify(args)


func _answer(part: String, stage: int, args: Array) -> Variant:
	var by_stage: Dictionary = _tables.get(part, {})
	var table: Dictionary = by_stage.get(stage, {})
	return table.get(_key(args))


# --- what the game asks --------------------------------------------------------------------------------------------


## What `key` opens, by the player's shortcut(): a panel's name, or "" for nothing, not built, or not ready.
func shortcut(key: String) -> String:
	if key in Parts.RESERVED_KEYS:
		return ""
	var answer: Variant = _answer(Parts.SHORTCUTS, 0, [key])
	return String(answer) if answer is String else ""


## Whether Esc opens the player's own menu: the menu is built and their shortcut() says "menu" for Esc.
func escape_opens_menu() -> bool:
	return built(Parts.MENU) and built(Parts.SHORTCUTS) and shortcut("escape") == "menu"


## The menu's items: the player's menu_items() for what the town offers now, or the town's own order while theirs is
## not built, not back yet, or not usable for this list.
func menu_items() -> Array[String]:
	var offered := Parts.menu_built(_state())
	if built(Parts.MENU) and _menu_for == offered and not _menu_items.is_empty():
		return _menu_items.duplicate()
	_update_menu()
	return Parts.town_menu(offered)


## Whether the menu's list is the player's own right now.
func menu_is_players() -> bool:
	return built(Parts.MENU) and _menu_for == Parts.menu_built(_state()) and not _menu_items.is_empty()


func _update_menu() -> void:
	if not built(Parts.MENU) or _menu_running:
		return
	var offered := Parts.menu_built(_state())
	if offered == _menu_for:
		return
	_menu_running = true
	var answer: Dictionary = await _call_live(Parts.MENU, 0, [offered])
	_menu_running = false
	if not bool(answer.ok):
		_menu_for = offered
		_menu_items = []
		_say(Parts.MENU, "run", Text.f("Your menu_items() tripped: %s. The menu is in the town's order for now.", [String(answer.words)]))
		return
	var verdicts := TaskJudges.judge("menu_items", [{"args": [offered]}], [{"ok": true, "value": answer.value}])
	_menu_for = offered
	_menu_items = []
	if verdicts.is_empty() or not bool(verdicts[0].ok):
		_say(Parts.MENU, "refused", Text.t("Your menu_items() didn't give a menu the town can use, so the menu is in the town's order for now."))
	else:
		for item: Variant in answer.value:
			_menu_items.append(String(item))
	changed.emit(Parts.MENU)
	# The town may have built something new while it ran.
	_update_menu()


## The rows of the player's Options page ([] when the options part is not built or its answer cannot be used).
func options_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var answer: Variant = _answer(Parts.OPTIONS, 0, [])
	if answer is Array:
		for row: Variant in answer:
			if row is Dictionary:
				out.append(row)
	return out


## How loud notch `notch` is by the player's volume(): -1.0 when the part is not built or the answer cannot be used.
## Before its stage 2 ("past the ends") a notch is kept between 0 and 10 first.
func volume_at(notch: int) -> float:
	if not built(Parts.VOLUME):
		return -1.0
	var asked := notch if passed(Parts.VOLUME) >= 2 else clampi(notch, 0, 10)
	asked = clampi(asked, Parts.NOTCH_LOW, Parts.NOTCH_HIGH)
	var answer: Variant = _answer(Parts.VOLUME, 0, [asked])
	return clampf(float(answer), 0.0, 1.0) if Tasks.is_number(answer) else -1.0


## The loudness of notches 0 to 10, for the Options page's little chart; empty when the part is not built.
func volume_curve() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if not built(Parts.VOLUME):
		return out
	for notch in 11:
		out.append(maxf(volume_at(notch), 0.0))
	return out


## The minimap's colours: ground -> Color, by the player's map_colour(); the stand-in greys before it is built.
func map_colours() -> Dictionary:
	var out := {}
	for ground in Parts.grounds(catalog):
		var answer: Variant = _answer(Parts.MAP, 0, [ground])
		var colour: Variant = Parts.colour_of(answer)
		if colour != null:
			out[ground] = colour
		else:
			var walkable := bool(((catalog.get("terrain", {}) as Dictionary).get(ground, {}) as Dictionary).get("walk", false))
			out[ground] = STAND_IN.get(ground, STAND_IN_GROUND if walkable else Color("#57546a"))
	return out


## The colour names the player's map_colour() gave, by ground (the full map's legend); {} before it is built.
func map_colour_names() -> Dictionary:
	var out := {}
	for ground in Parts.grounds(catalog):
		var answer: Variant = _answer(Parts.MAP, 0, [ground])
		if Parts.colour_of(answer) != null:
			out[ground] = String(answer)
	return out


## The place a cell is in, by the player's place_of() (map stage 2): "" when not built, not ready yet, or in none.
## The first ask for a map starts its table.
func place_at(map_id: String, cell: Vector2i) -> String:
	if passed(Parts.MAP) < 2:
		return ""
	var program := Parts.program(_state(), Parts.MAP)
	var made: Dictionary = _places.get(map_id, {})
	var identity := _places_identity(program)
	if String(made.get("identity", "")) != identity:
		_make_places(map_id, program)
		return ""
	var cells: PackedStringArray = made.get("cells", PackedStringArray())
	var map: Dictionary = (catalog.get("maps", {}) as Dictionary).get(map_id, {})
	var width := OverworldMap.size_of(map).x
	var index := cell.y * width + cell.x
	return cells[index] if index >= 0 and index < cells.size() else ""


func _places_identity(program: Dictionary) -> String:
	return "%s|%s|%s|%s" % [String(program.source), String(program.language), TranslationServer.get_locale(), Text.japanese_reading()]


func _make_places(map_id: String, program: Dictionary) -> void:
	var identity := _places_identity(program)
	var current: Dictionary = _places.get(map_id, {})
	if bool(current.get("running", false)) and String(current.get("identity", "")) == identity:
		return
	var map: Dictionary = (catalog.get("maps", {}) as Dictionary).get(map_id, {})
	if map.is_empty():
		return
	_places[map_id] = {"identity": identity, "running": true}
	# The places as the player's code is given them: their names in the player's language, so the map says them in it.
	var places: Array = []
	for place: Variant in (catalog.get("places", {}) as Dictionary).get(map_id, []):
		if place is Dictionary:
			var named := (place as Dictionary).duplicate()
			named.name = Text.t(String(named.get("name", "")))
			places.append(named)
	var domain := Parts.domain(Parts.MAP, 1, catalog, map, places)
	var the_task := task(Parts.MAP)
	var language := String(program.language)
	var source := String(program.source)
	var table: Variant = await Background.run(
		func() -> Dictionary: return TaskRun.table(the_task, 1, language, source, domain)
	)
	# A live language/reading change while the sandbox runs invalidates its translated place names.
	if String(_places.get(map_id, {}).get("identity", "")) != identity:
		return
	if _places_identity(program) != identity:
		_make_places(map_id, program)
		return
	var cells := PackedStringArray()
	# Only a place of this map (or nothing) may be shown: a name the map does not have is refused, once said.
	var names: Array[String] = []
	for place: Variant in places:
		if place is Dictionary:
			names.append(String((place as Dictionary).get("name", "")))
	var refused: Variant = null
	if table is Dictionary and (table.problem as Dictionary).is_empty():
		for value: Variant in table.values:
			var fine: bool = value == null or (value is String and (String(value) == "" or String(value) in names))
			cells.append(String(value) if fine and value is String else "")
			if not fine and refused == null:
				refused = value
		if not (table.errors as Array).is_empty():
			var first: Dictionary = table.errors[0]
			var args: Array = domain[int(first.index)]
			_say(Parts.MAP, "places", Text.f("Your place_of() tripped on x %d, y %d: %s", [int(args[0]), int(args[1]), _error_words(first)]))
	if refused != null:
		_say(Parts.MAP, "places-refused", Text.f("Your place_of() gave %s, which is no place on this map. The map leaves that cell's name blank.", [Tasks.shown(refused, language)]))
	_places[map_id] = {"identity": identity, "cells": cells, "running": false}
	changed.emit(Parts.MAP)


## Pip's percent by the player's progress(): -1 when not built or not usable (the tracker shows pips then).
func progress_of(done: int, total: int) -> int:
	if not built(Parts.PROGRESS):
		return -1
	if total > Parts.MOST_STEPS:
		return -1
	var answer: Variant = _answer(Parts.PROGRESS, 0, [done, total])
	return int(roundf(float(answer))) if Tasks.is_whole(answer) else -1


## The town's phase at `minute` by the player's time_of_day(): "" when not built (the town is always day then).
func phase_at(minute: int) -> String:
	if not built(Parts.CLOCK):
		return ""
	var answer: Variant = _answer(Parts.CLOCK, 0, [posmod(minute, Parts.DAY_MINUTES)])
	return String(answer) if answer is String else ""


## The clock's words at `minute` by the player's clock_text() (clock stage 2): "" before then.
func clock_text_at(minute: int) -> String:
	if passed(Parts.CLOCK) < 2:
		return ""
	var answer: Variant = _answer(Parts.CLOCK, 1, [posmod(minute, Parts.DAY_MINUTES)])
	return String(answer) if answer is String else ""


## The tracks of tracks.jsonc as the music box's titles() is given them: [{id, title, place}] in their order.
func track_list() -> Array:
	var tracks: Dictionary = catalog.get("tracks", {})
	var ids: Array = tracks.keys()
	ids.sort_custom(
		func(a: Variant, b: Variant) -> bool:
			var oa := int((tracks[a] as Dictionary).get("order", 0))
			var ob := int((tracks[b] as Dictionary).get("order", 0))
			return oa < ob if oa != ob else String(a) < String(b)
	)
	var out: Array = []
	for id: Variant in ids:
		# The player's code is given the titles in the player's language, so the music box shows them in it.
		out.append({"id": String(id), "title": Text.t(String(tracks[id].title)), "place": Text.t(String(tracks[id].get("place", "")))})
	return out


## The music box's titles: the player's titles() of the track list when it is built and usable, else the tracks' own.
func titles() -> Array[String]:
	var tracks := track_list()
	var own: Array[String] = []
	for track: Dictionary in tracks:
		own.append(String(track.title))
	if not built(Parts.MUSIC):
		return own
	var answer: Dictionary = await _call_live(Parts.MUSIC, 0, [tracks])
	if not bool(answer.ok) or not answer.value is Array or (answer.value as Array).size() != tracks.size():
		_say(Parts.MUSIC, "titles", Text.t("Your titles() didn't give one title per track, so the music box shows the tracks' own names."))
		return own
	var out: Array[String] = []
	for i in (answer.value as Array).size():
		var title: Variant = (answer.value as Array)[i]
		# A title that is not text (None, a number) shows the track's own name.
		out.append(String(title).left(48) if title is String and String(title).strip_edges() != "" else own[i])
	return out


## The track after `index` of `count` by the player's next_track() (music stage 2): -1 before then or when unusable.
func next_index(index: int, count: int) -> int:
	if passed(Parts.MUSIC) < 2 or count < 1 or count > Parts.MOST_TRACKS:
		return -1
	var answer: Variant = _answer(Parts.MUSIC, 1, [index, count])
	return int(answer) if Tasks.is_whole(answer) else -1


## Puts one `item` in the bag with the player's add(): {ok, bag, words}. The state is not changed here; the caller
## keeps `bag` when ok. Not ok: the bag stays as it was and `words` says why.
func bag_add(item: String) -> Dictionary:
	var before: Array = Bag.cleaned(_state().get("bag", []))
	if not built(Parts.BAG):
		return {"ok": false, "bag": before, "words": Text.t("There's no bag to put it in yet.")}
	var answer: Dictionary = await _call_live(Parts.BAG, 0, [before, item])
	if not bool(answer.ok):
		return {"ok": false, "bag": before, "words": Text.f("Your add() tripped: %s", [String(answer.words)])}
	var verdict := Bag.valid_add(before, answer.value, item)
	if not bool(verdict.get("ok", false)):
		return {"ok": false, "bag": before, "words": _bag_words("add", verdict, item)}
	return {"ok": true, "bag": Bag.cleaned(answer.value), "words": ""}


## Takes `count` of `item` out with the player's remove(), one call each: {ok, bag, words}. All or nothing.
func bag_remove(item: String, count := 1) -> Dictionary:
	var before: Array = Bag.cleaned(_state().get("bag", []))
	if passed(Parts.BAG) < 2:
		return {"ok": false, "bag": before, "words": Text.t("Your bag can't give things away yet.")}
	var bag := before
	for i in count:
		var answer: Dictionary = await _call_live(Parts.BAG, 1, [bag, item])
		if not bool(answer.ok):
			return {"ok": false, "bag": before, "words": Text.f("Your remove() tripped: %s", [String(answer.words)])}
		var verdict := Bag.valid_remove(bag, answer.value, item)
		if not bool(verdict.get("ok", false)):
			return {"ok": false, "bag": before, "words": _bag_words("remove", verdict, item)}
		bag = Bag.cleaned(answer.value)
	return {"ok": true, "bag": bag, "words": ""}


func _bag_words(function: String, verdict: Dictionary, item: String) -> String:
	var said := Tasks.advice(task(Parts.BAG), 0 if function == "add" else 1, {"ok": false, "problem": {}, "cases": [verdict]})
	var text := String(said.text) if String(said.text) != "" else String(verdict.get("reason", ""))
	return Text.f("Your %s() didn't work for %s: %s", [function, item, text])


## The credits' lines by the player's credits(): [] when not built or not usable.
func credits_lines(maker: String, part_names: Array[String]) -> Array[String]:
	var out: Array[String] = []
	if not built(Parts.CREDITS):
		return out
	var answer: Dictionary = await _call_live(Parts.CREDITS, 0, [maker, part_names])
	if not bool(answer.ok):
		_say(Parts.CREDITS, "run", Text.f("Your credits() tripped: %s", [String(answer.words)]))
		return out
	var verdicts := TaskJudges.judge("credits", [{"args": [maker, part_names]}], [{"ok": true, "value": answer.value}])
	if verdicts.is_empty() or not bool(verdicts[0].ok):
		_say(Parts.CREDITS, "refused", Text.t("Your credits() didn't give lines the credits can roll."))
		return out
	for line: Variant in answer.value:
		out.append(String(line))
	return out


# --- chapter 3 (Concept/v0.4/05) -------------------------------------------------------------------------------------


## Hotaru's brightness at second `t` (looping a minute) by the player's glow(): -1.0 before it is built.
func glow_at(t: int) -> float:
	if not built(Parts.GLOW):
		return -1.0
	var answer: Variant = _answer(Parts.GLOW, 0, [posmod(t, Parts.GLOW_SECONDS)])
	return clampf(float(answer), 0.0, 1.0) if Tasks.is_number(answer) else -1.0


## The weather on day `day` by the player's weather() (it repeats every four weeks): "" before it is built.
func weather_on(day: int) -> String:
	if not built(Parts.WEATHER):
		return ""
	var answer: Variant = _answer(Parts.WEATHER, 0, [posmod(day, Parts.WEATHER_DAYS)])
	return String(answer) if answer is String else ""


## Where `person` is at `hour` by the player's where(): "home", "work", "inn", or "" before it is built (or unknown).
func where_at(person: String, hour: int) -> String:
	if not built(Parts.HOURS):
		return ""
	var answer: Variant = _answer(Parts.HOURS, 0, [person, posmod(hour, Parts.HOURS_IN_DAY)])
	return String(answer) if answer is String else ""


## How many of `lanterns` ({name, lit}) are lit, by the player's count(): -1 when not built or unusable.
func count_lit(lanterns: Array) -> int:
	if not built(Parts.COUNT):
		return -1
	var answer: Dictionary = await _call_live(Parts.COUNT, 0, [lanterns])
	if not bool(answer.ok):
		_say(Parts.COUNT, "run", Text.f("Your count() tripped: %s", [String(answer.words)]))
		return -1
	var value: Variant = answer.value
	if not Tasks.is_whole(value) or int(value) < 0 or int(value) > lanterns.size():
		_say(Parts.COUNT, "refused", Text.f("Your count() gave %s, but there are only %d lanterns.", [Tasks.shown(value), lanterns.size()]))
		return -1
	return int(value)


## The coins `count` of `item` fetch at `prices` by the player's price(): -1 when not built or unusable.
func price_of(prices: Dictionary, item: String, count: int) -> int:
	if not built(Parts.SHOP):
		return -1
	var answer: Dictionary = await _call_live(Parts.SHOP, 0, [prices, item, count])
	if not bool(answer.ok) or not Tasks.is_whole(answer.value) or int(answer.value) < 0:
		_say(Parts.SHOP, "price", Text.t("Your price() didn't give a whole number of coins, so Nym can't pay that."))
		return -1
	return int(answer.value)


## Whether `coins` buy something that costs `cost`, by the player's can_buy() (shop stage 2). Null when it can't say.
func can_buy(coins: int, cost: int) -> Variant:
	if passed(Parts.SHOP) < 2:
		return null
	var answer: Dictionary = await _call_live(Parts.SHOP, 1, [coins, cost])
	if not bool(answer.ok) or not answer.value is bool:
		_say(Parts.SHOP, "buy", Text.t("Your can_buy() didn't answer true or false, so Nym can't sell yet."))
		return null
	return bool(answer.value)


## Everything in the bag, counted by the player's total(): -1 when not built or unusable.
func total_of(bag: Array) -> int:
	if not built(Parts.TIDY):
		return -1
	var answer: Dictionary = await _call_live(Parts.TIDY, 0, [bag])
	if not bool(answer.ok) or not Tasks.is_whole(answer.value) or int(answer.value) < 0:
		_say(Parts.TIDY, "total", Text.t("Your total() didn't give a whole number."))
		return -1
	return int(answer.value)


## The bag tidied by the player's tidy() (tidy stage 2): {ok, bag, words}, judged as the task judges it.
func tidy_bag(bag: Array) -> Dictionary:
	if passed(Parts.TIDY) < 2:
		return {"ok": false, "bag": bag, "words": Text.t("Your bag can't tidy itself yet. Mira can help.")}
	var answer: Dictionary = await _call_live(Parts.TIDY, 1, [bag])
	if not bool(answer.ok):
		return {"ok": false, "bag": bag, "words": Text.f("Your tidy() tripped: %s", [String(answer.words)])}
	var verdicts := TaskJudges.judge("tidy_sorted", [{"args": [bag]}], [{"ok": true, "value": answer.value}])
	if verdicts.is_empty() or not bool(verdicts[0].ok):
		return {"ok": false, "bag": bag, "words": Text.t("Your tidy() lost or changed something, so the bag stays as it was.")}
	return {"ok": true, "bag": Bag.cleaned(answer.value), "words": ""}


## The lines (counted from 1) that differ between two versions, by the player's changed(): [] when not built or
## unusable, or when nothing changed.
func changed_lines(old_lines: Array, new_lines: Array) -> Array[int]:
	var out: Array[int] = []
	if not built(Parts.HISTORY):
		return out
	var answer: Dictionary = await _call_live(Parts.HISTORY, 0, [old_lines, new_lines])
	if not bool(answer.ok) or not answer.value is Array:
		return out
	var most := maxi(old_lines.size(), new_lines.size())
	for line: Variant in answer.value:
		if Tasks.is_whole(line) and int(line) >= 1 and int(line) <= most:
			out.append(int(line))
	return out


## One live call of a part's stage function on a thread: {ok, value, words}.
func _call_live(part: String, stage: int, args: Array) -> Dictionary:
	var program := Parts.program(_state(), part)
	var the_task := task(part)
	if program.is_empty() or the_task.is_empty():
		return {"ok": false, "value": null, "words": "not built"}
	var language := String(program.language)
	var source := String(program.source)
	var call := {
		"entries": Tasks.entries(the_task, stage, language),
		"signature": Tasks.signature(the_task, stage, language),
		"args": args,
		"mutates": int(Tasks.stage(the_task, stage).get("mutates", -1)),
	}
	var ran: Variant = await Background.run(func() -> Dictionary: return TaskRun.run(language, source, [call]))
	if not ran is Dictionary or String(ran.status) != "ok":
		var failed: Dictionary = ran if ran is Dictionary else {}
		return {"ok": false, "value": null, "words": _error_words(failed)}
	var result: Dictionary = (ran.results as Array)[0]
	if not bool(result.get("ok", false)):
		return {"ok": false, "value": null, "words": _error_words(result)}
	return {"ok": true, "value": result.get("value"), "words": ""}


# --- words ---------------------------------------------------------------------------------------------------------


func _say(part: String, kind: String, words: String) -> void:
	var key := "%s:%s:%s" % [part, kind, String(_made_from.get(part, ""))]
	if _told.has(key):
		return
	_told[key] = true
	problem.emit(part, words)


func _name_of(part: String, stage: int) -> String:
	var the_task := task(part)
	return "%s()" % Tasks.entry(the_task, stage, String(Parts.program(_state(), part).get("language", "python")))


static func _args_words(args: Array) -> String:
	var parts := PackedStringArray()
	for arg: Variant in args:
		parts.append(Tasks.shown(arg) if not arg is Array else "[…]")
	return ", ".join(parts)


static func _error_words(error: Dictionary) -> String:
	var kind := String(error.get("kind", ""))
	var message := String(error.get("message", ""))
	var line := int(error.get("line", 0))
	var where := Text.f(" (line %d)", [line]) if line > 0 else ""
	return ("%s: %s%s" % [kind, message, where]) if kind != "" else message + where
