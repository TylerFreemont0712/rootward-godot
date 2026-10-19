class_name StudioTalkEditor
extends VBoxContainer
## The quest editor's Talk view (Concept/v0.3/10, S9): one person's talk file as a node editor. On the left the
## file's start rules (which node a talk opens at, by condition) and its nodes; on the right the chosen node: its
## lines (speaker, mood, text), the flags it sets, its choices (text, where they go, when they show), where it goes
## next and what it opens. Under them, what Talk.problems finds. Every change is one command on the "talk/<id>" doc.
##
## The methods are what the buttons do, so a test can press them as a player would.

## The talk file shown (an id), the node chosen, and what was jumped to ("start 1", "choice 0") to show with an edge.
var file := ""
var node := ""
var marked := ""

var _studio: StudioMode
var _work: StudioQuestWork
var _files: OptionButton
var _left: VBoxContainer
var _right: VBoxContainer
var _left_scroll: ScrollContainer
var _right_scroll: ScrollContainer
var _problems: VBoxContainer
var _new_node: LineEdit
var _remove_node: Button
var _marked_card: Control
## The problems as shown, for the tests.
var problems_text: Array[String] = []


func _init(studio: StudioMode) -> void:
	_studio = studio
	_work = studio.quests
	name = "TalkEditor"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	_files = OptionButton.new()
	_files.name = "TalkFile"
	_files.focus_mode = Control.FOCUS_NONE
	_files.custom_minimum_size = Vector2(260, StudioQuestUi.FIELD_HEIGHT)
	_files.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	_files.get_popup().add_theme_font_size_override("font_size", StudioStyle.SMALL)
	_files.item_selected.connect(func(index: int) -> void: choose_file(String(_files.get_item_metadata(index))))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left = Ui.vbox([], 8)
	_left.custom_minimum_size.x = 540
	_left_scroll = Ui.scroll(_left)
	_left_scroll.custom_minimum_size.x = 560
	_left_scroll.size_flags_horizontal = Control.SIZE_FILL
	_right = Ui.vbox([], 8)
	_right_scroll = Ui.scroll(_right)
	_right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_left_scroll)
	body.add_child(VSeparator.new())
	body.add_child(_right_scroll)
	add_child(Ui.hbox([StudioQuestUi.heading(StudioText.t("talk_file")), _files], 10))
	add_child(body)
	add_child(StudioStyle.rule())
	_problems = Ui.vbox([], 2)
	var problems_scroll := Ui.scroll(_problems)
	problems_scroll.custom_minimum_size.y = 74
	add_child(problems_scroll)


# --- what the talk is ------------------------------------------------------------------------------------------------


func key() -> String:
	return "talk/" + file


func talk() -> Dictionary:
	return _work.data(key()) if file != "" else {}


func nodes() -> Dictionary:
	return talk().get("nodes", {}) as Dictionary


func node_data() -> Dictionary:
	return nodes().get(node, {}) as Dictionary


func _node_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in nodes():
		out.append(id)
	return out


## How many places lead to a node: start rules, choices and `next` of the other nodes.
func leads_to(id: String) -> int:
	var count := 0
	for rule: Dictionary in talk().get("start", []):
		if String(rule.get("goto", "")) == id:
			count += 1
	for other: String in nodes():
		var one: Dictionary = nodes()[other]
		for choice: Dictionary in one.get("choices", []):
			if String(choice.get("goto", "")) == id:
				count += 1
		if String(one.get("next", "")) == id:
			count += 1
	return count


# --- what the buttons do ---------------------------------------------------------------------------------------------


func _do(command: Dictionary) -> bool:
	if command.is_empty():
		return false
	return bool(_work.do(key(), command).get("ok", false))


func _put(tail: Array, value: Variant) -> bool:
	return _do(StudioQuestEdit.set_value(talk(), ["nodes", node] + tail, value))


