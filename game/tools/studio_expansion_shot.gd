extends "res://tools/overworld_shot.gd"
## Read-only catalog review of Lanternroot Studio's expanded assets.


func _ready() -> void:
	OS.set_environment("ROOTWARD_LANTERNTOWN_MAP", "home")
	await super._ready()


func _catalog(studio: StudioMode) -> void:
	studio.focus(Vector2(5.5, 4.5) * OverworldScale.TILE)
	var category := OS.get_environment("ROOTWARD_EXPANSION_CATEGORY")
	studio.place_panel().set_filters({"view": "all", "category": category, "subcategory": "", "text": "expand"})
	await _frames(3)
