extends Control
## The move cards' pictures (ADR-0037): each move of the cosmetic catalogue on the motion dummy at its telling moment
## (a cast at its release, an idle mid-breath), as the stage shows it, saved with a clear background to
## assets/menus/moves/<clip>.png. Run after changing a move:
##   scripts/screenshot.sh res://tools/move_thumbs.tscn shots/move-thumbs.png 10

signal shot_ready

const OUT := "res://assets/menus/moves/"
const SIZE := Vector2i(300, 300)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var moves: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(StageCharacter.MOVES_META)).clips
	var row := HBoxContainer.new()
	add_child(row)
	for slot: String in CosmeticRules.NATIVE:
		for option in Cosmetics.options(slot):
			var clip := String(option.clip)
			var facts: Dictionary = moves.get(clip, {})
			var release: Variant = facts.get("release")
			var at := float(release) if release != null else float(facts.get("length", 1.0)) * 0.3
			at = float(option.get("thumb", at))
			var view := HeroView.new()
			view.preview_skin = "dummy"
			view.custom_minimum_size = Vector2(SIZE)
			row.add_child(view)
			await get_tree().process_frame
			var hero := view.character
			# Framed closer than on the stage: the card is small, the pose is the point.
			view._camera.size = hero.stature() / 0.9
			view._camera.position.y = view._camera.size * 0.5 - 0.03
			hero.player.play(clip, 0.0)
			hero.player.seek(at + 0.04, true)
			hero.player.pause()
			for i in 8:
				await get_tree().process_frame
			var image := view._viewport.get_texture().get_image()
			image.save_png(ProjectSettings.globalize_path(OUT + clip + ".png"))
			print("move thumb: ", clip, " at ", at)
	set_meta("shot_ready", true)
	shot_ready.emit()