func choose_file(id: String, at_node := "", where := "") -> void:
	StudioQuestUi.settle(self)
	file = id
	var ids := _node_ids()
	node = at_node if at_node != "" and at_node in ids else (ids[0] if not ids.is_empty() else "")
	marked = where
	rebuild()


func choose_node(id: String) -> void:
	StudioQuestUi.settle(self)
	node = id
	marked = ""
	rebuild()


## A node added (the id typed in the box, or "node" made fresh when `id` is empty). False when the id is bad or taken.
func add_node(id := "") -> bool:
	StudioQuestUi.settle(self)
	var wanted := id if id != "" else StudioQuestEdit.fresh_id("node", _node_ids())
	if not StudioQuestEdit.is_id(wanted) or nodes().has(wanted):
		_studio.say(StudioText.t("talk_bad_id") % wanted, true)
		return false
	if not _do(StudioQuestEdit.set_value({}, ["nodes", wanted], {"lines": [{"text": StudioText.t("talk_new_line")}]})):
		return false
	_new_node.text = ""
	node = wanted
	marked = ""
	return true


## The chosen node goes, when nothing leads to it.
func remove_node() -> bool:
	StudioQuestUi.settle(self)
	if node == "" or leads_to(node) > 0:
		return false
	var ids := _node_ids()
	var at := ids.find(node)
	var gone := node
	node = ""
	var ok := _do(StudioQuestEdit.set_value(talk(), ["nodes", gone], null))
	if ok:
		ids.erase(gone)
		node = ids[mini(at, ids.size() - 1)] if not ids.is_empty() else ""
	else:
		node = gone
	return ok


# start rules

func add_start() -> bool:
	StudioQuestUi.settle(self)
	var ids := _node_ids()
	var rules: Array = talk().get("start", [])
	# The last rule with no condition is the way in when nothing else holds: a new rule goes before it.
	var before_last := not rules.is_empty() and not (rules.back() as Dictionary).has("if")
	var made := {"if": {"flag": ""}, "goto": ids[0] if not ids.is_empty() else ""}
	return _do(StudioQuestEdit.add_item(talk(), ["start"], made, rules.size() - 1 if before_last else -1))


func set_start(index: int, field: String, value: Variant) -> bool:
	var erased := value == null or (field == "if" and value is Dictionary and (value as Dictionary).is_empty())
	return _do(StudioQuestEdit.set_value(talk(), ["start", index, field], null if erased else value))


func move_start(index: int, by: int) -> bool:
	StudioQuestUi.settle(self)
	marked = ""
	return _do(StudioQuestEdit.move_item(talk(), ["start"], index, index + by))


func remove_start(index: int) -> bool:
	StudioQuestUi.settle(self)
	if (talk().get("start", []) as Array).size() <= 1:
		return false
	return _do(StudioQuestEdit.remove_item(["start"], index))


# lines

func add_line() -> bool:
	StudioQuestUi.settle(self)
	return _do(StudioQuestEdit.add_item(talk(), ["nodes", node, "lines"], {"text": StudioText.t("talk_new_line")}))


## A field of a line: "text", "speaker" or "mood" (empty erases the last two).
func set_line(index: int, field: String, value: String) -> bool:
	var erased := field != "text" and value == ""
	return _put(["lines", index, field], null if erased else value)


func move_line(index: int, by: int) -> bool:
	StudioQuestUi.settle(self)
	return _do(StudioQuestEdit.move_item(talk(), ["nodes", node, "lines"], index, index + by))


func remove_line(index: int) -> bool:
	StudioQuestUi.settle(self)
	if (node_data().get("lines", []) as Array).size() <= 1:
		return false
	return _do(StudioQuestEdit.remove_item(["nodes", node, "lines"], index))


# set

## A flag the chosen node sets (once).
func add_set(flag: String) -> bool:
	var named := flag.strip_edges()
	if named == "" or node == "" or named in (node_data().get("set", []) as Array):
		return false
	return _do(StudioQuestEdit.add_item(talk(), ["nodes", node, "set"], named))


