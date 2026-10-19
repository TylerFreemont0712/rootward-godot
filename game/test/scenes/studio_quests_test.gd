extends GdUnitTestSuite
## The quest editor (Concept/v0.3/10, S9). The acceptance: a step added to "Hello, Lanternroot" that needs a new flag set
## by talking to Pip; the draft played; the tracker shows the step, and talking to Pip completes it; Publish writes
## quests.jsonc and talk/pip.jsonc and the world loads them. Then: undo and redo of a step, the flag browser and its
## jumps (to a quest step, a talk node, a thing), a talk that leads nowhere, and moving a quest. Content, drafts and
## saves are isolated copies.

const TEST_ROOT := "user://studio_test/quests"
const OVERWORLD := "res://scenes/overworld/overworld.tscn"
const TOWN := "lanternroot"
const LOOK := {"outfit": "outfit/tunic", "hair": "hair/short", "colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"}}
const BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true, "first-action": true}
const WIDTH := 20
const HEIGHT := 48
const PIP := Vector2i(9, 11)
const FLAG := "waved-at-pip"
const STEP_TEXT := "Wave to Pip, who is counting lanterns."

var screen: OverworldScreen
var studio: StudioMode
var _root := ""
var _old_drafts := ""
var _old_playtest := ""
var _old_content := ""
var _old_env := ""
var _old_catalog: Dictionary = {}


