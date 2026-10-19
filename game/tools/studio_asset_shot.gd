extends "res://tools/overworld_shot.gd"
## Isolated size/review demonstration. ROOTWARD_LANTERNTOWN=studio-catalog ROOTWARD_ASSET_SHOT=size|menu|reviews|prompt


func _catalog(studio: StudioMode) -> void:
	var commands: Array = []
	for sid: int in studio.work.doc().sids:
		commands.append({"type": "remove", "sid": sid})
	studio.work.command({"type": "batch", "name": "Clear screenshot stage", "commands": commands})
	var rows: Array[String] = []
	for y: int in studio.current_map().height:
		rows.append(".".repeat(int(studio.current_map().width)))
	studio.work.command({"type": "set_map", "key": "legend", "value": {".": "grass"}})
	studio.work.command({"type": "set_map", "key": "ground", "value": rows})
	var small := studio.work.place(StudioAssets.template("inn"), Vector2i(34, 24))
	var large := studio.work.place(StudioAssets.template("inn"), Vector2i(43, 24))
	var barrel := studio.work.place(StudioAssets.template("barrel"), Vector2i(37, 27))
	studio.work.resize_object(int(small.sid), Vector2i(4, 4))
	studio.work.resize_object(int(large.sid), Vector2i(7, 6))
	studio.work.resize_object(int(barrel.sid), Vector2i(2, 2))
	studio.select_sids([int(large.sid)])
	studio.studio_camera().shown = 2
	studio.focus(Vector2(39, 22) * OverworldScale.TILE)
	studio.set_overlay("grid", false)
	studio.set_overlay("footprints", true)
	studio.set_place_list(true)
	studio.place_panel().search_for("inn")
	studio.asset_reviews.flag("inn")
	studio.asset_reviews.flag("expand-stone_bench")
	await _frames(5)
	match OS.get_environment("ROOTWARD_ASSET_SHOT"):
		"menu":
			studio.asset_reviews.resolve("inn")
			var card := studio.place_panel().find_child("Card_inn", true, false) as StudioCatalogCard
			studio.asset_reviews.open_menu("inn", card.get_screen_transform() * (card.size / 2.0))
		"prompt":
			studio.asset_reviews.flag("barrel")
			studio.asset_reviews.open_reviews("barrel")
			(studio.asset_reviews.find_child("ReviewNotes", true, false) as TextEdit).text = "Use quieter wood colours and sturdy iron hoops to match the village."
			(studio.asset_reviews.find_child("ReplacementPrompt", true, false) as LineEdit).text = "weathered oak barrel with dark iron hoops and a small painted fox emblem"
			studio.asset_reviews._refresh_generate()
			studio.asset_reviews._save_fields()
		"reviews":
			studio.asset_reviews.open_reviews("inn")
			(studio.asset_reviews.find_child("ReviewNotes", true, false) as TextEdit).text = "Roof feels too bright. Aim for warmer timber, quieter colours and the same village scale."
			(studio.asset_reviews.find_child("ReplacementPrompt", true, false) as LineEdit).text = "cozy timber village inn with a weathered moss roof"
			studio.asset_reviews._save_fields()
	await _frames(5)
