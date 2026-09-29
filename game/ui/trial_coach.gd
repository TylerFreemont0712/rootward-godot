class_name TrialCoach
extends Control
## The coach reads the current saved step. Only session events move the lesson forward.

signal wants(command: Dictionary)
signal skipped

var _content: Dictionary = {}
var _state: Dictionary = {}
var _target: Control
var _panel: PanelContainer
var _step_id := ""
var _review := -1
var _compact := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = "Overlay"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_compact = DisplayServer.window_get_size().x < 1100
	_content = TrialContent.load_trial(String(Game.profile.get("preferred_language", "en"))).get("value", {})
	resized.connect(_place)


func show_step(state: Dictionary, target: Control) -> void:
	_state = state
	_target = target
	var id := String(state.get("trial", {}).get("step_id", ""))
	if id != _step_id:
		_step_id = id
		_review = -1
		Sound.play("sfx-card-place", 0.25)
		_render()
	_place()
	queue_redraw()


func _render() -> void:
	Ui.clear(_panel)
	var steps: Array = _content.get("steps", [])
	var index := 0
	for i in steps.size():
		if steps[i].id == _step_id:
			index = i
			break
	var shown: Dictionary = steps[clampi(_review if _review >= 0 else index, 0, steps.size() - 1)]
	var chapter := TrialContent.chapter(_content, String(shown.chapter))
	var first: bool = index == 0 or steps[index - 1].chapter != shown.chapter
	var japanese: bool = Game.profile.get("preferred_language", "en") == "ja"
	var line := Ui.label(String(shown.say), "Narration", true)
	line.custom_minimum_size.x = 820 if _compact else 340
	if _compact:
		Ui.sized(line, 30)
	Ui.tint(line, UiTheme.TEXT)
	var mood := String(shown.get("mood", chapter.get("mood", "neutral")))
	var faces := {"neutral": "◈", "excited": "✦", "worried": "◇", "proud": "★"}
	var portrait := Ui.picture("sprites/pip/" + mood, Vector2(64, 64), faces.get(mood, "◈"))
	portrait.tooltip_text = "Pip · " + mood
	if portrait is Label:
		Ui.sized(portrait, 36)
		Ui.tint(portrait, UiTheme.AMBER if mood in ["excited", "proud"] else UiTheme.TEAL)
	var chapter_title := Ui.label(String(chapter.get("title", "")), "Subheading", true)
	if _compact:
		Ui.sized(chapter_title, 30)
	var title := Ui.vbox([Ui.label("PIP", "Faint"), chapter_title], 3)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := Ui.hbox([portrait, title], 12)
	var body := Ui.vbox([heading], 8)
	if first:
		var scene := Ui.label(String(chapter.get("scene", "")), "Muted", true)
		if _compact:
			Ui.sized(scene, 25)
		body.add_child(Ui.tint(scene, UiTheme.AMBER))
	# LEARN: showing the previous step's code line keeps the "real code" beat after the action that proved it.
	var completed: Array = _state.get("trial", {}).get("completed", [])
	if index > 0 and steps[index - 1].id in completed and _review < 0:
		var previous_code := Ui.label(String(steps[index - 1].code), "Muted", true)
		if _compact:
			Ui.sized(previous_code, 25)
		body.add_child(Ui.tint(previous_code, UiTheme.TEAL))
	body.add_child(line)
	if _review >= 0 or _state.get("trial", {}).get("done", false):
		var code := Ui.label(String(shown.code), "Muted", true)
		if _compact:
			Ui.sized(code, 25)
		body.add_child(Ui.tint(code, UiTheme.TEAL))
	var hint := String(_state.get("trial", {}).get("hint", ""))
	if hint != "":
		if japanese:
			hint = String(_content.get("loss_hint", hint))
		var reminder := Ui.label("Pip: " + hint, "Muted", true)
		if _compact:
			Ui.sized(reminder, 25)
		body.add_child(Ui.tint(reminder, UiTheme.WARN))
	var controls := Ui.hbox([], 6)
	var finished: bool = _state.get("trial", {}).get("done", false)
	var back := Ui.button("‹ " + ("もどる" if japanese else "Back"), _back)
	back.disabled = index == 0 and _review < 0
	controls.add_child(back)
	controls.add_child(Ui.button("↻ " + ("もう一度" if japanese else "Say that again"), _again))
	if finished:
		controls.add_child(
			Ui.button("タイトルへ" if japanese else "Return to title", func() -> void: Game.go(Game.TITLE), "PrimaryButton")
		)
	elif _review >= 0:
		controls.add_child(Ui.button("› " + ("つづける" if japanese else "Current step"), _again, "PrimaryButton"))
	elif shown.event == "coach-next":
		controls.add_child(Ui.button("› " + ("つぎへ" if japanese else "Next"), _next, "PrimaryButton"))
	else:
		controls.add_child(Ui.tint(Ui.label("やってみよう" if japanese else "Your turn", "Faint"), UiTheme.AMBER))
	if not finished:
		controls.add_child(Ui.button("× " + ("スキップ" if japanese else "Skip"), func() -> void: skipped.emit()))
	if _compact:
		for button: Node in controls.get_children():
			if button is Button:
				Ui.sized(button, 24)
	body.add_child(controls)
	_panel.add_child(body)
	_place()


func _back() -> void:
	var steps: Array = _content.steps
	var index := 0
	for i in steps.size():
		if steps[i].id == _step_id:
			index = i
			break
	_review = maxi(0, index - 1) if _review < 0 else maxi(0, _review - 1)
	_render()


func _again() -> void:
	_review = -1
	Sound.play("sfx-card-place", 0.35)
	_render()


func _next() -> void:
	wants.emit({"type": "trial-next"})


func _process(_delta: float) -> void:
	_place()
	queue_redraw()


func _place() -> void:
	if _panel == null or _panel.get_child_count() == 0:
		return
	var width := minf(990.0 if _compact else 470.0, maxf(320.0, size.x - 24.0))
	_panel.custom_minimum_size.x = width
	_panel.size = Vector2(width, _panel.get_combined_minimum_size().y)
	var rect := Rect2()
	if is_instance_valid(_target) and _target.is_inside_tree():
		rect = _target.get_global_rect()
		rect.position -= global_position
	var x_left := 16.0
	var x_right := maxf(16.0, size.x - width - 16.0)
	var y_top := 80.0
	var y_bottom := maxf(80.0, size.y - _panel.size.y - 16.0)
	var candidates := [
		Vector2(x_right, y_top), Vector2(x_left, y_top), Vector2(x_right, y_bottom), Vector2(x_left, y_bottom)
	]
	var best: Vector2 = candidates[0]
	var smallest := INF
	for candidate: Vector2 in candidates:
		var overlap := Rect2(candidate, _panel.size).intersection(rect.grow(18))
		var area := overlap.get_area()
		if area < smallest:
			smallest = area
			best = candidate
	_panel.position = best


func _draw() -> void:
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		return
	var rect := _target.get_global_rect()
	rect.position -= global_position
	if rect.size.x > 0 and rect.size.y > 0:
		draw_rect(rect.grow(5), Color(UiTheme.AMBER, 0.9), false, 3.0)
