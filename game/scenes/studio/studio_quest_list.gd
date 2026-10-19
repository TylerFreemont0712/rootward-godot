class_name StudioQuestList
extends HBoxContainer
## The quest editor's Quests view (Concept/v0.3/10, S9): the quests in order on the left, with what state each is in,
## and the chosen quest on the right: title, summary, giver, the quests it waits for, and its steps (text, hint, the
## done condition, the pin on the map). Every change is one command on the "quests" doc, so Undo takes it back.
##
## The methods are what the buttons do, so a test can press them as a player would: add_quest, move_quest,
## remove_quest, add_step, move_step, remove_step, set_after, set_step.

const KEY := "quests"

## The quest chosen, and the step the editor was sent to (-1: none), which is shown with an amber edge.
var chosen := ""
var step_marked := -1

var _studio: StudioMode
var _work: StudioQuestWork
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _detail: VBoxContainer
var _detail_scroll: ScrollContainer
var _new_id: LineEdit
var _move_up: Button
var _move_down: Button
var _remove: Button
var _marked_card: Control


func _init(studio: StudioMode) -> void:
	_studio = studio
	_work = studio.quests
	name = "QuestList"
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := Ui.vbox([], 6)
	left.custom_minimum_size.x = 360
	left.add_child(StudioQuestUi.heading(StudioText.t("quests_list")))
	_list = Ui.vbox([], 4)
	_list_scroll = Ui.scroll(_list)
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_list_scroll)
	_new_id = StudioQuestUi.line("", func(_text: String) -> void: pass, "quests.new_id", StudioText.t("quests_new_id"))
	_new_id.name = "NewQuestId"
	left.add_child(Ui.hbox([_new_id, StudioQuestUi.button(StudioText.t("quests_add"), func() -> void: add_quest(_new_id.text.strip_edges()), "AddQuest", StudioText.t("quests_add_tip"))], 6))
	_move_up = StudioQuestUi.button(StudioText.t("move_up"), func() -> void: move_quest(-1), "MoveQuestUp", StudioText.t("quests_move_tip"))
	_move_down = StudioQuestUi.button(StudioText.t("move_down"), func() -> void: move_quest(1), "MoveQuestDown", StudioText.t("quests_move_tip"))
	_remove = StudioQuestUi.button(StudioText.t("quests_remove"), func() -> void: remove_quest(), "RemoveQuest", StudioText.t("quests_remove_tip"))
	left.add_child(Ui.hbox([_move_up, _move_down, Ui.spacer(), _remove], 6))
	add_child(left)
	add_child(VSeparator.new())
	_detail = Ui.vbox([], 8)
	_detail_scroll = Ui.scroll(_detail)
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_detail_scroll)


# --- what the quests are ----------------------------------------------------------------------------------------------


func quests() -> Dictionary:
	return _work.data(KEY)


## The steps of the chosen quest as the doc has them now.
func steps() -> Array:
	return (quests().get(chosen, {}) as Dictionary).get("steps", []) as Array


func _flags_now() -> Dictionary:
	var state: Variant = _studio.parts().get("state")
	if state is Callable:
		return ((state as Callable).call() as Dictionary).get("flags", {})
	return {}


## "open", "done", or "locked: after boots" for a quest.
func status_words(id: String) -> String:
	var all := quests()
	var flags := _flags_now()
	var status := Quests.status(all, id, flags)
	if status == Quests.LOCKED:
		var waiting: Array[String] = []
		for before: Variant in (all.get(id, {}) as Dictionary).get("after", []):
			if not all.has(String(before)) or Quests.status(all, String(before), flags) != Quests.DONE:
				waiting.append(String(before))
		return StudioText.t("quest_locked") % ", ".join(waiting)
	return StudioText.t("quest_done" if status == Quests.DONE else "quest_open")


# --- what the buttons do ---------------------------------------------------------------------------------------------


func choose(id: String, step := -1) -> void:
	StudioQuestUi.settle(self)
	chosen = id
	step_marked = step
	rebuild()


