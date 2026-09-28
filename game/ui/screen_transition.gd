class_name ScreenTransition
extends CanvasLayer
## One input-blocking curtain persists across the scene replacement. The new scene is ready before it is revealed.

static var busy := false


static func go(path: String) -> void:
	if busy:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if Settings.reduced_motion:
		tree.change_scene_to_file.call_deferred(path)
		return
	busy = true
	var transition := ScreenTransition.new()
	transition.layer = 120
	# LEARN: the boot scene may call this from _ready while root is still attaching its children.
	# Defer both operations in order: the curtain needs to be in the tree before it can tween.
	tree.root.add_child.call_deferred(transition)
	transition._run.call_deferred(path)


func _run(path: String) -> void:
	var tree := get_tree()
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
