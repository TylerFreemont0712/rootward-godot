class_name StudioKeys
extends RefCounted
## The keyboard in Edit (Concept/v0.3/10, section 12): WASD pan, and the arrows pan too while nothing is selected and
## nudge the selection when something is. The rest do one thing as they go down: Del, F, R, E, O, Home, Tab, Esc and
## the Ctrl commands (undo, redo, duplicate, copy, paste, save the draft). F1 and F2 are the Studio's own. In the Land
## tab, B, R, G, 1, 2, 3, 5 and E choose its tools (see _land).

## The arrow keys, as the cells they nudge a selection by.
const NUDGES := {
	KEY_UP: Vector2i.UP,
	KEY_DOWN: Vector2i.DOWN,
	KEY_LEFT: Vector2i.LEFT,
	KEY_RIGHT: Vector2i.RIGHT,
}
const PAN_KEYS := {
	KEY_W: Vector2.UP,
	KEY_UP: Vector2.UP,
	KEY_S: Vector2.DOWN,
	KEY_DOWN: Vector2.DOWN,
	KEY_A: Vector2.LEFT,
	KEY_LEFT: Vector2.LEFT,
	KEY_D: Vector2.RIGHT,
	KEY_RIGHT: Vector2.RIGHT,
}

## The pan keys held now (key code -> bool), and whether Shift is down (a faster pan).
var held: Dictionary = {}
var fast := false

var _studio: StudioMode


func _init(studio: StudioMode) -> void:
	_studio = studio


## Handles a key while editing; true when it was the Studio's (and must not reach anything else).
func handle(key: InputEventKey) -> bool:
	fast = key.shift_pressed
	if _studio.text_editor_focused():
		return false
	if _studio.link.active:
		if PAN_KEYS.has(key.keycode) and not key.ctrl_pressed and not key.meta_pressed:
			held[key.keycode] = key.pressed
		elif key.pressed and not key.echo:
			if key.keycode == KEY_ESCAPE:
				_studio.link.cancel()
			elif key.keycode == KEY_O:
				_studio.studio_camera().toggle_overview()
			elif key.keycode == KEY_HOME:
				_studio.studio_camera().home(_studio.player().position)
		return true
	if _studio.tab == "quests":
		# The quest editor takes the keys (its own undo and redo); the town's do not reach a map no one is looking at.
		return _studio.quest_panel.key(key)
	if _studio.arrange.mode == "box":
		# LEARN: an unfinished rectangle is a preview. Editing its old selection here could move or delete unseen targets.
		if key.keycode == KEY_ESCAPE and key.pressed and not key.echo:
			_studio.arrange.cancel()
		elif PAN_KEYS.has(key.keycode) and not key.ctrl_pressed and not key.meta_pressed:
			held[key.keycode] = key.pressed
		return true
	if key.ctrl_pressed or key.meta_pressed:
		if _studio.link.active and key.keycode != KEY_S:
			# Undo, paste and the rest wait until the link is made or let go.
			return true
		return key.pressed and not key.echo and _command(key)
	if PAN_KEYS.has(key.keycode):
		if key.keycode == KEY_S and key.pressed and (not _studio.arrange.placing.is_empty() or _studio.arrange.area_select):
			_studio.start_select()
			return true
		# Arrows nudge what is selected, and pan when nothing is; WASD always pan.
		if key.keycode in NUDGES and key.pressed and not _studio.selected_sids().is_empty() and not _studio.link.active:
			if not key.echo:
				_studio.nudge(NUDGES[key.keycode] * (4 if key.shift_pressed else 1), key.alt_pressed)
		else:
			held[key.keycode] = key.pressed
		return true
	return key.pressed and not key.echo and _once(key.keycode)


