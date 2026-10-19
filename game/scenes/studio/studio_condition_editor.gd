class_name StudioConditionEditor
extends RefCounted
## The editor of a condition (Concept/v0.3/10, S9), in the quests' language (Quests.holds): a kind choice (always, flag,
## not, flag and not, count, all) with the fields that kind needs; an `all` is a list of conditions of its own, each
## one edited the same way. It builds a row of controls and says every change as a whole new condition.
##
##   var row := StudioConditionEditor.build(func() -> Variant: return step_now().done, flags, func(next: Dictionary) -> void: ..., "step.2.done")

const ALWAYS := "always"
const FLAG := "flag"
const NOT := "not"
const FLAG_NOT := "flag_not"
const COUNT := "count"
## The bag holds at least so many of an item (v0.4, Talk.holds' "has").
const HAS := "has"
const ALL := "all"
const KINDS: Array[String] = [ALWAYS, FLAG, NOT, FLAG_NOT, COUNT, HAS, ALL]


## Which kind a condition is. A condition with an `all` is an all; a count; both a flag and a not; then one of them.
static func kind_of(condition: Variant) -> String:
	if not condition is Dictionary:
		return ALWAYS
	var kept := condition as Dictionary
	if kept.has("all"):
		return ALL
	if kept.has("count"):
		return COUNT
	if kept.has("has"):
		return HAS
	if kept.has("flag") and kept.has("not"):
		return FLAG_NOT
	if kept.has("flag"):
		return FLAG
	if kept.has("not"):
		return NOT
	return ALWAYS


## The condition of another kind that keeps what can be kept: a flag stays the flag, a count's prefix stays.
static func converted(condition: Variant, kind: String) -> Dictionary:
	var kept: Dictionary = condition if condition is Dictionary else {}
	var named := ""
	for key: String in ["flag", "not", "count"]:
		if String(kept.get(key, "")) != "":
			named = String(kept[key])
			break
	var was := kind_of(kept)
	match kind:
		ALWAYS:
			return {}
		FLAG:
			return {"flag": named}
		NOT:
			return {"not": named}
		FLAG_NOT:
			return {"flag": String(kept.get("flag", "")), "not": String(kept.get("not", ""))} if was == FLAG_NOT else {"flag": named, "not": ""}
		COUNT:
			return {"count": String(kept.get("count", "")), "at_least": int(kept.get("at_least", 1))} if was == COUNT else {"count": "", "at_least": 1}
		HAS:
			return {"has": String(kept.get("has", "")), "at_least": int(kept.get("at_least", 1))} if was == HAS else {"has": "", "at_least": 1}
		ALL:
			if was == ALL:
				return kept
			return {"all": [{"flag": named}] if named != "" else []}
	return {}


## The kinds' words, for the choice.
static func kind_labels(optional: bool) -> Array[String]:
	var out: Array[String] = []
	for kind: String in _kinds(optional):
		out.append(StudioText.t("cond_" + kind))
	return out


static func _kinds(optional: bool) -> Array[String]:
	var out: Array[String] = []
	out.assign(KINDS)
	if not optional:
		out.erase(ALWAYS)
	return out


