class_name CardDetail
extends PanelContainer
## What a card does, shown beside it while it is pointed at: its name, cost and speed, what kind of card it is, what it
## needs and leaves, its summary written as a comment (when the difficulty shows summaries), and its code. Wide and
## short, so it never runs down the screen; a long function shows its first lines.

const WIDTH := 580.0
const CODE_LINES := 13
const COLUMNS := 74
const CODE_SIZE := 13


## `forge_into` names the card a forge turns it into ("" when none does).
static func create(
	card: Dictionary,
	id: String,
	language: String,
	summaries: bool,
	colour: Color,
	tags: Array[String],
	forge_into: String
) -> CardDetail:
	var detail := CardDetail.new()
	detail._build(card, id, language, summaries, colour, tags, forge_into)
	return detail


func _build(
	card: Dictionary,
	id: String,
	language: String,
	summaries: bool,
	colour: Color,
	tags: Array[String],
	forge_into: String
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
	size = box
	var x := rect.end.x + 14.0
	if x + box.x > screen.x - 8.0:
		x = rect.position.x - 14.0 - box.x
	var y := clampf(rect.end.y - box.y, 8.0, screen.y - box.y - 8.0)
	global_position = Vector2(maxf(8.0, x), y)
