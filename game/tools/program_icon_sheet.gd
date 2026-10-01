extends Control
## A review fixture using the unchanged real CardFace at its hand size, with no overlap hiding the art.
## ROOTWARD_ICON_PAGE is 0, 1 or 2. No gameplay or player saves are changed.

signal shot_ready


func _ready() -> void:
	theme = UiTheme.shared()
	var backdrop := ColorRect.new()
	backdrop.color = UiTheme.GROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var catalog := ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)
	var ids: Array[String] = []
	for id: String in catalog.shards:
		if not id.ends_with("-plus"):
			ids.append(id)
	ids.sort()
	var page := clampi(int(OS.get_environment("ROOTWARD_ICON_PAGE")), 0, 2)
	var heading := Ui.sized(
		Ui.label("SHARDRUN CARD ART  ·  %d / 3  ·  REAL HAND-SIZE CARDS" % (page + 1), "Heading"), 26
	)
	heading.position = Vector2(64, 24)
	add_child(heading)
	for index in range(page * 32, mini((page + 1) * 32, ids.size())):
		var card := CardFace.create(ids[index], catalog, "python", true, CardFace.Size.HAND)
		card.draggable = false
		card.details = false
		var local := index - page * 32
		card.position = Vector2(64 + (local % 8) * 224, 80 + (local / 8) * 244)
		add_child(card)
	for frame in 10:
		await get_tree().process_frame
	set_meta("shot_ready", true)
	shot_ready.emit()