## The controls for a condition: a row (a column for an `all`). `current` gives the condition as the doc has it now (a
## button pressed after a typed line committed must start from that line, not from what was built); `on_change` gets
## the whole new condition. `optional` lets the kind be "always" (a start rule or a choice with no condition). `fid`
## names the controls for focus.
static func build(current: Callable, flags: Array[String], on_change: Callable, fid: String, optional := false) -> Control:
	var kept := _now(current)
	var kind := kind_of(kept)
	var kinds := _kinds(optional)
	var pick := func(picked: String) -> void: on_change.call(converted(_now(current), picked))
	var picker := StudioQuestUi.choice(kinds, kind_labels(optional), kind if kind in kinds else kinds[0], pick, fid + ".kind")
	picker.custom_minimum_size.x = 190
	picker.name = "Kind"
	var row := Ui.hbox([picker], 6)
	var with := func(key: String, value: Variant) -> void:
		var next := _now(current).duplicate(true)
		next[key] = value
		on_change.call(next)
	var set_flag := func(key: String) -> Callable: return func(text: String) -> void: with.call(key, text)
	match kind:
		FLAG:
			row.add_child(StudioQuestUi.flag_field(String(kept.get("flag", "")), flags, set_flag.call("flag"), fid + ".flag"))
		NOT:
			row.add_child(StudioQuestUi.flag_field(String(kept.get("not", "")), flags, set_flag.call("not"), fid + ".not"))
		FLAG_NOT:
			row.add_child(StudioQuestUi.flag_field(String(kept.get("flag", "")), flags, set_flag.call("flag"), fid + ".flag"))
			row.add_child(StudioStyle.line(StudioText.t("cond_and_not"), UiTheme.MUTED))
			row.add_child(StudioQuestUi.flag_field(String(kept.get("not", "")), flags, set_flag.call("not"), fid + ".not"))
		COUNT:
			var prefix := StudioQuestUi.line(String(kept.get("count", "")), set_flag.call("count"), fid + ".count", StudioText.t("cond_prefix_hint"))
			prefix.custom_minimum_size.x = 220
			prefix.size_flags_horizontal = Control.SIZE_FILL
			row.add_child(prefix)
			row.add_child(StudioStyle.line(StudioText.t("cond_at_least"), UiTheme.MUTED))
			var spin := SpinBox.new()
			spin.min_value = 1
			spin.max_value = 999
			spin.step = 1
			spin.value = int(kept.get("at_least", 1))
			spin.custom_minimum_size = Vector2(80, StudioQuestUi.FIELD_HEIGHT)
			spin.set_meta("fid", fid + ".at_least")
			spin.value_changed.connect(func(value: float) -> void: with.call("at_least", int(value)))
			row.add_child(spin)
		HAS:
			var item := StudioQuestUi.line(String(kept.get("has", "")), set_flag.call("has"), fid + ".has", StudioText.t("cond_item_hint"))
			item.custom_minimum_size.x = 160
			item.size_flags_horizontal = Control.SIZE_FILL
			row.add_child(item)
			row.add_child(StudioStyle.line(StudioText.t("cond_at_least"), UiTheme.MUTED))
			var many := SpinBox.new()
			many.min_value = 1
			many.max_value = 999
			many.step = 1
			many.value = int(kept.get("at_least", 1))
			many.custom_minimum_size = Vector2(80, StudioQuestUi.FIELD_HEIGHT)
			many.set_meta("fid", fid + ".at_least")
			many.value_changed.connect(func(value: float) -> void: with.call("at_least", int(value)))
			row.add_child(many)
		ALL:
			# LEARN: the picker heads the all's own column instead, and leaves the row first: a node has one parent.
			row.remove_child(picker)
			row.free()
			return _all(picker, current, flags, on_change, fid)
	return row


static func _now(current: Callable) -> Dictionary:
	var value: Variant = current.call()
	return value if value is Dictionary else {}


## An `all`: its kind choice, then a column of the conditions it holds (each one edited as a condition) and a button
## to add one.
static func _all(picker: Control, current: Callable, flags: Array[String], on_change: Callable, fid: String) -> Control:
	var column := Ui.vbox([Ui.hbox([picker, StudioStyle.line(StudioText.t("cond_all_of"), UiTheme.MUTED)], 6)], 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var parts_of := func() -> Array:
		var all: Variant = _now(current).get("all", [])
		return all if all is Array else []
	# The whole condition with its parts changed: `change` is given the parts (a copy) to change.
	var with_parts := func(change: Callable) -> void:
		var all: Array = (parts_of.call() as Array).duplicate(true)
		change.call(all)
		var changed := _now(current).duplicate(true)
		changed["all"] = all
		on_change.call(changed)
	for i: int in (parts_of.call() as Array).size():
		var index := i
		var part_now := func() -> Variant:
			var all: Array = parts_of.call()
			return all[index] if index < all.size() else {}
		var replace := func(next: Dictionary) -> void:
			with_parts.call(func(all: Array) -> void: all[index] = next)
		var edit := build(part_now, flags, replace, "%s.%d" % [fid, i])
		var remove := func() -> void:
			StudioQuestUi.settle(column)
			with_parts.call(func(all: Array) -> void: all.remove_at(index))
		var drop := StudioQuestUi.button("x", remove, "DropPart%d" % i, StudioText.t("cond_drop_part"))
		column.add_child(Ui.hbox([Ui.spacer(18, 0), edit, drop], 6))
	var append := func() -> void:
		StudioQuestUi.settle(column)
		with_parts.call(func(all: Array) -> void: all.append({"flag": ""}))
	column.add_child(Ui.hbox([Ui.spacer(18, 0), StudioQuestUi.button(StudioText.t("cond_add_part"), append, "AddPart")], 6))
	return column
