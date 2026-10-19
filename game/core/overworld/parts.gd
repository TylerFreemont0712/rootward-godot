class_name Parts
extends RefCounted
## The parts of the game the player builds (Concept/v0.4/01): which are built, the records the state keeps, and the
## inputs each part's table is made over. Pure: the overworld's PartsRuntime runs the code; this says what to run it on
## and what the answers may be.
##
##   Parts.built(state, "menu")          # stage 1 of the menu task has passed
##   Parts.menu_built(state)             # what menu_items(built) is given now
##   Parts.facts(state)                  # the flags plus "bag:<item>" counts, for Talk and Quests conditions
##   Parts.domain("volume", 0, catalog)  # [[-3], [-2], ... [14]]: every notch the volume table answers
##
## A part's id is its task's id. Its record is state.tasks[id] (Concept/v0.4/02, section 7): the blocks, the code
## typed, the stages passed, and `source`, the last program that passed, which is the one the game runs.

const SHORTCUTS := "shortcuts"
const MENU := "menu"
const OPTIONS := "options"
const VOLUME := "volume"
const MUSIC := "music"
const BAG := "bag"
const MAP := "map"
const PROGRESS := "progress"
const CLOCK := "clock"
const CREDITS := "credits"
# Chapter 3 (Concept/v0.4/05): the town comes alive.
const COUNT := "count"
const GLOW := "glow"
const DRILLS := "drills"
const LOCKS := "locks"
const FORGE := "forge"
const STONES := "stones"
const WEATHER := "weather"
const HOURS := "hours"
const SHOP := "shop"
const TIDY := "tidy"
const HISTORY := "history"
const IDS: Array[String] = [
	SHORTCUTS, MENU, OPTIONS, VOLUME, MUSIC, BAG, MAP, PROGRESS, CLOCK, CREDITS,
	COUNT, GLOW, DRILLS, LOCKS, FORGE, STONES, WEATHER, HOURS, SHOP, TIDY, HISTORY,
]
## The glow table's seconds, the weather's days (it repeats), and the hours of a day.
const GLOW_SECONDS := 60
const WEATHER_DAYS := 28
const HOURS_IN_DAY := 24
## What the weather may be, and where a person may be.
const WEATHERS: Array[String] = ["sun", "rain", "cloud"]
const SPOTS: Array[String] = ["home", "work", "inn"]
## How many passing programs a task's record keeps (the changelog's versions).
const VERSIONS := 5
## The lessons that came before the parts, shown on the Workbench beside them: their own editors, and the flag that
## says each is built.
const BUILT_BEFORE := {"boots": "all-ways", "save": "memory-written", "lamps": "lamps-lit"}

## The keys the player's shortcut(key) is asked about. The keys the town needs are never asked (RESERVED_KEYS).
const SHORTCUT_KEYS: Array[String] = [
	"escape", "c", "f", "g", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "t", "u", "v", "y",
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
]
const RESERVED_KEYS: Array[String] = [
	"up", "down", "left", "right", "w", "a", "s", "d", "space", "enter", "e", "z", "b", "x", "tab", "h",
]
## What a shortcut may open.
const PANELS: Array[String] = ["menu", "bag", "map", "quests", "workbench", "options", "music"]
## What a menu may hold. continue comes first and quit last; the rest are the town's to offer (menu_built).
const MENU_ITEMS: Array[String] = [
	"continue", "quests", "workbench", "bag", "map", "music", "options", "save", "settings", "characters", "title",
	"credits", "quit",
]
## The rows the player's options() may list.
const SETTINGS: Array[String] = ["music", "sound", "text_speed", "track", "fullscreen"]
## The colours map_colour(ground) may give, each drawn as a colour of the palette (pipeline/pixel/palette.json).
const MAP_COLOURS := {
	"green": Color("#62a050"),
	"dark green": Color("#3e6e40"),
	"light green": Color("#9ad06e"),
	"blue": Color("#4a78c6"),
	"light blue": Color("#86c0f0"),
	"brown": Color("#8e5c3c"),
	"tan": Color("#dcc092"),
	"grey": Color("#82808f"),
	"dark grey": Color("#57546a"),
	"white": Color("#fbf7ee"),
	"yellow": Color("#e2b448"),
	"orange": Color("#d97a3c"),
	"red": Color("#c84a4a"),
	"pink": Color("#d6749e"),
	"purple": Color("#8460b8"),
	"black": Color("#24212f"),
}
## What a minimap cell can be beside the terrain's grounds: something solid drawn by its kind.
const GROUNDS_EXTRA: Array[String] = ["building", "tree", "thing"]
## The volume table's notches: the Options page's 0 to 10, and past the ends for stage 2.
const NOTCH_LOW := -3
const NOTCH_HIGH := 14
## The music box's next_track table: up to this many tracks.
const MOST_TRACKS := 32
## Pip's progress table: quests of up to this many steps.
const MOST_STEPS := 12
const DAY_MINUTES := 1440

# --- records -------------------------------------------------------------------------------------------------------


static func record(state: Dictionary, id: String) -> Dictionary:
	var tasks: Variant = state.get("tasks", {})
	if not tasks is Dictionary:
		return {}
	var kept: Variant = (tasks as Dictionary).get(id, {})
	return kept if kept is Dictionary else {}


## How many of the task's stages have passed.
static func passed(state: Dictionary, id: String) -> int:
	return int(record(state, id).get("passed", 0))


## Whether the part is built: its first stage has passed and its passing program is kept.
static func built(state: Dictionary, id: String) -> bool:
	var kept := record(state, id)
	return int(kept.get("passed", 0)) >= 1 and String(kept.get("source", "")).strip_edges() != ""


