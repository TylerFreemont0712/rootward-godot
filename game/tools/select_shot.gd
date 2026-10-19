extends Control
## Moments of Lanternroot's character screen for screenshots (ADR-0061), each in its own save folder under
## user://select-shot-saves/, never the player's profiles:
##   ROOTWARD_SELECT_SHOT=<moment> scripts/screenshot.sh res://tools/select_shot.tscn shots/select/three.png 40
## Moments: three (three characters using both player models, the newest chosen), second (the middle one chosen),
## new (the New spot chosen), one (a single character),
## empty (no characters at all), many (nine characters, the fifth chosen), delete (the Delete question open), progress
## (the newest one's Progress panel); add "-ja" for Japanese.

signal shot_ready

const MALE_LOOK := {"model": "male"}
const FEMALE_LOOK := {"model": "female"}
const WALKERS := [
	["Taro", MALE_LOOK, {}],
	["Mina", FEMALE_LOOK, {"woke": true, "first-step": true}],
	[
		"Kai",
		MALE_LOOK,
		{"woke": true, "first-step": true, "all-ways": true, "left-home": true, "met-pip": true}
	],
]


func _ready() -> void:
	var moment := OS.get_environment("ROOTWARD_SELECT_SHOT")
	if moment == "":
		moment = "three"
	var base := moment.trim_suffix("-ja")
	Game.reset("user://select-shot-saves/" + moment)
	Game.boot()
	Game.profile.needs_name = false
	Game.profile.preferred_language = "ja" if moment.ends_with("-ja") else "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	var store := OverworldStore.for_profile()
	# Start from nothing: a shot never shows what an earlier run left in its folder.
	for entry in store.characters():
		store.delete_character(String(entry.id))
	var count := {"empty": 0, "one": 1, "many": 9}.get(base, 3) as int
	for i in count:
		var walker: Array = WALKERS[i % WALKERS.size()]
		var state := OverworldState.fresh("lanternroot", Vector2i(13, 45), "down", "python")
		state.look = walker[1]
		state.name = String(walker[0]) if count <= 3 else "%s %d" % [walker[0], i + 1]
		state.flags = walker[2]
		# Kai has played an hour and twenty minutes, Mina a quarter of an hour, Taro just begun.
		state["played_seconds"] = [0, 900, 4800][i % 3]
		store.save_character(store.new_id(), state)
		await get_tree().create_timer(0.02).timeout
	var screen := (
		(load("res://scenes/overworld/character_select.tscn") as PackedScene).instantiate()
		as CharacterSelect
	)
	screen.navigates = false
	add_child(screen)
	for i in 20:
		await get_tree().process_frame
	match base:
		"second":
			screen.choose(1)
		"new":
			screen.choose(screen.count() - 1)
		"many":
			screen.choose(4)
		"delete":
			screen.choose(1)
			screen._ask_delete()
		"progress":
			screen._show_progress()
	for i in 30:
		await get_tree().process_frame
	shot_ready.emit()