func remove_set(index: int) -> bool:
	StudioQuestUi.settle(self)
	return _do(StudioQuestEdit.remove_item(["nodes", node, "set"], index))


# choices

func add_choice() -> bool:
	StudioQuestUi.settle(self)
	var ids := _node_ids()
	var made := {"text": StudioText.t("talk_new_choice"), "goto": ids[0] if not ids.is_empty() else ""}
	return _do(StudioQuestEdit.add_item(talk(), ["nodes", node, "choices"], made))


## A field of a choice: "text", "goto", or "if" (a condition; {} erases it).
func set_choice(index: int, field: String, value: Variant) -> bool:
	var erased := field == "if" and value is Dictionary and (value as Dictionary).is_empty()
	return _put(["choices", index, field], null if erased else value)


func move_choice(index: int, by: int) -> bool:
	StudioQuestUi.settle(self)
	marked = ""
	return _do(StudioQuestEdit.move_item(talk(), ["nodes", node, "choices"], index, index + by))


func remove_choice(index: int) -> bool:
	StudioQuestUi.settle(self)
	return _do(StudioQuestEdit.remove_item(["nodes", node, "choices"], index))


## A plain field of the node: "next" or "open" (empty erases it).
func set_node_field(field: String, value: String) -> bool:
	return _put([field], null if value == "" else value)


# --- drawing ---------------------------------------------------------------------------------------------------------


func rebuild() -> void:
	var ids := _work.talk_ids()
	if file == "" or not file in ids:
		file = ids[0] if not ids.is_empty() else ""
		node = ""
	if not nodes().has(node):
		var node_ids := _node_ids()
		node = node_ids[0] if not node_ids.is_empty() else ""
	var saved := StudioQuestUi.remember(self)
	var left_scroll := _left_scroll.scroll_vertical
	var right_scroll := _right_scroll.scroll_vertical
	StudioQuestUi.clear(_left)
	StudioQuestUi.clear(_right)
	StudioQuestUi.clear(_problems)
	_marked_card = null
	_fill_files(ids)
	if file == "" or _work.history(key()) == null:
		_left.add_child(StudioStyle.line(StudioText.t("talk_unreadable") % file, UiTheme.FAIL))
		return
	var flags := StudioQuestUi.flag_names(_work)
	_build_left(flags)
	if node != "":
		_build_right(flags)
	_build_problems()
	StudioQuestUi.restore(self, saved)
	if _marked_card != null:
		StudioQuestUi.show_control(_left_scroll if _marked_card.get_meta("side", "") == "left" else _right_scroll, _marked_card)
	else:
		StudioQuestUi.keep_scroll(_left_scroll, left_scroll)
		StudioQuestUi.keep_scroll(_right_scroll, right_scroll)


func _fill_files(ids: Array[String]) -> void:
	_files.clear()
	var people := _studio.catalog().get("townsfolk", {}) as Dictionary
	var by_talk := {}
	for id: String in people:
		by_talk[String((people[id] as Dictionary).get("talk", id))] = String((people[id] as Dictionary).get("name", id))
	for i: int in ids.size():
		_files.add_item(ids[i] if not by_talk.has(ids[i]) else "%s (%s)" % [ids[i], by_talk[ids[i]]])
		_files.set_item_metadata(i, ids[i])
		if ids[i] == file:
			_files.select(i)