func _do(command: Dictionary) -> bool:
	if command.is_empty():
		return false
	return bool(_work.do(KEY, command).get("ok", false))


## A new quest, after the last one; `id` empty makes "new-quest". False when the id is taken or not an id.
func add_quest(id := "") -> bool:
	StudioQuestUi.settle(self)
	var all := quests()
	var wanted := id if id != "" else StudioQuestEdit.fresh_id("new-quest", all.keys())
	if not StudioQuestEdit.is_id(wanted) or all.has(wanted):
		_studio.say(StudioText.t("quest_bad_id") % wanted, true)
		return false
	var order := 0
	for other: String in all:
		order = maxi(order, int((all[other] as Dictionary).get("order", 0)))
	var ordered := Quests.ordered(all)
	var after: Array = [ordered.back()] if not ordered.is_empty() else []
	var quest := {
		"order": order + 1, "after": after, "title": StudioText.t("quest_new_title"), "giver": "hotaru", "summary": "",
		"steps": [{"text": StudioText.t("quest_new_step"), "done": {"flag": ""}}],
	}
	if not _do({"type": "set_at", "path": [wanted], "value": quest}):
		return false
	_new_id.text = ""
	chosen = wanted
	step_marked = -1
	return true


## The chosen quest moves up (-1) or down (1) in the order: the orders of the quests are made 1, 2, 3 in the new order.
func move_quest(by: int) -> bool:
	StudioQuestUi.settle(self)
	var ids := Quests.ordered(quests())
	var at := ids.find(chosen)
	var to := at + by
	if at < 0 or to < 0 or to >= ids.size():
		return false
	ids.remove_at(at)
	ids.insert(to, chosen)
	var commands: Array = []
	for i: int in ids.size():
		commands.append(StudioQuestEdit.set_value(quests(), [ids[i], "order"], i + 1))
	return _do(StudioQuestEdit.batch(StudioText.t("quest_move_name"), commands))


## The chosen quest goes, and no other quest waits for it any more.
func remove_quest() -> bool:
	StudioQuestUi.settle(self)
	var all := quests()
	if not all.has(chosen) or all.size() <= 1:
		return false
	var commands: Array = []
	for other: String in all:
		var after: Array = (all[other] as Dictionary).get("after", [])
		if other != chosen and chosen in after:
			var kept := after.duplicate()
			kept.erase(chosen)
			commands.append(StudioQuestEdit.set_value(all, [other, "after"], kept))
	commands.append(StudioQuestEdit.set_value(all, [chosen], null))
	var ordered := Quests.ordered(all)
	var at := ordered.find(chosen)
	var next := ordered[at - 1] if at > 0 else ordered[1]
	if not _do(StudioQuestEdit.batch(StudioText.t("quest_remove_name"), commands)):
		return false
	chosen = next
	step_marked = -1
	return true


## A field of the chosen quest: "title", "summary", "giver" (empty erases it).
func set_field(key: String, value: String) -> bool:
	var erased := key == "giver" and value == ""
	return _do(StudioQuestEdit.set_value(quests(), [chosen, key], null if erased else value))


## Whether the chosen quest waits for another (`after`).
func set_after(other: String, on: bool) -> bool:
	StudioQuestUi.settle(self)
	var after: Array = ((quests().get(chosen, {}) as Dictionary).get("after", []) as Array).duplicate()
	if on and not other in after:
		after.append(other)
	elif not on:
		after.erase(other)
	return _do(StudioQuestEdit.set_value(quests(), [chosen, "after"], after))


## A step added at the end of the chosen quest: `step` is its first words ({} makes a step that waits for no flag yet).
func add_step(step := {}) -> int:
	StudioQuestUi.settle(self)
	var made: Dictionary = step if not step.is_empty() else {"text": StudioText.t("quest_new_step"), "done": {"flag": ""}}
	if not _do(StudioQuestEdit.add_item(quests(), [chosen, "steps"], made)):
		return -1
	step_marked = steps().size() - 1
	return step_marked


