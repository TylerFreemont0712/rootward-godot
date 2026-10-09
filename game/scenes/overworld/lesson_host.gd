class_name LessonHost
extends Control
## Lanternroot's lessons after the boots (ADR-0061): lesson 2 writes the player's own save, lesson 3 lights the lane.
## The overworld opens a lesson when a talk asks for it (a node with open "lesson:<id>"), and hears back through
## state_changed. Placeholder surface; the lessons work fills it in and keeps these names.

## The lesson changed the town (a flag, the player's saved memory, the lamps): the overworld saves it and redraws.
signal state_changed(state: Dictionary)
## The menu's Save finished: the state to keep, and what Hotaru says about it.
signal saved(state: Dictionary, message: String)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Opens lesson `id` ("memory", "lamps") over the town.
func open_lesson(_id: String, _state: Dictionary) -> void:
	pass


## True while a lesson's editor is open: the town does not walk under it.
func busy() -> bool:
	return visible


## Whether the menu's Save works yet: only once the player has written their own save (lesson 2).
static func can_save(state: Dictionary) -> bool:
	return bool((state.get("flags", {}) as Dictionary).get("memory-written", false))


## Saves with the player's own save program. Emits saved when done.
func save_now(state: Dictionary) -> void:
	saved.emit(state, "")


## The state as Continue starts it. Before lesson 2 the town keeps the player's place for them; after it, the place is
## what the player's own save kept.
static func restore(state: Dictionary) -> Dictionary:
	return state