## The state with `id`'s record replaced.
static func with_record(state: Dictionary, id: String, kept: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	if not out.get("tasks") is Dictionary:
		out["tasks"] = {}
	out.tasks[id] = kept.duplicate(true)
	return out


## The program the game runs for a part: {source, language}, or {} when it is not built.
static func program(state: Dictionary, id: String) -> Dictionary:
	if not built(state, id):
		return {}
	var kept := record(state, id)
	return {"source": String(kept.source), "language": String(kept.get("source_language", kept.get("language", Tasks.PYTHON)))}


## A record after stage `index` passed with `source` in `language`: `passed` grows, the program is kept, and the last
## few passing programs are kept as versions (oldest first; a pass with the same code adds none).
static func passed_record(kept: Dictionary, index: int, source: String, language: String) -> Dictionary:
	var out := kept.duplicate(true)
	out.passed = maxi(int(out.get("passed", 0)), index + 1)
	out.source = source
	out.source_language = language
	var versions: Array = (out.get("versions", []) as Array).duplicate() if out.get("versions") is Array else []
	if versions.is_empty() or String(versions[-1]) != source:
		versions.append(source)
	while versions.size() > VERSIONS:
		versions.pop_front()
	out.versions = versions
	return out


# --- what the game asks the parts ----------------------------------------------------------------------------------


## What the player's menu_items(built) is given: the items the town can show now, in the town's own order. The
## workbench, the save (locked until lesson 2), the settings, the characters and the title are always offered; the
## bag, the map, the music box, the options and the credits once their parts are built.
static func menu_built(state: Dictionary) -> Array[String]:
	var out: Array[String] = ["quests", "workbench"]
	for part: String in [BAG, MAP, MUSIC, OPTIONS]:
		if built(state, part):
			out.append(part)
	out.append_array(["save", "settings", "characters", "title"])
	if built(state, CREDITS) and bool((state.get("flags", {}) as Dictionary).get("credits-rolled", false)):
		out.append("credits")
	return out


## The menu the town shows when the player's own cannot be used (not built, or broken for this list).
static func town_menu(built_items: Array[String]) -> Array[String]:
	var out: Array[String] = ["continue"]
	out.append_array(built_items)
	out.append("quit")
	return out


## What conditions see: the saved flags, and the bag's counts as "bag:<item>" (Talk.BAG_FACT). Never saved.
# LEARN: the town counts the bag itself (never with the player's code) and hands the counts to conditions as facts
# beside the flags; without_facts takes them out again before anything is saved.
static func facts(state: Dictionary) -> Dictionary:
	var out: Dictionary = (state.get("flags", {}) as Dictionary).duplicate() if state.get("flags", {}) is Dictionary else {}
	var counts := Bag.counts(state.get("bag", []))
	for item: String in counts:
		out[Talk.BAG_FACT + item] = counts[item]
	return out


## The flags without any facts (what a save may keep).
static func without_facts(flags: Dictionary) -> Dictionary:
	var out := {}
	for key: String in flags:
		if not key.begins_with(Talk.BAG_FACT):
			out[key] = flags[key]
	return out


# --- tables --------------------------------------------------------------------------------------------------------


## The argument lists a part's stage `index` is asked for its table: every key, every notch, every ground, every
## minute... `catalog` gives the terrain (map), `map` the cells (map stage 1, one map at a time), `places` the map's
## places. [] for a part that has no table (the menu, the bag and the credits are called live).
static func domain(part: String, index: int, catalog: Dictionary, map: Dictionary = {}, places: Array = []) -> Array:
	var out: Array = []
	match part:
		SHORTCUTS:
			for key in SHORTCUT_KEYS:
				out.append([key])
		OPTIONS:
			out.append([])
		VOLUME:
			for notch in range(NOTCH_LOW, NOTCH_HIGH + 1):
				out.append([notch])
		MUSIC:
			if index >= 1:
				for count in range(1, MOST_TRACKS + 1):
					for at in count:
						out.append([at, count])
		MAP:
			if index == 0:
				for ground in grounds(catalog):
					out.append([ground])
			else:
				var size := OverworldMap.size_of(map) if not map.is_empty() else Vector2i.ZERO
				for y in size.y:
					for x in size.x:
						out.append([x, y, places])
		PROGRESS:
			for total in range(0, MOST_STEPS + 1):
				for done in range(0, total + 1):
					out.append([done, total])
		CLOCK:
			for minute in DAY_MINUTES:
				out.append([minute])
		GLOW:
			for t in GLOW_SECONDS:
				out.append([t])
		WEATHER:
			for day in WEATHER_DAYS:
				out.append([day])
		HOURS:
			var people: Array = (catalog.get("schedules", {}) as Dictionary).keys()
			people.sort()
			for person: Variant in people:
				for hour in HOURS_IN_DAY:
					out.append([String(person), hour])
	return out


## Every ground a minimap cell can be: the terrain's ids in order, then building, tree and thing.
static func grounds(catalog: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var terrain: Dictionary = catalog.get("terrain", {}) if catalog.get("terrain", {}) is Dictionary else {}
	for id: String in terrain:
		out.append(id)
	out.append_array(GROUNDS_EXTRA)
	return out


## A colour's name as the map draws it; null when the name is not one of MAP_COLOURS.
static func colour_of(name: Variant) -> Variant:
	if not name is String:
		return null
	var key := String(name).strip_edges().to_lower()
	return MAP_COLOURS.get(key)
