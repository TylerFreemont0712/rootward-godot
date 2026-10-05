extends Control
## The first scene: loads what every screen shares (Game.boot), then hands over to the title. A screen that cannot
## start (broken content) says so on the title rather than here.


func _ready() -> void:
	theme = UiTheme.shared()
	var ground := ColorRect.new()
	ground.color = UiTheme.GROUND
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	# The profile, and so its language, is known once Game.boot has run; nothing is drawn before _ready returns.
	Game.boot()
	# The saved graphics device or renderer is not the one this run started with: start again with it (once).
	if Graphics.relaunch_if_needed():
		return
	var label := Ui.label(FoundryUi.text("Lowering a lantern into the Salvage…", "サルベージに、ランタンを下ろしているよ…"), "Narration")
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(label)
	Game.go(Game.TITLE)
