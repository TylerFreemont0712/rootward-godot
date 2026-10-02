class_name FoundrySettingsRoom
extends Control
## An opaque control room replaces the station visually while retaining the title's safe modal focus lifecycle.

var _painting: TextureRect
var _light: ShaderMaterial
var _clock := 0.0
var _preferences: ScrollContainer


static func make(panel: FoundrySettingsPanel) -> FoundrySettingsRoom:
	var room := FoundrySettingsRoom.new()
	room.size = Vector2(1920, 1080)
	room.mouse_filter = Control.MOUSE_FILTER_STOP
	var ground := ColorRect.new()
	ground.color = Color("101b1c")
	ground.size = room.size
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(ground)
	room._painting = TextureRect.new()
	room._painting.texture = Art.texture("menus/control-room")
	room._painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room._painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room._painting.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	room._painting.size = room.size
	room._painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room._light = ShaderMaterial.new()
	room._light.shader = preload("res://scenes/title/settings_lights.gdshader")
	room._painting.material = room._light
	room.add_child(room._painting)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.06, 0.07, 0.48)
	shade.size = room.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(shade)
	var reading_shade := ColorRect.new()
	var reading_material := ShaderMaterial.new()
	reading_material.shader = preload("res://scenes/title/library_reading_shade.gdshader")
	reading_shade.material = reading_material
	reading_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FoundryUi.place(room, reading_shade, Rect2(168, 184, 1480, 800))
	var plaque := Ui.vbox(
		[
			Ui.tint(Ui.sized(Ui.label(FoundryUi.text("THE CONTROL ROOM", "工房の調整室"), "Heading"), 32), UiTheme.AMBER),
			Ui.label(
				FoundryUi.text("Tune the light, the sound and the lettering of your journey.", "灯り、音、冒険の文字を、自分らしく。"),
				"Muted"
			)
		],
		6
	)
	FoundryUi.place(room, plaque, Rect2(200, 92, 1520, 76))
	room._preferences = Ui.centered_scroll(panel)
	FoundryUi.place(room, room._preferences, Rect2(200, 200, 1520, 760))
	room._preferences.minimum_size_changed.connect(room._fit_preferences)
	room._fit_preferences.call_deferred()
	FoundryUi.place(
		room,
		Ui.label(
			FoundryUi.text(
				"Tab · Navigate    Enter · Select    Esc · Return to station", "Tab · 移動    Enter · 選ぶ    Esc · 駅へ戻る"
			),
			"Muted"
		),
		Rect2(200, 1006, 1520, 28)
	)
	return room


func _process(delta: float) -> void:
	if Settings.reduced_motion:
		return
	_clock += delta
	_light.set_shader_parameter("clock", _clock)


func _fit_preferences() -> void:
	# LEARN: wrapped labels can shrink their minimum after layout; restore this room's intended rectangle too.
	_preferences.size = Vector2(1520, 760)
