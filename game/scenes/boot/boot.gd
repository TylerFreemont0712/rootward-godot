extends Control
## The first scene: loads what every screen shares (Game.boot), then hands over to the title. A screen that cannot
## start (broken content) says so on the title rather than here.


func _ready() -> void:
	theme = UiTheme.shared()
	var ground := ColorRect.new()
	ground.color = UiTheme.GROUND
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	var label := Ui.label("Lowering a lantern into the Salvage…", "Narration")
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(label)
	Game.boot()
	Game.go(Game.TITLE)