## A field of a step: "text", "hint" (empty erases it), "done" (a condition), "at" (a pin, or null).
func set_step(index: int, key: String, value: Variant) -> bool:
	var erased := value == null or (key == "hint" and String(value) == "")
	return _do(StudioQuestEdit.set_value(quests(), [chosen, "steps", index, key], null if erased else value))


func move_step(index: int, by: int) -> bool:
	StudioQuestUi.settle(self)
	var moved := _do(StudioQuestEdit.move_item(quests(), [chosen, "steps"], index, index + by))
	if moved:
		step_marked = index + by
	return moved


func remove_step(index: int) -> bool:
	StudioQuestUi.settle(self)
	if steps().size() <= 1:
		return false
	step_marked = -1
	return _do(StudioQuestEdit.remove_item([chosen, "steps"], index))


# --- drawing ---------------------------------------------------------------------------------------------------------


## The list and the chosen quest, built again from the doc (the text box being typed in keeps its focus).
func rebuild() -> void:
	var all := quests()
	if not all.has(chosen):
		var ordered := Quests.ordered(all)
		chosen = ordered[0] if not ordered.is_empty() else ""
		step_marked = -1
	var saved := StudioQuestUi.remember(self)
	var list_scroll := _list_scroll.scroll_vertical
	var detail_scroll := _detail_scroll.scroll_vertical
	StudioQuestUi.clear(_list)
	StudioQuestUi.clear(_detail)
	_marked_card = null
	_build_list(all)
	if all.has(chosen):
		_build_detail(all)
	else:
		_detail.add_child(StudioStyle.line(StudioText.t("quests_none"), UiTheme.MUTED))
	var ids := Quests.ordered(all)
	var at := ids.find(chosen)
	_move_up.disabled = at <= 0
	_move_down.disabled = at < 0 or at >= ids.size() - 1
	_remove.disabled = at < 0 or ids.size() <= 1
	StudioQuestUi.restore(self, saved)
	if _marked_card != null:
		StudioQuestUi.show_control(_detail_scroll, _marked_card)
	else:
		StudioQuestUi.keep_scroll(_detail_scroll, detail_scroll)
	StudioQuestUi.keep_scroll(_list_scroll, list_scroll)


func _build_list(all: Dictionary) -> void:
	for id: String in Quests.ordered(all):
		var quest: Dictionary = all[id]
		var title := String(quest.get("title", id))
		var pick := StudioStyle.button("%d   %s" % [int(quest.get("order", 0)), title], func() -> void: choose(id), id == chosen)
		pick.name = "Quest_" + id
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.clip_text = true
		var steps_in: Array = quest.get("steps", [])
		var words := StudioText.t("quest_status_line") % [status_words(id), steps_in.size()]
		var status := StudioStyle.caption(words)
		status.name = "Status_" + id
		_list.add_child(Ui.vbox([pick, Ui.hbox([Ui.spacer(14, 0), status], 0)], 0))