func _build_left(flags: Array[String]) -> void:
	_left.add_child(StudioQuestUi.heading(StudioText.t("talk_starts")))
	_left.add_child(StudioStyle.caption(StudioText.t("talk_starts_hint")))
	var rules: Array = talk().get("start", [])
	var ids := _node_ids()
	for i: int in rules.size():
		var index := i
		var rule: Dictionary = rules[i]
		var number := StudioStyle.line(str(i + 1), UiTheme.AMBER)
		number.custom_minimum_size.x = 20
		var goes := StudioQuestUi.choice(ids, [] as Array[String], String(rule.get("goto", "")), func(picked: String) -> void: set_start(index, "goto", picked), "start.%d.goto" % i)
		goes.name = "StartGoto%d" % i
		var up := StudioQuestUi.button(StudioText.t("move_up"), func() -> void: move_start(index, -1), "StartUp%d" % i)
		up.disabled = i == 0
		var down := StudioQuestUi.button(StudioText.t("move_down"), func() -> void: move_start(index, 1), "StartDown%d" % i)
		down.disabled = i >= rules.size() - 1
		var drop := StudioQuestUi.button(StudioText.t("quest_remove_step"), func() -> void: remove_start(index), "StartRemove%d" % i)
		drop.disabled = rules.size() <= 1
		var cond_now := func() -> Variant: return ((talk().get("start", []) as Array)[index] as Dictionary).get("if", {}) if index < (talk().get("start", []) as Array).size() else {}
		var cond := StudioConditionEditor.build(cond_now, flags, func(next: Dictionary) -> void: set_start(index, "if", next), "start.%d.if" % i, true)
		cond.name = "StartIf%d" % i
		var head := Ui.hbox([number, StudioQuestUi.field_name(StudioText.t("talk_goes_to"), 60), goes, Ui.spacer(), up, down, drop], 6)
		var card := StudioQuestUi.card(Ui.vbox([head, Ui.hbox([StudioQuestUi.field_name(StudioText.t("talk_when"), 60), cond], 6)], 6), marked == "start %d" % i)
		card.name = "Start%d" % i
		if marked == "start %d" % i:
			card.set_meta("side", "left")
			_marked_card = card
		_left.add_child(card)
	var add_rule := StudioQuestUi.button(StudioText.t("talk_add_start"), func() -> void: add_start(), "AddStart")
	_left.add_child(Ui.hbox([add_rule], 0))
	_left.add_child(StudioStyle.rule())
	_left.add_child(StudioQuestUi.heading(StudioText.t("talk_nodes")))
	for id: String in ids:
		var one: Dictionary = nodes()[id]
		var pick := StudioStyle.button(id, func() -> void: choose_node(id), id == node)
		pick.name = "Node_" + id
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.custom_minimum_size.x = 150
		var facts: Array[String] = [StudioText.t("talk_n_lines") % (one.get("lines", []) as Array).size()]
		var sets := (one.get("set", []) as Array).size()
		if sets > 0:
			facts.append(StudioText.t("talk_n_sets") % sets)
		if (one.get("choices", []) as Array).size() > 0:
			facts.append(StudioText.t("talk_n_choices") % (one.get("choices", []) as Array).size())
		var note := StudioStyle.caption(", ".join(facts))
		var nothing := leads_to(id) == 0
		var lead := StudioStyle.caption(StudioText.t("talk_nothing_leads") if nothing else "")
		lead.add_theme_color_override("font_color", UiTheme.WARN)
		_left.add_child(Ui.hbox([pick, note, lead], 8))
	_new_node = StudioQuestUi.line("", func(_text: String) -> void: pass, "talk.new_node", StudioText.t("talk_new_node"))
	_new_node.name = "NewNodeId"
	var add := StudioQuestUi.button(StudioText.t("talk_add_node"), func() -> void: add_node(_new_node.text.strip_edges()), "AddNode", StudioText.t("talk_add_node_tip"))
	_remove_node = StudioQuestUi.button(StudioText.t("talk_remove_node"), func() -> void: remove_node(), "RemoveNode", StudioText.t("talk_remove_node_tip"))
	_remove_node.disabled = node == "" or leads_to(node) > 0
	_left.add_child(Ui.hbox([_new_node, add], 6))
	_left.add_child(Ui.hbox([_remove_node], 6))


