extends Control
## Moments of Lanternroot's overworld for screenshots (ADR-0061), each in its own save folder:
##   ROOTWARD_LANTERNTOWN=<moment> scripts/screenshot.sh res://tools/overworld_shot.tscn shots/town.png 40
## Moments: creator, wake, home, boots, code, town, square, talk, board, choice, bubble; add "-ja" for Japanese.
## A moment says `shot_ready` once it is set up (the boots have been read, and a talk is typed out as far as the picture
## needs), so the frames the screenshot waits are counted from then.

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
		"square", "bubble":
			state = OverworldState.moved(state, "lanternroot", Vector2i(19, 16), "up")
		"talk":
			state = OverworldState.moved(state, "lanternroot", Vector2i(32, 18), "up")
		"board":
			# The noticeboard is at (16, 11), two tiles wide: stand below its left half, facing it.
			state = OverworldState.moved(state, "lanternroot", Vector2i(16, 12), "up")
		"choice":
			# The innkeeper, Marta, stands at (32, 17).
			state = OverworldState.moved(state, "lanternroot", Vector2i(32, 18), "up")
	store.save_state(state)
	var screen := (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate()
	add_child(screen)
	for i in 30:
		await get_tree().process_frame
	await _until_read(screen)
	await _play(screen, base)
	shot_ready.emit()


## Sets the moment up on the screen: the boots open, or a talk is started and typed out as far as its picture needs.
func _play(screen: Node, base: String) -> void:
	var talk := screen.get("_talk") as DialogueBox
	match base:
		"boots", "code":
			screen.call("_open_boots")
		"bubble":
			# Hotaru's remark, as a walk into a wall says it: the bubble in the overworld's style.
			screen.call("_hotaru_says", Text.t("Whoa! Boots only take one step at a time: change x or y by 1."))
		"talk", "board":
			screen.call("_interact")
			await _frames(40)
			_finish_typing(talk)
		"choice":
			# Marta's first line is typed out and passed on, then her second line, and her choices show.
			screen.call("_interact")
			await _frames(40)
			_finish_typing(talk)
			talk.advance()
			await _frames(40)
			_finish_typing(talk)
	await _frames(10)


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