func _build_detail(all: Dictionary) -> void:
	var quest: Dictionary = all[chosen]
	var flags := StudioQuestUi.flag_names(_work)
	_detail.add_child(Ui.hbox([StudioQuestUi.heading(String(quest.get("title", chosen))), StudioStyle.caption(chosen)], 10))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := StudioQuestUi.line(String(quest.get("title", "")), func(text: String) -> void: set_field("title", text), "q.title")
	title.name = "QuestTitle"
	grid.add_child(StudioQuestUi.field_name(StudioText.t("quest_title")))
	grid.add_child(title)
	var summary := StudioQuestUi.area(String(quest.get("summary", "")), func(text: String) -> void: set_field("summary", text), "q.summary", 2)
	summary.name = "QuestSummary"
	grid.add_child(StudioQuestUi.field_name(StudioText.t("quest_summary")))
	grid.add_child(summary)
	var people := StudioQuestUi.people(_studio)
	var labels: Array[String] = []
	for person: String in people:
		labels.append(_person_label(person))
	var giver := StudioQuestUi.choice(people, labels, String(quest.get("giver", "")), func(picked: String) -> void: set_field("giver", picked), "q.giver")
	giver.name = "QuestGiver"
	giver.custom_minimum_size.x = 220
	grid.add_child(StudioQuestUi.field_name(StudioText.t("quest_giver")))
	grid.add_child(Ui.hbox([giver], 0))
	var waits := Ui.flow([], 12)
	var after: Array = quest.get("after", [])
	for other: String in Quests.ordered(all):
		if other == chosen:
			continue
		var box := CheckBox.new()
		box.text = String((all[other] as Dictionary).get("title", other))
		box.name = "After_" + other
		box.focus_mode = Control.FOCUS_NONE
		box.add_theme_font_size_override("font_size", StudioStyle.SMALL)
		box.set_pressed_no_signal(other in after)
		box.toggled.connect(func(on: bool) -> void: set_after(other, on))
		waits.add_child(box)
	for other: Variant in after:
		if not all.has(String(other)):
			waits.add_child(StudioStyle.line(StudioText.t("quest_missing") % String(other), UiTheme.FAIL))
	grid.add_child(StudioQuestUi.field_name(StudioText.t("quest_after")))
	grid.add_child(waits)
	_detail.add_child(grid)
	_detail.add_child(StudioStyle.rule())
	_detail.add_child(StudioQuestUi.heading(StudioText.t("quest_steps")))
	var steps_in: Array = quest.get("steps", [])
	for i: int in steps_in.size():
		_detail.add_child(_step_card(i, steps_in[i] as Dictionary, flags, steps_in.size()))
	var add := StudioQuestUi.button(StudioText.t("quest_add_step"), func() -> void: add_step(), "AddStep", StudioText.t("quest_add_step_tip"))
	_detail.add_child(Ui.hbox([add], 0))
	var problems := Quests.problems(all)
	for problem: String in problems:
		_detail.add_child(StudioStyle.line(problem, UiTheme.FAIL))


func _person_label(id: String) -> String:
	if id == "":
		return StudioText.t("nobody")
	var folk: Dictionary = _studio.catalog().get("townsfolk", {})
	if folk.has(id):
		return "%s (%s)" % [String((folk[id] as Dictionary).get("name", id)), id]
	return id if id != "hotaru" else StudioText.t("hotaru")


func _step_card(i: int, step: Dictionary, flags: Array[String], count: int) -> Control:
	var fid := "step.%d" % i
	var number := StudioStyle.line(str(i + 1), UiTheme.AMBER)
	number.custom_minimum_size.x = 22
	var text := StudioQuestUi.line(String(step.get("text", "")), func(value: String) -> void: set_step(i, "text", value), fid + ".text", StudioText.t("quest_step_text"))
	text.name = "StepText%d" % i
	var up := StudioQuestUi.button(StudioText.t("move_up"), func() -> void: move_step(i, -1), "StepUp%d" % i)
	up.disabled = i == 0
	var down := StudioQuestUi.button(StudioText.t("move_down"), func() -> void: move_step(i, 1), "StepDown%d" % i)
	down.disabled = i >= count - 1
	var remove := StudioQuestUi.button(StudioText.t("quest_remove_step"), func() -> void: remove_step(i), "StepRemove%d" % i, StudioText.t("quest_remove_step_tip"))
	remove.disabled = count <= 1
	var head := Ui.hbox([number, text, up, down, remove], 6)
	var hint := StudioQuestUi.line(String(step.get("hint", "")), func(value: String) -> void: set_step(i, "hint", value), fid + ".hint", StudioText.t("quest_hint_hint"))
	hint.name = "StepHint%d" % i
	var done_now := func() -> Variant: return (steps()[i] as Dictionary).get("done", {}) if i < steps().size() else {}
	var done := StudioConditionEditor.build(done_now, flags, func(next: Dictionary) -> void: set_step(i, "done", next), fid + ".done")
	done.name = "StepDone%d" % i
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	grid.add_child(StudioQuestUi.field_name(StudioText.t("quest_hint")))
	grid.add_child(hint)
	grid.add_child(StudioQuestUi.field_name(StudioText.t("quest_done_when")))
	var words := StudioQuests.condition_text(step.get("done", {}))
	var summary := StudioStyle.line(StudioText.t("quest_never_done") if StudioQuests.flags_read(step.get("done", {})).is_empty() else words, UiTheme.FAIL if StudioQuests.flags_read(step.get("done", {})).is_empty() else UiTheme.MUTED)
	summary.name = "StepWords%d" % i
	# A single flag says itself; the words are for the conditions that are more than that.
	var plain := StudioConditionEditor.kind_of(step.get("done", {})) in [StudioConditionEditor.FLAG, StudioConditionEditor.NOT]
	summary.visible = not plain or StudioQuests.flags_read(step.get("done", {})).is_empty()
	grid.add_child(Ui.vbox([done, summary], 2))
	grid.add_child(StudioQuestUi.field_name(StudioText.t("quest_pin")))
	grid.add_child(_pin_row(i, step))
	var card := StudioQuestUi.card(Ui.vbox([head, grid], 8), i == step_marked)
	card.name = "Step%d" % i
	if i == step_marked:
		_marked_card = card
	return card


