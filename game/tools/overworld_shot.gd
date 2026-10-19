extends Control
## Moments of Lanternroot's overworld for screenshots (ADR-0061), each in its own save folder:
##   ROOTWARD_LANTERNTOWN=<moment> scripts/screenshot.sh res://tools/overworld_shot.tscn shots/town.png 40
## Moments: creator, wake, home, boots, code, code-hints (Scribe with the hints open), town, square, talk, board, choice, bubble, thing-gate, thing-gate-open,
## thing-sign, studio, studio-plain, studio-browser, studio-context, studio-catalog, studio-remake, studio-land,
## studio-doors, studio-room, studio-link, studio-people, studio-people-doors, studio-debug, studio-debug-events, studio-thing, studio-wires,
## studio-quests, studio-quests-flags, studio-quests-talk (the quest editor, S9: a quest and its steps, the flag browser, a talk's nodes);
## tracker, tracker-pips, tracker-away, tracker-hidden, minimap, minimap-grey, fullmap, log (the v0.4 HUD: the quest tracker with its
## progress bar, direction line and minimap, the full map, and the quest log's Track; see _hud);
## add "-ja" for Japanese. The studio moments turn Lanternroot Studio on for the shot
## (ROOTWARD_STUDIO is set before the town is made) and press F2: `studio` is the town in Edit beside the Inn, with the
## grid, footprints, solid cells and doors on and the Inn selected; `studio-plain` is Edit with every overlay off, to
## compare with `town`. ROOTWARD_STUDIO_OVERVIEW=1 adds the overview (the whole map fitted).
## Hooks for any moment: ROOTWARD_LANTERNTOWN_MAP, _AT (x,y), _FACING, _MODEL (male/female), _FLAGS (comma list) and _CALL (a screen method).
## A moment says `shot_ready` once it is set up (the boots have been read, and a talk is typed out as far as the picture
## needs), so the frames the screenshot waits are counted from then.

## ROOTWARD_LANTERNTOWN_STEP=right starts one visual player step; _STEP_FRAMES holds the shot until a chosen pose.
signal shot_ready

const FULL_BOOTS := [
	{"key": "right", "do": [{"change": "x", "by": 1}]},
	{"key": "left", "do": [{"change": "x", "by": -1}]},
	{"key": "down", "do": [{"change": "y", "by": 1}]},
	{"key": "up", "do": [{"change": "y", "by": -1}]},
]
const LOOK := {
	"outfit": "outfit/tunic",
	"hair": "hair/short",
	"colours":
	{
		"skin": "skin_peach",
		"hair": "hair_brown",
		"main": "cloth_teal",
		"second": "cloth_cream",
		"accent": "cloth_orange"
	},
}


## The v0.4 HUD moments' own quest: four steps, the third a count with a pin at the Warm Hearth's door.
const HUD_QUESTS := {
	"keys":
	{
		"order": 5,
		"title": "A key for every door",
		"giver": "innkeeper",
		"summary": "Every door in Lanternroot opens on something you can write.",
		"steps":
		[
			{"text": "Meet Marta at the Warm Hearth.", "done": {"flag": "hud-1"}},
			{"text": "Ask Pip what a lantern counts.", "done": {"flag": "hud-2"}},
			{
				"text": "Meet more of the town.",
				"done": {"count": "met-", "at_least": 6},
				"at": {"map": "lanternroot", "at": [53, 26]}
			},
			{"text": "Write menu_items: what your menu shows.", "done": {"flag": "hud-4"}},
		],
	}
}
const HUD_FLAGS := {"hud-1": true, "hud-2": true, "met-pip": true, "met-guard": true, "met-innkeeper": true, "met-oracle": true}
## Districts for the full map's names (the real ones come with places.jsonc).
const HUD_PLACES := [
	{"name": "Home Hollow", "x": 4, "y": 38, "w": 16, "h": 14},
	{"name": "Waterside", "x": 22, "y": 34, "w": 16, "h": 14},
	{"name": "Lantern Square", "x": 33, "y": 15, "w": 16, "h": 14},
	{"name": "Warm Hearth Row", "x": 50, "y": 16, "w": 16, "h": 14},
	{"name": "Archive Quarter", "x": 4, "y": 12, "w": 20, "h": 14},
	{"name": "North Green", "x": 28, "y": 1, "w": 28, "h": 10},
	{"name": "Root Gate Road", "x": 56, "y": 36, "w": 22, "h": 16},
]
## A plausible table, as the player's map_colour could write it.
const HUD_COLOURS := {
	"grass": Color("#6fbf5b"), "flowers": Color("#ec8fb3"), "path": Color("#d8b878"), "cobble": Color("#a9a9b2"),
	"bridge": Color("#9a6a3a"), "floor": Color("#c99a68"), "rug": Color("#b5483f"), "water": Color("#4a90d9"),
	"hedge": Color("#2f7a45"), "wall": Color("#6f6f78"), "void": Color("#14110f"),
	"building": Color("#8a4f2c"), "tree": Color("#2f6b34"), "thing": Color("#e2c04f"),
}
const HUD_NAMES := {
	"grass": "green", "flowers": "pink", "path": "tan", "cobble": "grey", "bridge": "brown", "floor": "orange",
	"rug": "red", "water": "blue", "hedge": "dark green", "wall": "dark grey", "void": "black",
	"building": "brown", "tree": "dark green", "thing": "yellow",
}


