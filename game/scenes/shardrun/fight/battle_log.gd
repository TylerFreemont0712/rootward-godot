class_name BattleLog
extends RefCounted
## The fight's log, kept whole and opened on demand (the ".log" button) instead of scrolling past beside the fight:
## every entry the rules recorded, grouped by turn, with the numbers that explain it (weakness, shields, overkill,
## block, the race). Written like a log file, since the rest of the game is code too.

const COLOURS := {
	"cast": "#b48cff",
	"hit": "#f2a541",
	"wasted": "#6f5e46",
	"enemy": "#e2584f",
	"tempo": "#e9c46a",
	"timeout": "#e2584f",
	"curse": "#b48cff",
	"ward": "#5cc8b8",
	"shield": "#5cc8b8",
	"heal": "#8bc96a",
	"fizzle": "#a58f6e",
	"defeat": "#e9dcc0",
	"victory": "#8bc96a",
	"loss": "#e2584f",
	"turn": "#6f5e46",
}


## An entry's line: its text and, in brackets, what went into its number.
static func detail(entry: Dictionary) -> String:
	var text := String(entry.get("text", ""))
	var notes: Array[String] = []
	match String(entry.get("kind", "")):
		"hit":
			if entry.get("element", "none") != "none":
				notes.append(String(entry.element))
			match entry.get("affinity", ""):
				"weak":
					notes.append("weak to it ×1.5")
				"resist":
					notes.append("resists it ×0.5")
			if int(entry.get("overkill", 0)) > 0:
				notes.append("%d past its HP, wasted" % int(entry.overkill))
		"enemy":
			if int(entry.get("blocked", 0)) > 0:
				notes.append("%d taken by your block" % int(entry.blocked))
		"ward":
			notes.append("+%d block" % int(entry.get("amount", 0)))
	return text + ("  [%s]" % ", ".join(notes) if not notes.is_empty() else "")


## The log as BBCode, turn by turn, each line tagged with its kind.
static func text(entries: Array[Dictionary]) -> String:
	var lines: PackedStringArray = []
	var turn := -1
	var tally := {}
	for entry in entries:
		var at := int(entry.get("turn_number", 1))
		if at != turn:
			if turn >= 0:
				lines.append(_tally(tally))
			turn = at
			tally = {"dealt": 0, "taken": 0, "block": 0, "wasted": 0}
			lines.append("[color=#6f5e46]── turn %d ──────────────────────────────[/color]" % turn)
		match String(entry.kind):
			"hit":
				tally.dealt += int(entry.get("amount", 0))
				tally.wasted += int(entry.get("overkill", 0))
			"wasted":
				tally.wasted += int(entry.get("amount", 0))
			"enemy":
				tally.taken += int(entry.get("amount", 0))
			"ward":
				tally.block += int(entry.get("amount", 0))
		if entry.kind == "turn":
			continue
		var colour: String = COLOURS.get(entry.kind, "#a58f6e")
		var kind := "%-8s" % String(entry.kind)
		var line := (
			"[color=#6f5e46]T%d[/color]  [color=%s]%s[/color] %s"
			% [turn, colour, kind, detail(entry).replace("[", "[lb]")]
		)
		lines.append(line)
	if turn >= 0 and entries.back().kind != "turn":
		lines.append(_tally(tally))
	if lines.is_empty():
		lines.append("[color=#6f5e46]# nothing has happened yet[/color]")
	return "\n".join(lines)


## A turn's sums, as the comment under it.
static func _tally(tally: Dictionary) -> String:
	var parts := "dealt %d · took %d · gained %d block" % [tally.dealt, tally.taken, tally.block]
	if int(tally.wasted) > 0:
		parts += " · wasted %d" % tally.wasted
	return "[color=%s]   # %s[/color]" % [CodeColors.DOC, parts]


## A window over the screen with the whole log, newest at the bottom and scrolled to it.
static func open(owner: Control, entries: Array[Dictionary]) -> void:
	var popup := PopupPanel.new()
	popup.title = "battle.log"
	popup.popup_hide.connect(popup.queue_free)
	owner.add_child(popup)
	var heading := Ui.hbox([Ui.label("battle.log", "Heading"), Ui.spacer(), Ui.label("$ cat battle.log", "Faint")], 12)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.scroll_following = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 14)
	body.text = text(entries)
	var close := Ui.button("Close", popup.hide)
	var column := Ui.vbox([heading, Ui.panel(body, "Sunken"), close], 10)
	(column.get_child(1) as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel := Ui.panel(column, "Overlay")
	popup.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.popup_centered(Vector2i(980, 640))