func _build_right(flags: Array[String]) -> void:
	var one := node_data()
	_right.add_child(Ui.hbox([StudioQuestUi.heading(StudioText.t("talk_node") % node), StudioStyle.caption(StudioText.t("talk_node_hint"))], 10))
	# Lines
	var lines: Array = one.get("lines", [])
	var people := StudioQuestUi.people(_studio)
	var people_labels: Array[String] = []
	for person: String in people:
		people_labels.append(StudioText.t("nobody_speaker") if person == "" else person)
	var moods: Array[String] = ["", "happy"]
	_right.add_child(StudioQuestUi.heading(StudioText.t("talk_lines")))
	for i: int in lines.size():
		var index := i
		var line: Dictionary = lines[i]
		var number := StudioStyle.line(str(i + 1), UiTheme.AMBER)
		number.custom_minimum_size.x = 20
		var speaker := StudioQuestUi.choice(people, people_labels, String(line.get("speaker", "")), func(picked: String) -> void: set_line(index, "speaker", picked), "line.%d.speaker" % i)
		speaker.name = "LineSpeaker%d" % i
		var mood_labels: Array[String] = [StudioText.t("talk_no_mood"), "happy"]
		var mood := StudioQuestUi.choice(moods, mood_labels, String(line.get("mood", "")), func(picked: String) -> void: set_line(index, "mood", picked), "line.%d.mood" % i)
		mood.name = "LineMood%d" % i
		mood.custom_minimum_size.x = 110
		var up := StudioQuestUi.button(StudioText.t("move_up"), func() -> void: move_line(index, -1), "LineUp%d" % i)
		up.disabled = i == 0
		var down := StudioQuestUi.button(StudioText.t("move_down"), func() -> void: move_line(index, 1), "LineDown%d" % i)
		down.disabled = i >= lines.size() - 1
		var drop := StudioQuestUi.button(StudioText.t("quest_remove_step"), func() -> void: remove_line(index), "LineRemove%d" % i)
		drop.disabled = lines.size() <= 1
		var text := StudioQuestUi.area(String(line.get("text", "")), func(value: String) -> void: set_line(index, "text", value), "line.%d.text" % i, 2)
		text.name = "LineText%d" % i
		var head := Ui.hbox([number, StudioQuestUi.field_name(StudioText.t("talk_speaker"), 62), speaker, StudioQuestUi.field_name(StudioText.t("talk_mood"), 46), mood, Ui.spacer(), up, down, drop], 6)
		_right.add_child(StudioQuestUi.card(Ui.vbox([head, text], 6)))
	_right.add_child(Ui.hbox([StudioQuestUi.button(StudioText.t("talk_add_line"), func() -> void: add_line(), "AddLine")], 0))
	_right.add_child(StudioStyle.rule())
	# Set
	_right.add_child(StudioQuestUi.heading(StudioText.t("talk_sets")))
	_right.add_child(StudioStyle.caption(StudioText.t("talk_sets_hint")))
	var sets: Array = one.get("set", [])
	var chips := Ui.flow([], 8)
	for i: int in sets.size():
		var index := i
		var chip := Ui.hbox([StudioStyle.line(String(sets[i]), UiTheme.TEAL), StudioQuestUi.button("x", func() -> void: remove_set(index), "SetRemove%d" % i, StudioText.t("talk_remove_set"))], 2)
		chips.add_child(chip)
	_right.add_child(chips)
	var adder := StudioQuestUi.flag_field("", flags, func(text: String) -> void: add_set(text), "node.set.add")
	adder.custom_minimum_size.x = 300
	adder.size_flags_horizontal = Control.SIZE_FILL
	adder.name = "AddSetField"
	var add_set_button := StudioQuestUi.button(StudioText.t("talk_add_set"), func() -> void: StudioQuestUi.settle(self), "AddSet")
	_right.add_child(Ui.hbox([StudioStyle.line(StudioText.t("talk_add_set_label"), UiTheme.MUTED), adder, add_set_button], 8))
	_right.add_child(StudioStyle.rule())
	# Choices
	_right.add_child(StudioQuestUi.heading(StudioText.t("talk_choices")))
	var choices: Array = one.get("choices", [])
	var ids := _node_ids()
	var ends: Array[String] = [""]
	var end_labels: Array[String] = [StudioText.t("talk_ends")]
	for id: String in ids:
		ends.append(id)
		end_labels.append(id)
	for i: int in choices.size():
		var index := i
		var choice: Dictionary = choices[i]
		var number := StudioStyle.line(str(i + 1), UiTheme.AMBER)
		number.custom_minimum_size.x = 20
		var text := StudioQuestUi.line(String(choice.get("text", "")), func(value: String) -> void: set_choice(index, "text", value), "choice.%d.text" % i, StudioText.t("talk_choice_text"))
		text.name = "ChoiceText%d" % i
		var goes := StudioQuestUi.choice(ends, end_labels, String(choice.get("goto", "")), func(picked: String) -> void: set_choice(index, "goto", picked), "choice.%d.goto" % i)
		goes.name = "ChoiceGoto%d" % i
		var up := StudioQuestUi.button(StudioText.t("move_up"), func() -> void: move_choice(index, -1), "ChoiceUp%d" % i)
		up.disabled = i == 0
		var down := StudioQuestUi.button(StudioText.t("move_down"), func() -> void: move_choice(index, 1), "ChoiceDown%d" % i)
		down.disabled = i >= choices.size() - 1
		var drop := StudioQuestUi.button(StudioText.t("quest_remove_step"), func() -> void: remove_choice(index), "ChoiceRemove%d" % i)
		var cond_now := func() -> Variant: return ((node_data().get("choices", []) as Array)[index] as Dictionary).get("if", {}) if index < (node_data().get("choices", []) as Array).size() else {}
		var cond := StudioConditionEditor.build(cond_now, flags, func(next: Dictionary) -> void: set_choice(index, "if", next), "choice.%d.if" % i, true)
		cond.name = "ChoiceIf%d" % i
		var head := Ui.hbox([number, text, StudioQuestUi.field_name(StudioText.t("talk_goes_to"), 60), goes, up, down, drop], 6)
		var card := StudioQuestUi.card(Ui.vbox([head, Ui.hbox([Ui.spacer(26, 0), StudioQuestUi.field_name(StudioText.t("talk_only_when"), 80), cond], 6)], 6), marked == "choice %d" % i)
		card.name = "Choice%d" % i
		if marked == "choice %d" % i:
			card.set_meta("side", "right")
			_marked_card = card
		_right.add_child(card)
	_right.add_child(Ui.hbox([StudioQuestUi.button(StudioText.t("talk_add_choice"), func() -> void: add_choice(), "AddChoice")], 0))
	_right.add_child(StudioStyle.rule())
	# Next and open
	var next := StudioQuestUi.choice(ends, end_labels, String(one.get("next", "")), func(picked: String) -> void: set_node_field("next", picked), "node.next")
	next.name = "NodeNext"
	next.custom_minimum_size.x = 200
	var open := StudioQuestUi.line(String(one.get("open", "")), func(value: String) -> void: set_node_field("open", value), "node.open", StudioText.t("talk_open_hint"))
	open.name = "NodeOpen"
	open.size_flags_horizontal = Control.SIZE_FILL
	open.custom_minimum_size.x = 260
	_right.add_child(Ui.hbox([StudioQuestUi.field_name(StudioText.t("talk_next"), 110), next, StudioStyle.caption(StudioText.t("talk_next_hint"))], 8))
	_right.add_child(Ui.hbox([StudioQuestUi.field_name(StudioText.t("talk_open"), 110), open, StudioStyle.caption(StudioText.t("talk_open_note"))], 8))


func _build_problems() -> void:
	problems_text = Talk.problems(talk())
	if problems_text.is_empty():
		_problems.add_child(StudioStyle.line(StudioText.t("talk_no_problems"), UiTheme.PASS))
	for problem: String in problems_text:
		_problems.add_child(StudioStyle.line(problem, UiTheme.FAIL))