func _ready() -> void:
	var moment := OS.get_environment("ROOTWARD_LANTERNTOWN")
	if moment == "":
		moment = "town"
	var base := moment.trim_suffix("-ja")
	Game.reset("user://overworld-shot-saves/" + moment)
	Game.boot()
	Game.profile.needs_name = false
	Game.profile.preferred_language = "ja" if moment.ends_with("-ja") else "en"
	var reading := OS.get_environment("ROOTWARD_LANTERNTOWN_READING")
	if reading in ["hiragana", "kanji"]:
		Game.profile.japanese_reading = reading
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	var store := OverworldStore.for_profile()
	store.delete_state()
	var flags := {"woke": true, "first-step": true, "all-ways": true, "left-home": true}
	var state := OverworldState.fresh("lanternroot", Vector2i(13, 45), "down", "python")
	state.look = LOOK
	state.name = "Tinker"
	state.flags = flags
	state.boots.blocks = FULL_BOOTS
	match base:
		"creator":
			state = OverworldState.fresh("home", Vector2i(2, 3), "down", "python")
		"wake":
			state = OverworldState.fresh("home", Vector2i(2, 3), "down", "python")
			state.look = LOOK
		"home", "boots", "code", "code-hints":
			state = OverworldState.moved(state, "home", Vector2i(4, 4), "down")
			state.boots.blocks = FULL_BOOTS.slice(0, 2)
			if base == "code" or base == "code-hints":
				state.boots.mode = "code"
				state.boots.code = {"python": BootsCode.source(FULL_BOOTS.slice(0, 3), "python")}
		"quest-details":
			state.boots.blocks = FULL_BOOTS.slice(0, 1)
			state.flags.erase("all-ways")
			state = OverworldState.moved(state, "home", Vector2i(4, 4), "down")
		"quest-journal":
			state = _with_parts(state, "progress")
			for flag: String in ["cabbage-gate-open", "met-innkeeper", "met-guildmaster", "met-pip", "met-guard", "met-pell", "met-archivist", "read-notices", "menu-asked", "menu-key-written", "menu-built", "menu-opened"]:
				state.flags[flag] = true
		"square", "bubble":
			state = OverworldState.moved(state, "lanternroot", Vector2i(43, 21), "up")
		"talk":
			state = OverworldState.moved(state, "lanternroot", Vector2i(48, 24), "right")
		"board":
			# The noticeboard is at (16, 11), two tiles wide: stand below its left half, facing it.
			state = OverworldState.moved(state, "lanternroot", Vector2i(43, 21), "up")
		"choice":
			# The innkeeper, Marta, stands at (32, 17).
			state = OverworldState.moved(state, "lanternroot", Vector2i(48, 24), "right")
		"thing-gate", "thing-gate-open":
			# The cabbage-plot gate (two tiles, 4..5 by 44): stand below its left tile, facing it. thing-gate-open has
			# the gate open in the state, and the answer that opened it kept.
			state = OverworldState.moved(state, "lanternroot", Vector2i(4, 45), "up")
			if base == "thing-gate-open":
				state = TownThings.with_changes(state, "cabbage-gate", {"open": true})
				state.flags["first-action"] = true
				state.flags["cabbage-gate-open"] = true
		"thing-sign":
			# The crossroads signpost, at (11, 20): stand below it, facing it.
			state = OverworldState.moved(state, "lanternroot", Vector2i(11, 21), "up")
		"studio":
			# The Inn (50..55 by 21..26) is a few tiles to the right of the lane.
			state = OverworldState.moved(state, "lanternroot", Vector2i(48, 24), "right")
		"tracker", "tracker-pips", "tracker-away", "tracker-hidden", "minimap", "minimap-grey", "fullmap", "log", "log-track":
			# The v0.4 HUD: in the square, ten tiles west of the Warm Hearth.
			state = OverworldState.moved(state, "lanternroot", Vector2i(43, 21), "up")
	# Any moment can be placed elsewhere, and given flags: ROOTWARD_LANTERNTOWN_MAP=home, ROOTWARD_LANTERNTOWN_AT=4,5,
	# ROOTWARD_LANTERNTOWN_FACING=up, ROOTWARD_LANTERNTOWN_FLAGS=met-innkeeper,read-notices.
	var place_map := OS.get_environment("ROOTWARD_LANTERNTOWN_MAP")
	var place_at := OS.get_environment("ROOTWARD_LANTERNTOWN_AT").split(",", false)
	if place_map != "" or place_at.size() == 2:
		var cell := Vector2i(int(place_at[0]), int(place_at[1])) if place_at.size() == 2 else OverworldState.cell(state)
		var facing := OS.get_environment("ROOTWARD_LANTERNTOWN_FACING")
		state = OverworldState.moved(state, place_map if place_map != "" else String(state.map), cell, facing)
	for flag in OS.get_environment("ROOTWARD_LANTERNTOWN_FLAGS").split(",", false):
		state.flags[flag.strip_edges()] = true
	# v0.4's parts, built for a picture from the test fixtures' reference programs (never in the game itself):
	# ROOTWARD_LANTERNTOWN_PARTS=all, or a comma list such as shortcuts,menu,map. Each gets every stage and its flags.
	state = _with_parts(state, OS.get_environment("ROOTWARD_LANTERNTOWN_PARTS"))
	var clock := OS.get_environment("ROOTWARD_LANTERNTOWN_CLOCK")
	if clock != "":
		state.clock = int(clock)
	var bag := OS.get_environment("ROOTWARD_LANTERNTOWN_BAG")
	for pair in bag.split(",", false):
		var bits := pair.split(":")
		(state.bag as Array).append({"item": bits[0], "count": int(bits[1]) if bits.size() > 1 else 1})
	var model := OS.get_environment("ROOTWARD_LANTERNTOWN_MODEL")
	if model in ["male", "female"] and base != "creator":
		state.look = {"model": model}
	store.save_state(state)
	if base.begins_with("studio"):
		# The toggle for this run only, before the overworld asks (StudioMode.available); settings stay untouched.
		OS.set_environment("ROOTWARD_STUDIO", "1")
		StudioMode.drafts_dir = "user://studio_shots/%s-%d/drafts" % [base, Time.get_ticks_usec()]
	var screen := (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate()
	add_child(screen)
	for i in 30:
		await get_tree().process_frame
	await _until_read(screen)
	await _play(screen, base)
	if base == "creator" and model in ["male", "female"]:
		var creator := screen.get("_creator") as CharacterCreator
		creator._choose_model(model)
		await _frames(2)
	# Any method of the screen, called once the moment is set up: ROOTWARD_LANTERNTOWN_CALL=_open_menu.
	var call := OS.get_environment("ROOTWARD_LANTERNTOWN_CALL")
	if call != "" and screen.has_method(call):
		screen.call(call)
		await _frames(20)
	var step := OS.get_environment("ROOTWARD_LANTERNTOWN_STEP")
	var player := screen.get("_player") as Walker
	if step in BootsRules.KEYS and player != null:
		player.walk_to(player.cell + BootsRules.STEPS[step], step)
		await _frames(maxi(0, int(OS.get_environment("ROOTWARD_LANTERNTOWN_STEP_FRAMES"))))
	shot_ready.emit()


## Sets the moment up on the screen: the boots open, or a talk is started and typed out as far as its picture needs.
func _play(screen: Node, base: String) -> void:
	var talk := screen.get("_talk") as DialogueBox
	match base:
		"quest-details":
			var tracker := screen.get("_tracker") as QuestTracker
			var card := tracker.get("_card") as Control
			var point := get_viewport().get_final_transform() * card.get_global_rect().get_center()
			var motion := InputEventMouseMotion.new()
			motion.position = point
			get_tree().root.push_input(motion)
			await _frames(2)
			for down: bool in [true, false]:
				var event := InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = down
				event.position = point
				get_tree().root.push_input(event)
				await _frames(2)
		"quest-journal":
			screen.call("_show_quest_log")
			(screen.get("_log") as QuestLog)._toggle_journal()
		"boots", "code", "code-hints":
			CodeHints.remembered_open = base == "code-hints"
			screen.call("_open_boots")
		"bubble":
			# Hotaru's remark, as a walk into a wall says it: the bubble in the overworld's style.
			screen.call("_hotaru_says", Text.t("Whoa! Boots only take one step at a time: change x or y by 1."))
		"talk", "board":
			screen.call("_interact")
			await _frames(40)
			_finish_typing(talk)
		"studio", "studio-plain", "studio-arrange", "studio-publish", "studio-problems", "studio-play-draft", "studio-browser", "studio-context", "studio-catalog", "studio-remake", "studio-land", "studio-area", "studio-doors", "studio-room", "studio-link", "studio-people", "studio-people-doors", "studio-debug", "studio-debug-events", "studio-thing", "studio-wires", "studio-quests", "studio-quests-flags", "studio-quests-talk":
			_edit(screen, base == "studio")
			var studio := screen.get("_studio") as StudioMode
			if base in ["studio-arrange", "studio-publish", "studio-play-draft"]:
				_arrange(studio)
			if base == "studio-publish":
				studio.publish_tools.open_publish()
			elif base == "studio-problems":
				studio.work.command({"type": "add", "object": {"kind": "warp", "at": [44, 22], "to": {"map": "missing-interior", "at": [1, 1]}}})
				studio.publish_tools.open_problems()
			elif base == "studio-play-draft":
				studio.set_play_draft(true)
				studio.set_editing(false)
			elif base in ["studio-browser", "studio-context"]:
				await _browser(studio, base == "studio-context")
			elif base == "studio-catalog":
				await _catalog(studio)
			elif base == "studio-remake":
				await _remake(studio)
			elif base == "studio-land":
				await _land(studio)
			elif base == "studio-area":
				studio.open_new_area()
			elif base in ["studio-doors", "studio-room", "studio-link", "studio-people", "studio-people-doors"]:
				await _doors(studio, base)
			elif base in ["studio-debug", "studio-debug-events"]:
				await _debug(studio, base == "studio-debug-events")
			elif base in ["studio-thing", "studio-wires"]:
				await _things(studio, base == "studio-wires")
			elif base.begins_with("studio-quests"):
				await _quests(studio, base)
		"choice":
			# Marta's first line is typed out and passed on, then her second line, and her choices show.
			screen.call("_interact")
			await _frames(40)
			_finish_typing(talk)
			talk.advance()
			await _frames(40)
			_finish_typing(talk)
		"tracker", "tracker-pips", "tracker-away", "tracker-hidden", "minimap", "minimap-grey", "fullmap", "log", "log-track":
			await _hud(screen, base)
		"pocket-menu", "menu-built", "options", "music", "bag", "credits":
			await _menus(screen, base)
	await _frames(10)
	if base.begins_with("studio") and OS.get_environment("ROOTWARD_STUDIO_BENCH") == "1":
		await _bench_frames(screen.get("_studio") as StudioMode)


## The v0.4 menus and panels (the menus worker), each fed stand-in answers as the player's parts will give them:
## `pocket-menu` Hotaru's stand-in menu; `menu-built` the real menu with bag, map, music and options; `options` the
## Options page with a squared volume curve; `music` the Music panel; `bag` the Bag with a few stacks; `credits` the roll.
func _menus(screen: Node, base: String) -> void:
	match base:
		"pocket-menu":
			var pocket := PocketMenu.new()
			add_child(pocket)
			await _frames(2)
			pocket.open({"can_save": false, "note": ""})
		"menu-built":
			var menu := screen.get("_menu") as PauseMenu
			var items: Array[String] = ["continue", "quests", "workbench", "bag", "map", "music", "options", "save", "settings", "characters", "title", "quit"]
			menu.open(PauseMenu.about(screen.get("state"), screen.get("catalog"), {"items": items, "place": "Lantern Square", "clock": "18:40 · evening"}))
		"options":
			var page := OptionsPage.new()
			add_child(page)
			await _frames(2)
			var rows: Array[Dictionary] = [
				{"setting": "music", "label": "Songs"},
				{"setting": "sound", "label": "Boom volume"},
				{"setting": "text_speed", "label": "Talking"},
				{"setting": "track", "label": "Tune"},
				{"setting": "fullscreen", "label": "Big window"},
			]
			var curve := PackedFloat32Array()
			for notch in 11:
				curve.append(pow(notch / 10.0, 2.0))
			page.open(rows, {"music": 7, "sound": 5, "text_speed": "normal", "track": "Lanternroot", "fullscreen": false},
				func(notch: int) -> float: return pow(notch / 10.0, 2.0), curve)
		"music":
			var panel := MusicPanel.new()
			add_child(panel)
			await _frames(2)
			var titles: Array[String] = ["Lanternroot", "The Warm Hearth", "Study Hour", "Night at the Root", "The Front Gate", "Heap", "Kernel", "Rest"]
			var ids: Array[String] = ["music-lanternroot-town", "music-lanternroot-home", "music-lanternroot-lesson", "music-title", "music-lanternroot-front", "music-heap", "music-kernel", "music-rest"]
			panel.open(titles, ids, "music-lanternroot-home", "music-title", func(index: int, count: int) -> int: return (index + 1) % count)
		"bag":
			var bag := BagPanel.new()
			add_child(bag)
			await _frames(2)
			var items := {
				"apple": {"name": "Apple", "about": "Crisp and red. Marta says they're best in pie.", "icon": "item-apple", "colour": "cloth_red"},
				"cabbage": {"name": "Cabbage", "about": "Heavy and green. Marta wants three.", "icon": "item-cabbage", "colour": "leaf"},
				"honey": {"name": "Honey", "about": "Golden, from the hive by the gate.", "icon": "item-honey", "colour": "cloth_yellow"},
				"pebble": {"name": "Pebble", "about": "Smooth and grey.", "icon": "item-pebble", "colour": "stone"},
				"key": {"name": "Key", "about": "It opens something.", "icon": "item-key", "colour": "gold"},
				"berries": {"name": "Berries", "about": "Small, sweet and blue.", "icon": "item-berries", "colour": "cloth_blue"},
			}
			var stacks: Array = [
				{"item": "apple", "count": 5}, {"item": "cabbage", "count": 3}, {"item": "honey", "count": 1},
				{"item": "pebble", "count": 12}, {"item": "key", "count": 1}, {"item": "berries", "count": 7},
			]
			bag.open(stacks, items)
			bag.call("_select", 1)
		"credits":
			var credits := CreditsRoll.new()
			add_child(credits)
			await _frames(2)
			var lines: Array[String] = ["Lanternroot", "", "Made by Kai", "", "Boots", "Save", "Lamps", "Shortcuts", "Menu", "Bag", "", "Thank you for playing"]
			credits.roll(lines, "Kai")


## The v0.4 HUD (Concept/v0.4/01 section 9), fed the way the town will feed it, with stand-in parts: `tracker` is the card
## with the bar at 50 % (progress built), the count, and the arrow with its distance and place; `tracker-pips` the same
## before progress is built; `tracker-away` a pin in the house; `tracker-hidden` after H; `minimap` the card with the minimap
## under it in a plausible colour table, `minimap-grey` in the stand-in greys; `fullmap` the whole map with its names and
## legend; `log` the quest log with its Track button and star.
func _hud(screen: Node, base: String) -> void:
	var tracker := screen.get("_tracker") as QuestTracker
	var catalog: Dictionary = screen.get("catalog")
	var quests: Dictionary = HUD_QUESTS.duplicate(true)
	if base == "tracker-away":
		quests.keys.steps[2].at = {"map": "home", "at": [4, 4]}
	var flags := HUD_FLAGS.duplicate()
	var town: Dictionary = catalog.maps.lanternroot
	var cell := Vector2i(43, 21)
	tracker.setup(catalog)
	if base != "tracker-pips":
		tracker.set_parts(func(done: int, total: int) -> int: return done * 100 / maxi(total, 1), _place_of)
	else:
		tracker.set_parts(Callable(), _place_of)
	tracker.set_tracked("keys")
	tracker.locate("lanternroot", cell)
	var catalog_quests: Dictionary = catalog.quests.duplicate()
	catalog_quests.merge(quests)
	if base.begins_with("log"):
		# `log-track` follows the first quest, so "A key for every door" shows its Track button.
		var log_view := screen.get("_log") as QuestLog
		var entries := Quests.entries(catalog_quests, state_flags(screen))
		log_view.open(entries, catalog.townsfolk, "keys", "boots" if base == "log-track" else "keys")
		return
	tracker.follow(catalog_quests, flags)
	var people: Array[Vector2i] = []
	for object: Dictionary in town.objects:
		if String(object.kind) == "person":
			people.append(OverworldMap.cell_of(object.at))
	var minimap := tracker.minimap()
	minimap.show_map(town, {} if base == "minimap-grey" else HUD_COLOURS)
	minimap.set_people(people)
	tracker.set_clock("18:40")
	if base in ["minimap", "minimap-grey", "tracker", "tracker-pips", "tracker-away", "tracker-hidden"]:
		minimap.set_enabled(base != "tracker-hidden" and base != "tracker-pips")
	for i in 400:
		if not bool(tracker.get("_busy")):
			break
		await get_tree().process_frame
	if base == "tracker-hidden":
		tracker.toggle_hidden()
		await _frames(30)
	if base == "fullmap":
		var full := FullMap.new()
		add_child(full)
		await _frames(2)
		full.set_colour_names(HUD_NAMES)
		full.open(town, HUD_COLOURS, HUD_PLACES, cell, people, Vector2i(53, 26))
	await _frames(20)


static func state_flags(screen: Node) -> Dictionary:
	return (screen.get("state") as Dictionary).flags


## The shot's stand-in for the player's place_at: the district rectangle a cell is in, or "".
func _place_of(map_id: String, cell: Vector2i) -> String:
	if map_id != "lanternroot":
		return ""
	for place: Dictionary in HUD_PLACES:
		if cell.x >= int(place.x) and cell.x < int(place.x) + int(place.w) and cell.y >= int(place.y) and cell.y < int(place.y) + int(place.h):
			return String(place.name)
	return ""


## The catalog on Street / Fences and gates while a row of fences is Shift-dragged across the square (held, not put
## down): the fence card marked as the one being placed, and a ghost per piece, red where one does not fit.
func _catalog(studio: StudioMode) -> void:
	var from := Vector2(39, 24)
	studio.focus((from + Vector2(5.5, 0.5)) * OverworldScale.TILE)
	studio.place_panel().set_filters({"category": "street", "subcategory": "fences_and_gates"})
	studio.start_place("fence")
	await _frames(3)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.shift_pressed = true
	press.position = _catcher_point(studio, from)
	studio._world_input(press)
	var motion := InputEventMouseMotion.new()
	motion.shift_pressed = true
	motion.position = _catcher_point(studio, from + Vector2(11, 0))
	studio._world_input(motion)


## A barrel by the square remade at 2 x 1 in the shot's own drafts: the barrel's picture stretched as a placeholder,
## hatched, with its footprint handles, and Run remakes (1) in the tools column. Nothing is run.
func _remake(studio: StudioMode) -> void:
	# The first barrel with room to its right, so the remake fits without forcing it.
	for index: int in (studio.work.doc().data.objects as Array).size():
		if String(studio.work.raw(index).get("art", "")) == "barrel":
			var sid := studio.work.sid_at(index)
			if not bool(studio.remaking.remake(sid, Vector2i(2, 1)).get("ok", false)):
				continue
			studio.focus((Vector2(OverworldMap.cell_of(studio.work.raw(index).at)) + Vector2(1.0, 0.5)) * OverworldScale.TILE)
			studio.select_sids([sid])
			break
	await _frames(3)


## The Land tab: a 5-wide cobble road painted through the open grass east of the square (in the shot's own drafts),
## the brush hovering beside it in path.
func _land(studio: StudioMode) -> void:
	studio.set_tab("land")
	studio.set_ground("cobble")
	studio.set_brush(5)
	studio.work.paint(StudioLand.stroke(Vector2i(49, 46), Vector2i(67, 46), 5), "cobble")
	studio.set_ground("path")
	studio.set_brush(3)
	studio.focus(Vector2(58, 46) * OverworldScale.TILE)
	await _frames(3)
	var motion := InputEventMouseMotion.new()
	var catcher := studio.get_node("Chrome/World") as Control
	motion.position = catcher.get_global_transform() * _catcher_point(studio, Vector2(61, 50))
	motion.global_position = motion.position
	get_tree().root.push_input(motion, true)
	await _frames(3)


## People, doors and rooms (S6), in drafts only: `studio-doors` selects Pell's cottage (its door handle, and the
## inspector's Link door and Make interior); `studio-room` makes its room and furnishes it; `studio-link` links the
## cottage's door to a cell of the player's room, with the facing menu open; `studio-people` the catalog's people with
## Marta selected. ROOTWARD_SHOT_PROBLEMS=1 opens the problems list over `studio-room`.
func _doors(studio: StudioMode, base: String) -> void:
	for option: String in ["doors", "labels", "grid"]:
		studio.set_overlay(option, true)
	var pell := -1
	for object: Dictionary in studio.current_map().objects:
		if String(object.get("art", "")) == "cottage-pell":
			pell = studio.work.sid_at(int(object.index))
			studio.focus((Vector2(object.at) + Vector2(2.5, 3.0)) * OverworldScale.TILE)
	match base:
		"studio-doors":
			studio.select_sids([pell])
		"studio-room":
			studio.make_interior(pell)
			for placed: Array in [["bed", Vector2i(1, 3)], ["bookshelf", Vector2i(4, 2)], ["desk", Vector2i(8, 2)],
					["chair", Vector2i(6, 2)], ["plant", Vector2i(10, 2)], ["rug", Vector2i(5, 5)], ["window", Vector2i(2, 1)],
					["window", Vector2i(8, 1)]]:
				studio.work.place(StudioAssets.template(String(placed[0])), placed[1], true)
			studio.select(-1)
			if OS.get_environment("ROOTWARD_SHOT_PROBLEMS") == "1":
				studio.publish_tools.open_problems()
		"studio-link":
			studio.link_door(pell)
			studio.go_to_map("home")
			await _frames(3)
			var catcher := studio.get_node("Chrome/World") as Control
			var motion := InputEventMouseMotion.new()
			motion.position = catcher.get_global_transform() * _catcher_point(studio, Vector2(3, 4))
			motion.global_position = motion.position
			get_tree().root.push_input(motion, true)
			await _frames(3)
			studio.link.click(Vector2i(3, 4), catcher.get_screen_transform() * _catcher_point(studio, Vector2(3, 4)))
		"studio-people-doors":
			studio.set_tab("people")
			studio.people_panel().choose_view("people")
			await _frames(4)
		"studio-people":
			studio.place_panel().set_filters({"category": "people"})
			for object: Dictionary in studio.current_map().objects:
				if String(object.get("id", "")) == "innkeeper":
					studio.select(int(object.index))
					studio.focus((Vector2(object.at) + Vector2(0.5, 0.0)) * OverworldScale.TILE)
	await _frames(4)


## Things that take code (S8), in drafts only: `studio-thing` is Make it a thing open over a barrel by the inn;
## `studio-wires` a plate (the stone step, on_step) wired to a gate (on_change), with plates and wires shown.
func _things(studio: StudioMode, wires: bool) -> void:
	studio.set_overlay("talk", true)
	var near := Vector2i(54, 30)
	if wires:
		var plate := {"kind": "prop", "art": "step", "id": "shot-plate", "at": [near.x, near.y], "solid": false, "draw_layer": "ground",
			"program": {"hook": "on_step", "fields": {"pressed": {"type": "bool", "default": false}}, "links": ["shot-gate"]}}
		var gate := {"kind": "prop", "art": "gate", "id": "shot-gate", "at": [near.x + 4, near.y], "size": [2, 1], "solid_unless": "open",
			"program": {"hook": "on_change", "fields": {"open": {"type": "bool", "default": false}}}}
		studio.work.command({"type": "batch", "name": "Wire a plate to a gate", "commands": [
			{"type": "add", "object": plate, "index": -1}, {"type": "add", "object": gate, "index": -1}]})
		studio.focus(Vector2(near.x + 3, near.y) * OverworldScale.TILE)
	else:
		for object: Dictionary in studio.current_map().objects:
			if String(object.get("art", "")) == "barrel" and not object.has("program"):
				studio.select(int(object.index))
				studio.focus(Vector2(object.at) * OverworldScale.TILE)
				studio.thing_dialog.open(studio.work.sid_at(int(object.index)))
				studio.thing_dialog.set_part("unlock", "met-innkeeper")
				break
	await _frames(4)


## The quest editor (S9): `studio-quests` is the Quests view on "Hello, Lanternroot" with a step added (pinned at the
## Inn's door), `studio-quests-flags` the flag browser, `studio-quests-talk` Pip's first node with a flag added.
func _quests(studio: StudioMode, base: String) -> void:
	studio.set_tab("quests")
	await _frames(2)
	var panel := studio.quest_panel
	if base == "studio-quests-talk":
		panel.show_talk("pip", "hello")
		await _frames(2)
		panel.talk_editor.add_set("waved-at-pip")
	elif base == "studio-quests-flags":
		panel.quest_list.choose("hello")
		panel.quest_list.add_step({"text": "Wave to Pip, who is counting lanterns.", "done": {"flag": "waved-at-pip"}})
		panel.show_sub("flags")
	else:
		panel.quest_list.choose("hello")
		panel.quest_list.add_step({"text": "Wave to Pip, who is counting lanterns.", "done": {"all": [{"flag": "waved-at-pip"}, {"not": "pip-annoyed"}]}, "at": {"map": "lanternroot", "at": [36, 34]}})
	await _frames(6)


## The developer inspector (S7) in Play, on the play-test state: the main quest jumped to "Light the lane", the player on
## the lane (its lamps dark), a flag poked; `studio-debug-events` shows the Events tab.
func _debug(studio: StudioMode, events: bool) -> void:
	studio.set_editing(false)
	await _frames(2)
	studio.set_play_draft(true)
	await _frames(2)
	studio.toggle_debug()
	await _frames(2)
	studio.debug.jump_to("lamps")
	(studio.parts().teleport as Callable).call("lanternroot", Vector2i(47, 17))
	await _frames(4)
	studio.debug.set_flag("shot-poked")
	if events:
		studio.debug.show_tab("events")
	await _frames(6)


## A cell's middle as a point on the Studio's world Control.
func _catcher_point(studio: StudioMode, cell: Vector2) -> Vector2:
	var view := studio.pixel_view()
	var catcher := studio.get_node("Chrome/World") as Control
	var point := (cell + Vector2(0.5, 0.5)) * OverworldScale.TILE
	return catcher.get_global_transform().affine_inverse() * (view.get_global_transform() * view.to_screen(point))


## The compact asset browser and a right-click menu over a placed instance, without changing its draft.
func _browser(studio: StudioMode, context: bool) -> void:
	var art := "noticeboard" if context else "flowerpot"
	var point := Vector2(45, 22) * OverworldScale.TILE
	for object: Dictionary in studio.current_map().objects:
		if String(object.get("art", "")) == art:
			studio.select(int(object.index))
			point = (Vector2(object.at) + Vector2(0.5, 0.5)) * OverworldScale.TILE
			break
	studio.focus(point)
	studio.place_panel().set_filters({
		"category": "street" if context else "nature",
		"subcategory": "signs_and_boards" if context else "bushes_and_flowers",
		"place": "outdoor", "kind": "prop",
	})
	studio.place_panel().preview_asset("noticeboard" if context else "bush")
	await _frames(3)
	if context:
		var view := studio.pixel_view()
		var catcher := studio.get_node("Chrome/World") as Control
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = true
		event.position = catcher.get_global_transform().affine_inverse() * (view.get_global_transform() * view.to_screen(point))
		studio._world_input(event)


func _arrange(studio: StudioMode) -> void:
	for art: String in ["noticeboard", "bench", "oak"]:
		for index: int in (studio.work.doc().data.objects as Array).size():
			var object := studio.work.raw(index)
			if String(object.get("art", "")) != art:
				continue
			var sid := studio.work.sid_at(index)
			match art:
				"noticeboard":
					studio.work.move([sid], Vector2i(3, 0))
					studio.select_sids([sid])
				"bench":
					studio.work.delete([sid])
				"oak":
					studio.work.flip([sid])
			break
	var added := 0
	for y: int in range(21, 29):
		for x: int in range(40, 49):
			var cell := Vector2i(x, y)
			if added < 2 and not OverworldMap.blocked(studio.current_map(), cell) and studio.pick().objects_at_cell(cell).is_empty():
				if studio.work.place(StudioAssets.template("barrel"), cell).ok:
					added += 1
	studio.focus(Vector2(46, 21) * OverworldScale.TILE)
	studio.publish_tools.refresh_now()


## A rendered pan/ghost measurement, separate from the headless picking benchmark.
func _bench_frames(studio: StudioMode) -> void:
	if not studio.editing:
		return
	studio.select(-1)
	studio.publish_tools.refresh_now()
	var cell := Vector2i(45, 22)
	studio.arrange.start_placing(StudioAssets.template("barrel"))
	var samples: Array[int] = []
	var previous := Time.get_ticks_usec()
	for frame: int in 240:
		studio.studio_camera().pan(Vector2(1 if frame < 120 else -1, 0))
		studio.studio_camera().apply()
		var point := (Vector2(cell + Vector2i(frame % 5, 0)) + Vector2(0.5, 0.5)) * OverworldScale.TILE
		var view := studio.pixel_view()
		var catcher := studio.get_node("Chrome/World") as Control
		studio._set_cursor(catcher.get_global_transform().affine_inverse() * (view.get_global_transform() * view.to_screen(point)))
		studio.arrange.update()
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		if frame > 30:
			samples.append(now - previous)
		previous = now
	studio.arrange.stop_placing()
	samples.sort()
	var total := 0
	for sample: int in samples:
		total += sample
	print("STUDIO_RENDER_BENCH frames=%d mean_us=%d p95_us=%d max_us=%d fps=%.1f" % [samples.size(), total / samples.size(), samples[int(samples.size() * 0.95)], samples.back(), 1000000.0 * samples.size() / total])


## Presses F2: the town in Edit. With `overlays` the grid, footprints, solid cells and doors are on and the Inn is
## selected; without, every overlay is off and nothing is selected.
func _edit(screen: Node, overlays: bool) -> void:
	var studio := screen.get("_studio") as StudioMode
	if studio == null:
		push_error("the Studio is not mounted: is the repository's content folder writable?")
		return
	studio.set_editing(true)
	for option in StudioTools.OVERLAYS:
		studio.set_overlay(option, overlays and option in ["grid", "footprints", "solid", "doors", "player"])
	if OS.get_environment("ROOTWARD_STUDIO_OVERVIEW") == "1":
		studio.studio_camera().toggle_overview()
	if overlays:
		for object: Dictionary in studio.current_map().objects:
			if String(object.get("art", "")) == "inn":
				studio.select(int(object.index))
				if not studio.studio_camera().overview:
					studio.focus((Vector2(object.at) + Vector2(object.size) / 2.0) * OverworldScale.TILE)
				break


## Types out the rest of the line on screen, as Space does, if it is still being typed. It looks at the words, not the
## clock, so a slow frame cannot carry the talk past a line.
func _finish_typing(talk: DialogueBox) -> void:
	var words := talk.get("_text") as RichTextLabel
	if words.visible_characters != -1:
		talk.advance()


## Waits, for at most ten seconds, until the screen has read its boots, so Hotaru's reading remark is gone from the
## picture.
func _until_read(screen: Node) -> void:
	for i in 600:
		if not bool(screen.get("_reading")):
			return
		await get_tree().process_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## The state with parts built from the reference programs in test/fixtures/tasks (for pictures only).
func _with_parts(state: Dictionary, which: String) -> Dictionary:
	if which == "":
		return state
	var catalog: Dictionary = OverworldContent.load_world().catalog
	var ids: Array[String] = []
	if which == "all":
		ids = Parts.IDS.duplicate()
	else:
		for id in which.split(",", false):
			ids.append(id.strip_edges())
	var out := state
	# A picture with the save lesson done needs a saved place, or Continue wakes the player at home (Lessons.restore).
	out.memory = {"x": int(out.cell[0]), "y": int(out.cell[1]), "map": String(out.map), "facing": String(out.facing)}
	for id in ids:
		var task: Dictionary = catalog.tasks.get(id, {})
		var path := "res://test/fixtures/tasks/%s.py" % id
		if task.is_empty() or not FileAccess.file_exists(path):
			continue
		var last := Tasks.stage_count(task) - 1
		out = Parts.with_record(out, id, Parts.passed_record({}, last, FileAccess.get_file_as_string(path), "python"))
		for s in Tasks.stage_count(task):
			out.flags[String(Tasks.stage(task, s).flag)] = true
	return out