func before_test() -> void:
	_root = TEST_ROOT.path_join(str(Time.get_ticks_usec()))
	_old_drafts = StudioMode.drafts_dir
	_old_playtest = StudioMode.playtest_dir
	_old_content = StudioMode.content_dir
	_old_env = OS.get_environment("ROOTWARD_STUDIO")
	_old_catalog = OverworldScreen._catalog_cache
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
	StudioAssets.reload()
	assert_bool(StudioFiles.write_content(_path(TOWN), JsoncWriter.map_text("// Quests fixture\n", _fixture()))).is_true()
	# The real town's pickups, places (v0.4) and schedules (chapter 3) are cells of the real map, not of this small
	# fixture: they go.
	for name: String in ["pickups.jsonc", "places.jsonc", "schedules.jsonc"]:
		DirAccess.remove_absolute(_content(name))
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var state := OverworldState.fresh(TOWN, Vector2i(2, 2), "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Quests tester"
	state.flags = BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	screen = (load(OVERWORLD) as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
	studio.set_editing(true)
	await _frames(2)
	studio.set_tab("quests")
	await _frames(3)


func after_test() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	Sound.silence()
	await _frames(6)
	Background.finish_all()
	Game.reset()
	StudioMode.drafts_dir = _old_drafts
	StudioMode.playtest_dir = _old_playtest
	StudioMode.content_dir = _old_content
	OverworldScreen._catalog_cache = _old_catalog
	StudioAssets.reload()
	OS.set_environment("ROOTWARD_STUDIO", _old_env)
	_remove_tree(_root)


func _path(id: String) -> String:
	return StudioSession.path_of(id, StudioMode.content_dir)


func _content(name: String) -> String:
	return StudioMode.content_dir.path_join("packs/core/overworld").path_join(name)


## A grass town: Pip, and the player's house.
func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in HEIGHT:
		rows.append(".".repeat(WIDTH))
	return {"id": TOWN, "name": "Quests test", "legend": {".": "grass"}, "ground": rows, "start": [2, 2], "facing": "down", "objects": [
		{"kind": "person", "id": "pip", "at": [PIP.x, PIP.y], "facing": "right"},
		{"kind": "building", "art": "home", "at": [10, 39], "size": [6, 6], "door": [3, 5], "to": {"map": "home", "at": [5, 6], "facing": "up"}},
	]}


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _publisher() -> StudioPublish:
	var publisher := StudioPublish.new()
	publisher.content_root = StudioMode.content_dir
	publisher.drafts_dir = StudioMode.drafts_dir
	publisher.backups_dir = _root.path_join("backups")
	return publisher


## Types into the text box with this fid and presses Enter, as a player would.
func _type(root: Node, fid: String, text: String) -> void:
	var edit := StudioQuestUi.find(root, fid) as LineEdit
	assert_object(edit).override_failure_message("no text box %s" % fid).is_not_null()
	edit.text = text
	edit.text_submitted.emit(text)


func _press(root: Node, button_name: String) -> void:
	var button := root.find_child(button_name, true, false) as Button
	assert_object(button).override_failure_message("no button %s" % button_name).is_not_null()
	assert_bool(button.disabled).override_failure_message("%s is disabled" % button_name).is_false()
	button.pressed.emit()


func _hello_steps() -> Array:
	return studio.quests.data("quests").hello.steps


## Frames go by until the check holds, for at most five seconds.
func _until(check: Callable) -> void:
	var limit := Time.get_ticks_msec() + 5000
	while not bool(check.call()) and Time.get_ticks_msec() < limit:
		await get_tree().process_frame


## The talk goes on to its end: a choice is picked when there is one, a line is read otherwise.
func _talk_through() -> void:
	var box := screen.get("_talk") as DialogueBox
	var choices := box.get("_choices") as VBoxContainer
	for step: int in 600:
		if not box.busy:
			return
		if choices.get_child_count() > 0:
			(choices.get_child(0) as Button).pressed.emit()
		else:
			box.advance()
		await get_tree().process_frame


func test_a_step_that_needs_a_flag_pip_sets_is_shown_by_the_tracker_and_done_by_talking_and_publishes() -> void:
	var panel := studio.quest_panel
	assert_bool(panel.visible).is_true()
	var list := panel.quest_list
	list.choose("hello")
	await _frames(2)
	assert_int(_hello_steps().size()).is_equal(4)
	# Add a step with the button, and say its words and its flag in the boxes.
	_press(panel, "AddStep")
	await _frames(3)
	assert_int(_hello_steps().size()).is_equal(5)
	_type(list, "step.4.text", STEP_TEXT)
	await _frames(3)
	_type(list, "step.4.done.flag", FLAG)
	await _frames(3)
	assert_str(JSON.stringify(_hello_steps()[4])).is_equal(JSON.stringify({"text": STEP_TEXT, "done": {"flag": FLAG}}))
	# Pip's first words set it.
	panel.show_talk("pip", "hello")
	await _frames(3)
	assert_str(panel.talk_editor.node).is_equal("hello")
	_type(panel.talk_editor, "node.set.add", FLAG)
	await _frames(3)
	var sets: Array = studio.quests.data("talk/pip").nodes.hello.set
	assert_array(sets).is_equal(["met-pip", FLAG])
	assert_str(panel.drafted_text).contains("quests.jsonc")
	assert_str(panel.drafted_text).contains("talk/pip.jsonc")
	assert_array(studio.quests.drafted_keys()).is_equal(["quests", "talk/pip"])
	# Play the draft; the earlier steps (and quests) are done by poke.
	studio.set_play_draft(true)
	studio.set_editing(false)
	await _frames(3)
	assert_int((screen.catalog.quests.hello.steps as Array).size()).override_failure_message("Play draft plays the new step").is_equal(5)
	assert_bool(studio.debug.jump_to("hello")).is_true()
	assert_bool(studio.debug.complete_step("hello", 3)).is_true()
	await _frames(3)
	var current := Quests.current(screen.catalog.quests, screen.state.flags)
	assert_str(String(current.id)).is_equal("hello")
	assert_int(int(current.step)).is_equal(4)
	var tracker := screen.get("_tracker") as QuestTracker
	tracker.set_shown(true)
	await _until(func() -> bool: return tracker.step_text() == STEP_TEXT)
	assert_str(tracker.step_text()).override_failure_message("the tracker shows the new step").is_equal(STEP_TEXT)
	var before: Dictionary = screen.state.flags.duplicate()
	# Talk to Pip, standing beside them.
	var player := screen.get("_player") as Walker
	var beside := PIP + Vector2i.RIGHT
	player.place(beside, "left")
	screen.state = OverworldState.moved(screen.state, TOWN, beside, "left")
	screen.call("_interact")
	await _talk_through()
	assert_bool(bool(screen.state.flags.get(FLAG, false))).override_failure_message("talking to Pip sets the flag").is_true()
	assert_str(Quests.status(screen.catalog.quests, "hello", screen.state.flags)).is_equal(Quests.DONE)
	assert_int(Quests.steps_done(screen.catalog.quests.hello, screen.state.flags)).is_equal(5)
	assert_array(Quests.finished(screen.catalog.quests, before, screen.state.flags)).contains(["hello"])
	# Publish: both files are written and the world loads them.
	studio.set_play_draft(false)
	await _frames(1)
	assert_bool(studio.work.flush()).is_true()
	var result := _publisher().publish(studio.work.sessions(), true)
	assert_bool(result.ok).override_failure_message("publish: %s %s" % [str(result.get("error", "")), str(result.get("problems", []))]).is_true()
	assert_str(StudioFiles.read_text(_content("quests.jsonc"))).contains(FLAG)
	assert_str(StudioFiles.read_text(_content("talk/pip.jsonc"))).contains(FLAG)
	var loaded := OverworldContent.load_world(StudioMode.content_dir)
	for diagnostic: Dictionary in loaded.diagnostics:
		assert_str(ContentLoader.describe(diagnostic)).override_failure_message("a diagnostic: " + ContentLoader.describe(diagnostic)).is_empty()
	assert_int((loaded.catalog.quests.hello.steps as Array).size()).is_equal(5)
	assert_bool(Talk.sets(loaded.catalog.talk.pip, "hello").has(FLAG)).is_true()
	assert_array(studio.quests.drafted_keys()).override_failure_message("nothing is left to publish").is_empty()


func test_undo_and_redo_take_a_step_back_and_do_it_again() -> void:
	var panel := studio.quest_panel
	panel.quest_list.choose("hello")
	await _frames(2)
	_press(panel, "AddStep")
	await _frames(3)
	assert_int(_hello_steps().size()).is_equal(5)
	assert_bool((panel.find_child("Undo", true, false) as Button).disabled).is_false()
	_press(panel, "Undo")
	await _frames(3)
	assert_int(_hello_steps().size()).is_equal(4)
	assert_str(panel.drafted_text).contains("Nothing changed")
	_press(panel, "Redo")
	await _frames(3)
	assert_int(_hello_steps().size()).is_equal(5)
	# Ctrl+Z and Ctrl+Shift+Z do the same, while no text box has the focus.
	var undo_key := InputEventKey.new()
	undo_key.keycode = KEY_Z
	undo_key.ctrl_pressed = true
	undo_key.pressed = true
	assert_bool(panel.key(undo_key)).is_true()
	await _frames(2)
	assert_int(_hello_steps().size()).is_equal(4)
	undo_key.shift_pressed = true
	assert_bool(panel.key(undo_key)).is_true()
	await _frames(2)
	assert_int(_hello_steps().size()).is_equal(5)
	# A step moved and removed is one undo step each.
	panel.quest_list.move_step(4, -1)
	await _frames(2)
	assert_bool(panel.quest_list.remove_step(0)).is_true()
	await _frames(2)
	assert_int(_hello_steps().size()).is_equal(4)
	assert_bool(panel.undo()).is_true()
	assert_int(_hello_steps().size()).is_equal(5)
	assert_bool(panel.undo()).is_true()
	assert_str(String(_hello_steps()[3].text)).is_equal("Read the noticeboard in the square.")


func test_the_flag_browser_lists_the_new_flag_with_who_sets_and_reads_it_and_jumps_there() -> void:
	var panel := studio.quest_panel
	panel.quest_list.choose("hello")
	panel.quest_list.add_step({"text": STEP_TEXT, "done": {"flag": FLAG}})
	studio.quests.do("talk/pip", {"type": "insert_at", "path": ["nodes", "hello", "set"], "index": -1, "value": FLAG})
	var index := studio.quests.flags()
	assert_dict(index).contains_keys([FLAG])
	assert_array(index[FLAG].set_by).is_equal([{"kind": "talk", "id": "pip", "node": "hello"}])
	assert_array(index[FLAG].read_by).is_equal([{"kind": "quest", "id": "hello", "step": 4}])
	panel.show_sub("flags")
	await _frames(3)
	var browser := panel.flag_browser
	assert_array(browser.shown).contains([FLAG, "met-pip", "first-step"])
	# The search narrows the list; the orphans are the ones to look at.
	browser.search.text = "waved"
	browser.rebuild()
	assert_array(browser.shown).is_equal([FLAG])
	browser.search.text = ""
	browser.rebuild()
	await _frames(2)
	# Reading it: the quest, at the step.
	_press(browser, "Read_%s_0" % FLAG)
	await _frames(3)
	assert_str(panel.sub).is_equal("quests")
	assert_str(panel.quest_list.chosen).is_equal("hello")
	assert_int(panel.quest_list.step_marked).is_equal(4)
	# Setting it: the talk, at the node.
	panel.show_sub("flags")
	await _frames(2)
	_press(browser, "Set_%s_0" % FLAG)
	await _frames(3)
	assert_str(panel.sub).is_equal("talk")
	assert_str(panel.talk_editor.file).is_equal("pip")
	assert_str(panel.talk_editor.node).is_equal("hello")


func test_a_flag_a_thing_raises_jumps_to_the_thing_on_its_map() -> void:
	var plate := {"kind": "prop", "art": "step", "id": "tester-plate", "at": [3, 3], "solid": false, "draw_layer": "ground",
		"program": {"hook": "on_step", "fields": {}, "raises": ["plate-pressed"]}}
	assert_bool(bool(studio.work.command({"type": "add", "object": plate, "index": -1}).get("ok", false))).is_true()
	var panel := studio.quest_panel
	panel.show_sub("flags")
	await _frames(3)
	assert_array(panel.flag_browser.shown).contains(["plate-pressed"])
	_press(panel.flag_browser, "Set_plate-pressed_0")
	await _frames(3)
	assert_str(studio.tab).is_equal("objects")
	assert_bool(panel.visible).is_false()
	assert_int(studio.selected_sids().size()).is_equal(1)
	assert_str(String(studio.selected_object().get("id", ""))).is_equal("tester-plate")


func test_a_choice_that_goes_to_a_node_that_is_not_there_is_a_problem_shown_under_the_editor() -> void:
	var panel := studio.quest_panel
	panel.show_talk("pip", "hello")
	await _frames(3)
	assert_array(panel.talk_editor.problems_text).is_empty()
	studio.quests.do("talk/pip", {"type": "set_at", "path": ["nodes", "hello", "choices", 0, "goto"], "value": "nowhere"})
	await _frames(3)
	assert_array(panel.talk_editor.problems_text).contains(["hello leads to nowhere, which is not a node", "nothing leads to zero"])
	var goto := panel.find_child("ChoiceGoto0", true, false) as OptionButton
	assert_str(goto.get_item_text(goto.selected)).contains("nowhere")
	# Picking the node it should go to takes the problem away.
	panel.talk_editor.set_choice(0, "goto", "zero")
	await _frames(3)
	assert_array(panel.talk_editor.problems_text).is_empty()
	# A node nothing leads to can go; one something leads to cannot.
	assert_bool(panel.talk_editor.add_node("fresh")).is_true()
	await _frames(2)
	assert_bool(panel.talk_editor.remove_node()).is_true()
	panel.talk_editor.choose_node("zero")
	assert_bool(panel.talk_editor.remove_node()).is_false()


func test_a_quest_moves_in_the_order_and_a_condition_changes_kind() -> void:
	var panel := studio.quest_panel
	var list := panel.quest_list
	list.choose("lamps")
	await _frames(2)
	assert_bool(list.move_quest(-1)).is_true()
	await _frames(2)
	# Chapter 1 since v0.4: boots, hello, menu, memory, lamps (chapter 2's quests follow).
	assert_array(Quests.ordered(list.quests()).slice(0, 5)).is_equal(["boots", "hello", "menu", "lamps", "memory"])
	assert_bool(panel.undo()).is_true()
	assert_array(Quests.ordered(list.quests()).slice(0, 5)).is_equal(["boots", "hello", "menu", "memory", "lamps"])
	# A step's condition: a count, then an all of two flags.
	list.choose("hello")
	assert_bool(list.set_step(0, "done", StudioConditionEditor.converted({"flag": "met-innkeeper"}, StudioConditionEditor.COUNT))).is_true()
	assert_str(StudioQuests.condition_text(list.steps()[0].done)).is_equal("1 or more of …")
	var all := StudioConditionEditor.converted({"flag": "met-innkeeper"}, StudioConditionEditor.ALL)
	assert_str(JSON.stringify(all)).is_equal(JSON.stringify({"all": [{"flag": "met-innkeeper"}]}))
	assert_str(StudioConditionEditor.kind_of({"flag": "a", "not": "b"})).is_equal(StudioConditionEditor.FLAG_NOT)
	# A new quest, with an id that is free; a taken one is refused.
	assert_bool(list.add_quest("garden")).is_true()
	assert_str(list.chosen).is_equal("garden")
	# A new quest goes last, after the last quest (since v0.4, the credits).
	var order := Quests.ordered(list.quests())
	assert_str(order[-1]).is_equal("garden")
	assert_array(list.quests().garden.after).is_equal([order[-2]])
	assert_bool(list.add_quest("garden")).is_false()
	assert_bool(list.remove_quest()).is_true()
	assert_bool(list.quests().has("garden")).is_false()


func _copy_tree(source: String, target: String) -> void:
	DirAccess.make_dir_recursive_absolute(target)
	for directory: String in DirAccess.get_directories_at(source):
		_copy_tree(source.path_join(directory), target.path_join(directory))
	for file: String in DirAccess.get_files_at(source):
		assert_int(DirAccess.copy_absolute(source.path_join(file), target.path_join(file))).is_equal(OK)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
