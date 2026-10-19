extends "res://tools/overworld_shot.gd"
## P06 furnished room and exact return transition; the base helper owns isolated drafts and saves.


func _doors(studio: StudioMode, _base: String) -> void:
	if OS.get_environment("ROOTWARD_P06_VIEW") == "people":
		# Show one unplaced static roster entry beside placed entries; only this helper's draft changes.
		for object: Dictionary in studio.current_map().objects:
			if String(object.get("id", "")) == "innkeeper":
				studio.work.delete([studio.work.sid_at(int(object.index))], true)
				break
		studio.set_tab("people")
		studio.people_panel().choose_view("people")
		studio.focus(Vector2(49, 24) * OverworldScale.TILE)
		await _frames(4)
		return
	await super._doors(studio, "studio-room")
	studio.set_tab("people")
	studio.people_panel().choose_view("entrances")
	for object: Dictionary in studio.current_map().objects:
		if String(object.get("kind", "")) == "warp":
			studio.select(int(object.index))
			break
	studio.focus(Vector2(5.5, 4.0) * OverworldScale.TILE)
	await _frames(4)