## The pin of a step: a map and a cell, or none.
func _pin_row(i: int, step: Dictionary) -> Control:
	var pin: Dictionary = step.get("at", {}) if step.get("at", {}) is Dictionary else {}
	var maps: Array[String] = [""]
	var labels: Array[String] = [StudioText.t("quest_no_pin")]
	var map_ids: Array = _studio.catalog().get("maps", {}).keys()
	map_ids.sort()
	for id: String in map_ids:
		maps.append(id)
		labels.append(id)
	var pick := func(map_id: String) -> void:
		if map_id == "":
			set_step(i, "at", null)
			return
		var cell_now: Array = pin.get("at", [])
		if cell_now.size() != 2:
			var start: Vector2i = ((_studio.catalog().get("maps", {}) as Dictionary).get(map_id, {}) as Dictionary).get("start", Vector2i.ZERO)
			cell_now = [start.x, start.y]
		set_step(i, "at", {"map": map_id, "at": cell_now})
	var picker := StudioQuestUi.choice(maps, labels, String(pin.get("map", "")), pick, "step.%d.pin" % i)
	picker.name = "StepPin%d" % i
	picker.custom_minimum_size.x = 180
	var row := Ui.hbox([picker], 6)
	if not pin.is_empty():
		var cell: Array = pin.get("at", [0, 0])
		var pinned_map: Dictionary = (_studio.catalog().get("maps", {}) as Dictionary).get(String(pin.get("map", "")), {})
		var size := OverworldMap.size_of(pinned_map) if pinned_map.has("width") else Vector2i(200, 200)
		for axis: int in 2:
			var spin := SpinBox.new()
			spin.min_value = 0
			spin.max_value = maxi(1, (size.x if axis == 0 else size.y) - 1)
			spin.step = 1
			spin.value = int(cell[axis]) if cell.size() == 2 else 0
			spin.prefix = "x " if axis == 0 else "y "
			spin.custom_minimum_size = Vector2(96, StudioQuestUi.FIELD_HEIGHT)
			spin.name = "StepPin%s%d" % ["X" if axis == 0 else "Y", i]
			spin.value_changed.connect(
				func(value: float) -> void:
					var now: Variant = StudioQuestEdit.at(quests(), [chosen, "steps", i, "at"])
					if not now is Dictionary:
						return
					var at_now: Array = ((now as Dictionary).get("at", [0, 0]) as Array).duplicate()
					at_now[axis] = int(value)
					set_step(i, "at", {"map": String((now as Dictionary).get("map", "")), "at": at_now})
			)
			row.add_child(spin)
	return row
