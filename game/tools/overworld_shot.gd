extends Control
## Moments of Lanternroot's overworld for screenshots (ADR-0061), each in its own save folder:
##   ROOTWARD_LANTERNTOWN=<moment> scripts/screenshot.sh res://tools/overworld_shot.tscn shots/town.png 40
## Moments: creator, wake, home, boots, code, town, square, talk; add "-ja" for Japanese.

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


func _ready() -> void:
	var moment := OS.get_environment("ROOTWARD_LANTERNTOWN")
	if moment == "":
		moment = "town"
	var base := moment.trim_suffix("-ja")
	Game.reset("user://overworld-shot-saves/" + moment)
	Game.boot()
	Game.profile.needs_name = false
	Game.profile.preferred_language = "ja" if moment.ends_with("-ja") else "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	var store := OverworldStore.for_profile()
	store.delete_state()
	var flags := {"woke": true, "first-step": true, "all-ways": true, "left-home": true}
	var state := OverworldState.fresh("lanternroot", Vector2i(6, 23), "down", "python")
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
		"home", "boots", "code":
			state = OverworldState.moved(state, "home", Vector2i(4, 4), "down")
			state.boots.blocks = FULL_BOOTS.slice(0, 2)
			if base == "code":
				state.boots.mode = "code"
				state.boots.code = {"python": BootsCode.source(FULL_BOOTS.slice(0, 3), "python")}
		"square":
			state = OverworldState.moved(state, "lanternroot", Vector2i(19, 16), "up")
		"talk":
			state = OverworldState.moved(state, "lanternroot", Vector2i(32, 18), "up")
	store.save_state(state)
	var screen := (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate()
	add_child(screen)
	for i in 30:
		await get_tree().process_frame
	match base:
		"boots", "code":
			screen.call("_open_boots")
		"talk":
			screen.call("_interact")
			for i in 40:
				await get_tree().process_frame
			(screen.get("_talk") as DialogueBox).advance()
