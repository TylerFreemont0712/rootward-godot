extends Control
## Repeatable captures of Lanternroot (ADR-0055), each in its own save folder:
##   ROOTWARD_LANTERN=<moment> scripts/screenshot.sh res://tools/lanternroot_shot.tscn shots/lantern.png 20
## Moments: welcome, town, letter, fail, wrong, lit, town2, night, gremlin, gremlin-town, festival; add "-ja" for
## Japanese. ROOTWARD_SHOT_LANGUAGE=javascript plays the JavaScript town.

signal shot_ready

const WRONG := {
	"python": "def loaves_for(guests):\n    print(guests / 4)\n    return guests // 4\n",
	"javascript":
	(
		"function loavesFor(guests) {\n  console.log(guests / 4);\n"
		+ "  return Math.floor(guests / 4);\n}\n\nmodule.exports.loavesFor = loavesFor;\n"
	),
}
## A change to the bakery that forgets the default: the market's call with one argument breaks.
const NO_DEFAULT := {
	"python": "def loaves_for(guests, per_loaf):\n    return -(-guests // per_loaf)\n",
	"javascript":
	(
		"function loavesFor(guests, perLoaf) {\n  return Math.ceil(guests / perLoaf);\n}\n\n"
		+ "module.exports.loavesFor = loavesFor;\n"
	),
}


func _ready() -> void:
	var moment := OS.get_environment("ROOTWARD_LANTERN")
	moment = moment if moment != "" else "town"
	var language := OS.get_environment("ROOTWARD_SHOT_LANGUAGE")
	language = language if language in LanternRules.LANGUAGES else "python"
	Game.reset("user://lantern-shot-saves/%s-%s" % [moment, language])
	Game.boot()
	Game.profile.name = "Mira"
	Game.profile.needs_name = false
	Game.profile.preferred_language = "ja" if moment.ends_with("-ja") else "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	LanternStore.for_profile().delete_town(language)
	Settings.language = language
	Settings.reduced_motion = moment.trim_suffix("-ja") != "night"
	var base := moment.trim_suffix("-ja")
	if base != "welcome":
		_seed(base, language)
	var screen := (load(Game.LANTERNROOT) as PackedScene).instantiate() as LanternrootScreen
	add_child(screen)
	for i in 3:
		await get_tree().process_frame
	await _play(screen, base, language)
	shot_ready.emit()


## A saved town to start the moment from.
func _seed(base: String, language: String) -> void:
	var catalog := LanternrootScreen.catalog_of()
	var town := LanternRules.new_town(language)
	match base:
		"town2", "night":
			town = LanternReference.town(catalog, language, 6)
			town.day = 2
			town = LanternRules.open_letter(catalog, town, "postage")
			town.solved.erase("postage")
			town.lanterns.erase("postage")
		"gremlin", "gremlin-town":
			town = LanternReference.town(catalog, language, 8)
			town.files.bakery = NO_DEFAULT[language]
		"festival":
			town = LanternReference.town(catalog, language)
			town.complete = true
	LanternStore.for_profile().save_town(town)


func _play(screen: LanternrootScreen, base: String, language: String) -> void:
	var bench := screen.get("_bench") as LanternWorkbench
	match base:
		"letter", "fail", "wrong", "lit":
			screen.call("_open_letter", "loaves")
			if base == "wrong":
				bench.editor.text = WRONG[language]
			elif base == "lit":
				bench.editor.text = String(LanternrootScreen.catalog_of().requests.loaves.solution[language])
			if base != "letter":
				await screen.call("_run_tests")
		"night":
			screen.call("_ring_bell")
			await get_tree().create_timer(2.6).timeout
		"gremlin", "gremlin-town":
			await screen.call("_ring_bell")
			if base == "gremlin-town":
				screen.call("_close_modal")