## Ctrl+Z, Ctrl+Y and Ctrl+Shift+Z undo and redo, Ctrl+D duplicates, Ctrl+C and Ctrl+V copy and paste, Ctrl+S saves.
func _command(key: InputEventKey) -> bool:
	var work := _studio.work
	match key.keycode:
		KEY_Z:
			if key.shift_pressed:
				work.redo()
			else:
				work.undo()
		KEY_Y:
			work.redo()
		KEY_D:
			_studio.duplicate_selection()
		KEY_C:
			work.copy(_studio.selected_sids())
		KEY_V:
			_studio.paste_at_cursor(key.alt_pressed)
		KEY_S:
			work.flush()
		_:
			return false
	return true


## The Land tab's keys (Concept/v0.3/10, section 7.8): B brush, R rectangle, G fill, 1 2 3 5 the brush's size, E the
## ground under the cursor. True when the key was one of them.
func _land(code: Key) -> bool:
	match code:
		KEY_B:
			_studio.set_land_tool("brush")
		KEY_R:
			_studio.set_land_tool("rect")
		KEY_G:
			_studio.set_land_tool("fill")
		KEY_1, KEY_2, KEY_3, KEY_5:
			_studio.set_brush(int(OS.get_keycode_string(code)))
		KEY_E:
			_studio.set_ground(_studio.land.eyedrop())
		KEY_DELETE, KEY_F, KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_TAB:
			# The Objects tab's keys do nothing here, and do not reach anything else.
			pass
		_:
			return false
	return true


## The keys that do something once, as they go down. While a link is being made only Esc, O and Home do anything (the
## selection's keys would act on a map that is only being looked at).
func _once(code: Key) -> bool:
	if _studio.land_tab() and _land(code):
		return true
	if _studio.link.active and not code in [KEY_ESCAPE, KEY_O, KEY_HOME]:
		return code in [KEY_DELETE, KEY_F, KEY_R, KEY_E, KEY_TAB, KEY_BRACKETLEFT, KEY_BRACKETRIGHT]
	var work := _studio.work
	match code:
		KEY_Q:
			if not _studio.land_tab():
				_studio.start_area_select()
		KEY_O:
			_studio.studio_camera().toggle_overview()
		KEY_HOME:
			_studio.studio_camera().home(_studio.player().position)
		KEY_TAB:
			if _studio.stack().is_empty():
				var descriptor: Dictionary = StudioTopBar.DESCRIPTORS.get(_studio.tab, {})
				if (descriptor.get("tools", []) as Array).has("catalog"):
					_studio.set_place_list(not _studio.place_list_shown())
			else:
				_studio.cycle()
		KEY_DELETE:
			_studio.request_delete()
		KEY_F:
			work.flip(_studio.selected_sids())
		KEY_R:
			if not _studio.arrange.placing.is_empty():
				_studio.arrange.turn_placing()
			else:
				work.turn(_studio.selected_sids())
		KEY_E:
			_studio.eyedrop()
		KEY_BRACKETLEFT:
			if not _studio.arrange.placing.is_empty():
				_studio.arrange.cycle_variant(-1)
			else:
				work.swap_variant(_studio.selected_sids(), -1)
		KEY_BRACKETRIGHT:
			if not _studio.arrange.placing.is_empty():
				_studio.arrange.cycle_variant(1)
			else:
				work.swap_variant(_studio.selected_sids(), 1)
		KEY_ESCAPE:
			_escape()
		_:
			return false
	return true


## Esc lets go of the last thing started: placing, a drag, the selection, then Edit (Concept/v0.3/10, 7.1).
func _escape() -> void:
	var arrange := _studio.arrange
	if _studio.link.active:
		_studio.link.cancel()
	elif _studio.land.mode != "":
		_studio.land.cancel()
	elif not arrange.placing.is_empty():
		arrange.stop_placing()
	elif arrange.mode != "":
		arrange.cancel()
	elif arrange.area_select:
		_studio.start_select()
	elif not _studio.selected_sids().is_empty():
		_studio.select(-1)
	else:
		_studio.set_editing(false)
