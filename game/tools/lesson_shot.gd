extends Control
## Moments of Lanternroot's lessons 2 and 3 for screenshots (ADR-0061), each in its own save folder:
##   ROOTWARD_LESSON=<moment> scripts/screenshot.sh res://tools/lesson_shot.tscn shots/lesson.png 40
## Moments:
##   offer                         Vell offers lesson 2 (the hello quest's flags set, standing beside her)
##   memory, memory-fail, memory-pass   the save lesson for a Builder: x and y ticked; tried; x, y and map, tried
##   memory-code                   the save lesson for a Scribe, typed and tried
##   lamps, lamps-fail, lamps-pass the lamps lesson for a Builder: nothing; the first lamp, tried; the loop, tried
##   lamps-code                    the lamps lesson for a Scribe in JavaScript, typed and tried
##   memory-hints, lamps-hints     the same two Scribe lessons with the hints open (memory-hints is not tried)
##   lane-dark, lane-lighting, lane-lit   the lane before, while and after it lights
##   note                          Continue with a save that forgot the map: Hotaru says so at home
## The town is the overworld itself (res://scenes/overworld/overworld.tscn); `shot_ready` says when the moment is set.

signal shot_ready

const LOOK := {
	"outfit": "outfit/tunic",
	"hair": "hair/short",
	"colours":
	{"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"},
}
const WALKED: Array[String] = ["woke", "first-step", "all-ways", "left-home", "boots-hint-seen"]
const HELLO: Array[String] = ["met-innkeeper", "met-guildmaster", "met-a", "met-b", "met-c", "met-d", "read-notices"]
const MEMORY: Array[String] = ["memory-asked", "memory-written", "saved-once"]
const SCRIBE_SAVE := (
	"def save(player):\n"
	+ "    # Keep where I stand, which map, and which way I face.\n"
	+ '    return {"x": player["x"], "y": player["y"], "map": player["map"], "facing": player["facing"]}\n'
)
const SCRIBE_LAMPS := "function lightAll(lamps) {\n  for (const lamp of lamps) {\n    lamp.lit = true;\n  }\n}\n"


func _ready() -> void:
	var moment := OS.get_environment("ROOTWARD_LESSON")
	if moment == "":
		moment = "memory"
	Game.reset("user://lesson-shot-saves/" + moment)
	Game.boot()
	Game.profile.needs_name = false
	Game.profile.preferred_language = "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	var store := OverworldStore.for_profile()
	store.delete_state()
	store.save_state(_state_for(moment))
	var screen := (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(30)
	for i in 600:
		if not bool(screen.get("_reading")):
			break
		await get_tree().process_frame
	await _play(screen, moment)
	shot_ready.emit()


func _state_for(moment: String) -> Dictionary:
	var state := OverworldState.fresh("lanternroot", Vector2i(18, 8), "right", "python")
	state.look = LOOK
	state.name = "Tinker"
	var flags: Array[String] = WALKED + HELLO
	if moment.begins_with("memory"):
		flags.append("memory-asked")
	if moment.begins_with("lamps") or moment.begins_with("lane"):
		flags.append_array(MEMORY)
		flags.append("lamps-asked")
		state = OverworldState.moved(state, "lanternroot", Vector2i(44, 9), "right")
	if moment == "lane-dark" or moment == "lane-lighting" or moment == "lane-lit":
		flags.append("lamps-written")
		state.lessons = {"lamps": {"blocks": {"loop": true, "inside": true}, "passed": true}}
	match moment:
		"memory":
			state.lessons = {"memory": {"blocks": ["x", "y"]}}
		"memory-fail":
			state.lessons = {"memory": {"blocks": ["x", "y"]}}
		"memory-pass":
			state.lessons = {"memory": {"blocks": ["x", "y", "map"]}}
		"memory-code", "memory-hints":
			state.boots.style = OverworldState.SCRIBE
			if moment == "memory-code":
				state.lessons = {"memory": {"code": {"python": SCRIBE_SAVE}}}
		"lamps-fail":
			state.lessons = {"lamps": {"blocks": {"first": true}}}
		"lamps-pass":
			state.lessons = {"lamps": {"blocks": {"first": false, "loop": true, "inside": true}}}
		"lamps-code", "lamps-hints":
			state.boots.style = OverworldState.SCRIBE
			state.language = "javascript"
			if moment == "lamps-code":
				state.lessons = {"lamps": {"code": {"javascript": SCRIBE_LAMPS}}}
		"note":
			flags.append_array(MEMORY)
			state.lessons = {"memory": {"blocks": ["x", "y"], "passed": true, "source": "", "language": "python"}}
			state.memory = {"x": 19, "y": 16}
	var raised := {}
	for flag in flags:
		raised[flag] = true
	state.flags = raised
	return state


func _play(screen: OverworldScreen, moment: String) -> void:
	var host := screen.get("_lessons") as LessonHost
	var editor := host.get("_editor") as LessonEditor
	match moment:
		"offer":
			screen.call("_interact")
			await _frames(40)
			var talk := screen.get("_talk") as DialogueBox
			for i in 2:
				_finish_typing(talk)
				talk.advance()
				await _frames(30)
			_finish_typing(talk)
		"memory", "memory-code", "memory-fail", "memory-pass", "memory-hints":
			CodeHints.remembered_open = moment.ends_with("-hints")
			host.open_lesson(Lessons.MEMORY, screen.state)
			await _frames(20)
			if moment != "memory" and moment != "memory-hints":
				await editor.try_it()
		"lamps", "lamps-fail", "lamps-pass", "lamps-code", "lamps-hints":
			CodeHints.remembered_open = moment.ends_with("-hints")
			host.open_lesson(Lessons.LAMPS, screen.state)
			await _frames(20)
			if moment != "lamps" and moment != "lamps-hints":
				await editor.try_it()
		"lane-lighting":
			host.call("_light_the_lane")
			await get_tree().create_timer(1.45).timeout
		"lane-lit":
			host.call("_light_the_lane")
			await get_tree().create_timer(3.2).timeout
			_finish_typing(host.get("_voice") as DialogueBox)
		"note":
			await get_tree().create_timer(1.2).timeout
			_finish_typing(host.get("_voice") as DialogueBox)
	await _frames(10)
	# Hotaru's note about where Continue woke the player (the shot's state has no save) would sit over the editor.
	if moment.begins_with("memory") or moment.begins_with("lamps"):
		(host.get("_voice") as DialogueBox).visible = false


func _finish_typing(talk: DialogueBox) -> void:
	var words := talk.get("_text") as RichTextLabel
	if talk.busy and words.visible_characters != -1:
		talk.advance()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
