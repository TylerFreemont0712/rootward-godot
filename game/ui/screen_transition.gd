class_name ScreenTransition
extends CanvasLayer
## One input-blocking curtain persists across the scene replacement. The new scene is ready before it is revealed.

static var busy := false

var _sigil := false


## `sigil` swaps the scene under the sigil veil the title's library, character and settings rooms use, instead of the
## plain curtain.
static func go(path: String, sigil := false) -> void:
	if busy:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if Settings.reduced_motion:
		tree.change_scene_to_file.call_deferred(path)
		return
	busy = true
	var transition := ScreenTransition.new()
	transition.layer = 120
	transition._sigil = sigil
	# LEARN: the boot scene may call this from _ready while root is still attaching its children.
	# Defer both operations in order: the curtain needs to be in the tree before it can tween.
	tree.root.add_child.call_deferred(transition)
	transition._run.call_deferred(path)


func _run(path: String) -> void:
	var tree := get_tree()
	if _sigil:
		await _run_sigil(path)
		return
	var curtain := ColorRect.new()
	curtain.color = Color(0.025, 0.018, 0.04, 0.0)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(curtain)
	await create_tween().tween_property(curtain, "color:a", 1.0, 0.18).finished
	var error := tree.change_scene_to_file(path)
	if error != OK:
		push_error("Cannot open scene: " + path)
	await tree.process_frame
	await tree.process_frame
	await create_tween().tween_property(curtain, "color:a", 0.0, 0.26).finished
	busy = false
	queue_free()


# The veil is opaque at its midpoint: the new scene replaces the old one there and the second half reveals it.
func _run_sigil(path: String) -> void:
	var tree := get_tree()
	var veil := ArchivePassage.new()
	add_child(veil)
	veil.cover_viewport()
	veil.grab_focus()
	veil.midpoint.connect(
		func() -> void:
			if tree.change_scene_to_file(path) != OK:
				push_error("Cannot open scene: " + path),
		CONNECT_ONE_SHOT
	)
	veil.play()
	await veil.finished
	busy = false
	queue_free()
