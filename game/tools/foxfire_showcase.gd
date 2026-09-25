extends Control
## A safe visual preview of Tamamo-no-Mae's rigged cast and separate ward effects.


func _ready() -> void:
	theme = UiTheme.shared()
	Settings.character_skin = "tamamo_no_mae"
	var stage := BattleStage.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	await get_tree().process_frame
	stage.set_backdrop("arena-throne")
	_showcase_loop(stage)


func _showcase_loop(stage: BattleStage) -> void:
	while is_inside_tree():
		stage.hero.play("cast-heavy")
		stage.cast_flash("spark", true)
		await get_tree().create_timer(0.38).timeout
		if not is_inside_tree():
			return
		stage.ward_glow()
		await get_tree().create_timer(0.9).timeout
		if not is_inside_tree():
			return
		stage.hero.play("idle-breathe")
		await get_tree().create_timer(0.42).timeout
