extends "res://tools/overworld_shot.gd"
## P05 mounted navigation/diagnostic review, using the base helper's isolated draft and save folders.


func _doors(studio: StudioMode, _base: String) -> void:
	studio.set_overlay("doors", true)
	studio.set_tab("people")
	studio.people_panel().choose_view("people")
	var person := -1
	var building := -1
	for object: Dictionary in studio.current_map().objects:
		if String(object.get("id", "")) == "innkeeper":
			person = int(object.index)
		if String(object.get("art", "")) == "inn":
			building = int(object.index)
	studio.select(person)
	var at := OverworldMap.cell_of(studio.work.raw(person).get("at", [0, 0]))
	studio.focus((Vector2(at) + Vector2(0.5, 0)) * OverworldScale.TILE)
	var view := OS.get_environment("ROOTWARD_P05_VIEW")
	if view == "talk":
		studio.edit_person_talk("innkeeper")
	elif view == "quest":
		var references := StudioDoors.quest_references("innkeeper", studio.quests.data("quests"), studio.quests.data("talk/innkeeper"))
		if not references.is_empty():
			studio.edit_person_quest("innkeeper", String(references[0].id), int(references[0].step))
	elif view == "problem":
		studio.work.set_field(studio.work.sid_at(building), "to", {"map": "missing-room", "at": [5, 6], "facing": "up"})
		studio.people_panel().choose_view("entrances")
		var filter := studio.people_panel().find_child("PersonFilter", true, false) as OptionButton
		filter.select(3)
		filter.item_selected.emit(3)
		studio.select(building)
		var door := StudioDoors.front_of(studio.work.raw(building))
		studio.focus((Vector2(door) + Vector2(0, -1)) * OverworldScale.TILE)
	else:
		studio.edit_person_talk("innkeeper")
		studio.return_to_person()
	await _frames(4)
