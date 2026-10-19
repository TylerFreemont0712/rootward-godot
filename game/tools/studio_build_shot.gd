extends "res://tools/overworld_shot.gd"
## B01 shared shelf review. The base helper owns isolated drafts/saves; no source content is published.


func _catalog(studio: StudioMode) -> void:
	studio.set_tab("build")
	var group := OS.get_environment("ROOTWARD_BUILD_GROUP")
	if not StudioBuildCatalog.GROUPS.has(group):
		group = "building"
	if group == "furniture":
		studio.go_to_map("home")
	else:
		for object: Dictionary in studio.current_map().objects:
			if String(object.get("art", "")) == "home":
				studio.select(int(object.index))
				studio.focus((Vector2(object.at) + Vector2(3, 3)) * OverworldScale.TILE)
				break
	studio.build_panel().choose_group(group)
	studio.set_overlay("grid", false)
	studio.set_overlay("doors", true)
	await _frames(4)
