class_name CardDetail
extends PanelContainer
## What a card does, shown beside it while it is pointed at: its name, cost and speed, what kind of card it is, what it
## needs and leaves, its summary written as a comment (when the difficulty shows summaries), and its code. Wide and
## short, so it never runs down the screen; a long function shows its first lines.

const WIDTH := 580.0
const CODE_LINES := 13
const COLUMNS := 74
const CODE_SIZE := 13

## Frames it waits for its card to hold still before it shows anyway.
const PATIENCE := 20

## Its size and its card's place last frame (place_beside shows it only once they hold still).
var _last_box := Vector2(-1, -1)
var _last_rect := Rect2()
var _waited := 0
var _shown := false


## `forge_into` names the card a forge turns it into ("" when none does); `meanings` says what each keyword means.
static func create(
	card: Dictionary,
	id: String,
	language: String,
	summaries: bool,
	colour: Color,
	tags: Array[String],
	forge_into: String,
	meanings: Dictionary = {}
) -> CardDetail:
	var detail := CardDetail.new()
	detail._build(card, id, language, summaries, colour, tags, forge_into, meanings)
	return detail


func _build(
	card: Dictionary,
	id: String,
	language: String,
	summaries: bool,
	colour: Color,
	tags: Array[String],
	forge_into: String,
	meanings: Dictionary
) -> void:
	var look := UiTheme.box(Color(0.07, 0.05, 0.09, 0.97), colour.darkened(0.15), 2, 10, Vector2(14, 12))
	look.shadow_color = Color(0, 0, 0, 0.55)
	look.shadow_size = 12
	add_theme_stylebox_override("panel", look)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = WIDTH
	var name := Ui.tint(
		Ui.label(card.get("name", id), "Subheading"), UiTheme.rarity(card.get("rarity", "common")).lightened(0.25)
	)
	var cost := Ui.tint(Ui.label("%d◆" % int(card.get("cost", 0)), "Subheading"), UiTheme.SHARD.lightened(0.2))
	var speed := Ui.tint(Ui.label(ShardrunViews.complexity(card), "Subheading"), colour.lightened(0.35))
	var column := Ui.vbox([Ui.hbox([name, Ui.spacer(), speed, cost], 12)], 6)
	var kinds: Array[Control] = []
	if RoleBadge.ROLES.has(String(card.get("role", ""))):
		# The role first, in its own colour, as on the card's face.
		var role := Ui.label(RoleBadge.describe(String(card.role)), "Faint")
		kinds.append(Ui.tint(role, RoleBadge.colour_of(String(card.role)).lightened(0.1)))
	if not tags.is_empty():
		kinds.append(Ui.tint(Ui.label("  ·  ".join(tags), "Faint"), colour.lightened(0.1)))
	if not kinds.is_empty():
		column.add_child(Ui.hbox(kinds, 14))
	# Each keyword with what it means (ADR-0018), in its colour on the card's face.
	for keyword: String in card.get("keywords", []):
		var meaning := String(meanings.get(keyword, ""))
		var line := Ui.label("%s · %s" % [keyword, meaning] if meaning != "" else keyword, "Faint", true)
		column.add_child(Ui.tint(line, KeywordChips.colour_of(keyword)))
	if card.get("role", "") == "import":
		var imported := Ui.label(
			"Play it into the Program: it becomes a line at the top and holds for the rest of the fight.", "Faint", true
		)
		column.add_child(Ui.tint(imported, RoleBadge.colour_of("import")))
	var painted: PackedStringArray = []
	if summaries and card.has("summary"):
		for line in CodeColors.comment_lines(String(card.summary), language, COLUMNS):
			painted.append("[color=%s]%s[/color]" % [CodeColors.DOC, line.replace("[", "[lb]")])
	var code: String = (card.get("code", {}) as Dictionary).get(language, "")
	var lines := CodeColors.fit_code(code, language, COLUMNS)
	for line in lines.slice(0, CODE_LINES):
		painted.append(CodeColors.bbcode(line, language))
	if lines.size() > CODE_LINES:
		var more := (
			"%s … %d more lines in the Program panel"
			% ["#" if language == "python" else "//", lines.size() - CODE_LINES]
		)
		painted.append("[color=%s]%s[/color]" % [CodeColors.COMMENT, more])
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.clip_contents = true
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("normal_font_size", CODE_SIZE)
	text.text = "\n".join(painted)
	var box := Ui.panel(text, "Sunken")
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(box)
	var forge: Dictionary = card.get("forge", {})
	if forge_into != "":
		var verb := {"repair": "repairs", "optimize": "optimises"}.get(forge.get("verb"), "upgrades") as String
		column.add_child(Ui.label("A forge %s it into %s." % [verb, forge_into], "Faint", true))
	for child in column.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)


## Stands beside `rect` (the card, in canvas coordinates): to its right when there is room, else to its left, its
## bottom level with the card's but never off the screen.
func place_beside(rect: Rect2, screen: Vector2) -> void:
	var box := get_combined_minimum_size()
	# LEARN: a label that wraps, and rich text that fits its content, only know their height after a layout pass has
	# given them their width, so the first frame's size is a guess (Merge Sort's details measure 797 px, then 445).
	# Shown only once two frames agree on its size and on where the card is (a hand card lifts as it is pointed at),
	# the details never appear at a guessed place and slide or snap to the real one; after a few frames they show
	# anyway, beside a card that never holds still.
	var still := box == _last_box and rect.position.distance_to(_last_rect.position) < 0.5
	_waited += 1
	# Once shown it stays shown: a card nudged later (the hand making room) moves it without a blink.
	_shown = _shown or still or _waited >= PATIENCE
	modulate.a = 1.0 if _shown else 0.0
	_last_box = box
	_last_rect = rect
	size = box
	var x := rect.end.x + 14.0
	if x + box.x > screen.x - 8.0:
		x = rect.position.x - 14.0 - box.x
	var y := clampf(rect.end.y - box.y, 8.0, screen.y - box.y - 8.0)
	global_position = Vector2(maxf(8.0, x), y)
