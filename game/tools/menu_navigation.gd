extends SceneTree
## Real mouse clicks and scene handoffs in isolated saves. Run with scripts/menu-navigation.sh.

var _clicks := 0


func _initialize() -> void:
	_walk.call_deferred()


func _walk() -> void:
	var saves := "user://menu-navigation-saves/%d" % OS.get_process_id()
	Game.reset(saves)
	Game.boot()
	Settings.path = saves + "/settings.json"
	Settings.fullscreen = false
	Settings.apply_display()
	Game.profile.name = "Navigation Tester"
	Game.profile.needs_name = false
	Game.profile.preferred_language = "en"
	Game.profile.avatar = "vesper"
	Game.profile.tutorial = {}
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	Game.use("program")
	change_scene_to_file(Game.TITLE)
	await _settle()
	if OS.get_environment("ROOTWARD_NAVIGATION_QUIT") == "1":
		await _click("Quit")
		return
	for reduced: bool in [false, true]:
		Settings.reduced_motion = reduced
		for label: String in ["日本語", "EN", "日本語", "EN"]:
			await _click(label)
		for label: String in ["Character", "Library", "Settings", "Academy", "Navigation Tester"]:
			await _click(label)
			if label == "Character":
				await _click("Artificer")
				await _click("›")
				await _click("‹")
			await _click("Back")
		await _click("Settings")
		for label: String in ["Audio", "Spell playback", "Display"]:
			await _click(label)
		await _click("Back")
		await _click("Library")
		for label: String in ["Creatures", "Relics", "Concepts", "Shards", "Spellforge", "Shardrun"]:
			await _click(label)
		await _click("Back")
		for label: String in ["New player", "Rename", "Delete"]:
			await _click("Navigation Tester")
			await _click(label)
			await _click("Keep player" if label == "Delete" else "Cancel")
		await _click("Navigation Tester")
		await _click("Navigation Tester")
		await _expect_scene(Game.TITLE)
		await _click("Adventure")
		for label: String in ["Records", "Field guide", "Artificer"]:
			await _click(label)
			if label == "Records":
				for filter: String in ["Completed", "Lost", "Retired", "All journeys"]:
					await _click(filter)
				await _click("Commit log")
				await _click("Close")
			else:
				await _click("Back")
		await _click("Back")
		# A real scene replacement must leave the new scene ready and the curtain unlocked.
		Game.profile.tutorial = {"trial_prompted": true}
		Game.profiles.save_profile(Game.profile)
		await _click("Adventure")
		await _click("Begin a new descent")
		if _button("Start anew") != null:
			await _click("Start anew")
		await _expect_scene(Game.SHARDRUN)
		await _return_from_run()
		await _click("↓  Resume descent")
		await _expect_scene(Game.SHARDRUN)
		await _return_from_run()
		await _click("Adventure")
		await _click("Continue Pip's travels" if _button("Continue Pip's travels") != null else "Pip's travels")
		await _expect_scene(Game.SHARDRUN)
		await _return_from_run()
		await _click("Academy")
		await _click("Open existing Verifier course")
		await _expect_scene(Game.VERIFIER)
		await _click("← Title")
		await _expect_scene(Game.TITLE)
	var output := OS.get_environment("ROOTWARD_NAVIGATION_SHOT")
	if output != "":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		root.get_texture().get_image().save_png(output)
	print("Menu navigation passed: %d actual mouse clicks, animated and reduced-motion scene handoffs." % _clicks)
	Background.finish_all()
	quit(0)


func _return_from_run() -> void:
	await _click("Menu")
	await _click("Return to title")
	await _expect_scene(Game.TITLE)


func _button(label: String) -> Button:
	var scope := current_scene
	if current_scene.scene_file_path == Game.TITLE:
		var overlay := current_scene.get("_overlay") as Control
		if overlay.get_child_count() > 0:
			scope = overlay
	for child: Node in scope.find_children("*", "Button", true, false):
		var button := child as Button
		if button.text == label and button.is_visible_in_tree():
			return button
	return null


func _click(label: String) -> void:
	await process_frame
	var button := _button(label)
	if button == null or button.disabled:
		_fail("Missing or disabled button: " + label)
		return
	var received := [false]
	button.pressed.connect(func() -> void: received[0] = true, CONNECT_ONE_SHOT)
	var point := button.get_global_rect().get_center()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event, true)
	if not received[0]:
		_fail("Mouse click did not reach: " + label)
		return
	_clicks += 1
	print("Clicked: " + label)
	await _settle()


func _expect_scene(path: String) -> void:
	await _settle()
	if current_scene == null or current_scene.scene_file_path != path or ScreenTransition.busy:
		_fail("Scene handoff failed: " + path)


func _settle() -> void:
	await create_timer(0.55).timeout
	await process_frame
	await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
