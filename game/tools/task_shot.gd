extends Control
## Moments of v0.4's task editor, the Workbench and the part banner, for screenshots (Concept/v0.4):
##   ROOTWARD_TASK_SHOT=<moment> scripts/screenshot.sh res://tools/task_shot.tscn shots/v04/task.png 60
## Moments:
##   blocks         the Builder on shortcuts stage 2: the menu's switch on, the bag's off (dimmed)
##   blocks-js      the same in JavaScript
##   code           a Scribe on stage 1 with the Hints open
##   fail           the Builder, tried with the wrong key for the bag
##   pass           the Builder, tried with the right ones
##   code-broken    a Scribe whose code cannot run, tried
##   workbench      the Workbench with a few parts built
##   workbench-open the same with a built part chosen
##   banner         the part-built banner
## The scenes are instanced on their own in a save folder of their own; `shot_ready` says when the moment is set.

signal shot_ready

const SCRIBBLED := 'def shortcut(key):\n    if key == "escape":\n        return "menu"\n    return None\n'
const BROKEN := 'def shortcut(key):\n    if key == "escape"\n        return "menu"\n    return None\n'


func _ready() -> void:
	var moment := OS.get_environment("ROOTWARD_TASK_SHOT")
	if moment == "":
		moment = "blocks"
	Game.reset("user://task-shot-saves/" + moment)
	Game.boot()
	Game.profile.preferred_language = "en"
	var catalog: Dictionary = OverworldContent.load_world().catalog
	var state := _state()
	if moment.begins_with("workbench"):
		await _workbench(catalog, state, moment)
	elif moment == "banner":
		await _banner()
	else:
		await _editor(catalog, state, moment)
	shot_ready.emit()


func _state() -> Dictionary:
	var state := OverworldState.fresh("lanternroot", Vector2i(18, 8), "right", "python")
	state.name = "Tinker"
	return state


func _editor(catalog: Dictionary, state: Dictionary, moment: String) -> void:
	var editor := TaskEditor.new()
	add_child(editor)
	editor.setup(catalog)
	var task: Dictionary = catalog.tasks.shortcuts
	var record := {"mode": "blocks", "blocks": {"slots": {"menu_key": 1, "menu_panel": 1, "bag_key": 0}, "toggles": ["menu"]}}
	var at := 1
	if moment == "blocks-js":
		state.language = "javascript"
	if moment == "fail":
		record.blocks.toggles = ["menu", "bag"]
	if moment == "pass":
		record.blocks = {"slots": {"menu_key": 1, "menu_panel": 1, "bag_key": 2}, "toggles": ["menu", "bag"]}
	if moment.begins_with("code"):
		CodeHints.remembered_open = moment == "code"
		record = {"mode": "code", "code": {"python": BROKEN if moment == "code-broken" else SCRIBBLED}}
		at = 0 if moment == "code" else 1
	editor.open(task, at, record, state)
	await _frames(20)
	if moment in ["fail", "pass", "code-broken"]:
		await editor.try_it()
	await _frames(20)


func _workbench(catalog: Dictionary, state: Dictionary, moment: String) -> void:
	state.flags = {"all-ways": true, "memory-written": true, "menu-built": true}
	state.tasks = {
		"shortcuts": {"passed": 1, "source": 'def shortcut(key):\n    if key == "escape":\n        return "menu"\n    return None\n', "source_language": "python"},
		"menu": {"passed": 1, "source": "def menu_items(built):\n    return [\"continue\"] + built + [\"quit\"]\n", "source_language": "python"},
	}
	state.lessons = {"memory": {"blocks": ["x", "y", "map"], "passed": true, "source": "", "language": "python"}}
	var panel := WorkbenchPanel.new()
	add_child(panel)
	panel.open(catalog, state)
	await _frames(30)
	if moment == "workbench-open":
		panel.choose("menu")
		await _frames(10)


func _banner() -> void:
	var banner := PartBanner.new()
	add_child(banner)
	banner.hold_time = 60.0
	banner.show_part("The Menu", "Esc opens your menu now.")
	await get_tree().create_timer(1.2).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
