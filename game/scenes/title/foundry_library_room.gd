class_name FoundryLibraryRoom
extends Control
## An opaque archive room replaces the station visually while retaining the title's safe modal focus lifecycle.

var _painting: TextureRect
var _light: ShaderMaterial
var _clock := 0.0


static func make(panel: FoundryLibraryPanel) -> FoundryLibraryRoom:
	var room := FoundryLibraryRoom.new()
	room.size = Vector2(1920, 1080)
	room.mouse_filter = Control.MOUSE_FILTER_STOP
	var ground := ColorRect.new()
	ground.color = Color("101b1c")
	ground.size = room.size
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(ground)
	room._painting = TextureRect.new()
	room._painting.texture = Art.texture("menus/living-archive")
	room._painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room._painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room._painting.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	room._painting.size = room.size
	room._painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room._light = ShaderMaterial.new()
	room._light.shader = preload("res://scenes/title/library_lights.gdshader")
	room._painting.material = room._light
	room.add_child(room._painting)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.06, 0.07, 0.22)
	shade.size = room.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(shade)
	var plaque := Ui.vbox(
		[
			Ui.tint(Ui.label(FoundryUi.text("THE LIVING ARCHIVE", "記憶の図書室"), "Heading"), UiTheme.AMBER),
			Ui.label(FoundryUi.text("A quiet room. A thousand ways forward.", "静かな部屋に、旅のヒントがいっぱい。"), "Muted")
		],
		6
	)
	FoundryUi.place(room, plaque, Rect2(480, 160, 960, 60))
	var page := Ui.centered_scroll(panel)
	page.size = room.size
	room.add_child(page)
	FoundryUi.place(
		room,
		Ui.label(
			FoundryUi.text(
				"Tab · Navigate    Enter · Inspect    Esc · Return to station", "Tab · 移動    Enter · 調べる    Esc · 駅へ戻る"
			),
			"Muted"
		),
		Rect2(480, 860, 960, 28)
	)
	return room


func _process(delta: float) -> void:
	if Settings.reduced_motion:
		return
	_clock += delta
	_light.set_shader_parameter("clock", _clock)
