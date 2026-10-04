class_name Cards
extends RefCounted
## Shards and relics as cards: icon, name in its rarity's colour, what it costs, what it does, and (for a shard) the
## code itself, which is the point of the game.


## A shard's card. `summary` is false on a difficulty that shows only code; `code_lines` caps the code shown (0: all).
## `wide` puts the code beside the rest instead of under it, so whole lines show where there is room across.
static func shard(
	item: Dictionary, language: String, summary := true, code_lines := 0, action: Control = null, wide := false
) -> PanelContainer:
	var title := Ui.tint(
		Ui.label(Text.t(item.get("name", item.get("id", "?"))), "Subheading"), UiTheme.rarity(item.rarity)
	)
	var icon := Ui.picture(ShardrunViews.art(item), Vector2(40, 40), "◆")
	var facts := "%s · %s" % [Text.t(item.rarity), ShardrunViews.complexity(item)]
	if item.has("paradigm"):
		facts += Text.f(" · %d mana", [int(item.get("cost", 0))])
	elif int(item.get("cost", 0)) > 0:
		facts += Text.f(" · +%d work", [int(item.cost)])
	var head := Ui.hbox([icon, Ui.vbox([title, Ui.label(facts, "Faint")], 0)], 10)
	var body := Ui.vbox([head], 8)
	if summary and item.has("summary"):
		body.add_child(comment(Text.t(String(item.summary)), language, 34 if wide else 44))
	var curse: Dictionary = item.get("curse", {})
	if not curse.is_empty():
		body.add_child(
			Ui.tint(
				Ui.label(Text.f("Cursed: each cast burns %d Integrity.", [int(curse.integrity)]), "", true),
				UiTheme.SHARD
			)
		)
	var listing := code(item, language, code_lines)
	if not wide:
		body.add_child(listing)
	var forge: Dictionary = item.get("forge", {})
	if forge.has("into"):
		var verb := {"repair": "repairs", "optimize": "optimises"}.get(forge.get("verb"), "upgrades") as String
		# A program card's upgrade is a program card (P2-49), found among them, or the note shows its id.
		var programs: Dictionary = (Game.catalog.get("programs", {}) as Dictionary).get("cards", {})
		var pool: Dictionary = programs if item.has("role") else (Game.catalog.get("shards", {}) as Dictionary)
		var into: Dictionary = pool.get(forge.into, {})
		var into_name := Text.t(String(into.get("name", forge.into)))
		body.add_child(Ui.label(Text.f("A forge %s it into %s.", [Text.t(verb), into_name]), "Faint", true))
	if action != null:
		body.add_child(action)
	if not wide:
		return Ui.panel(body, "Card")
	body.custom_minimum_size.x = 300
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return Ui.panel(Ui.hbox([body, listing], 14), "Card")


## A shard's code in the run's language, coloured, in a sunken box.
static func code(item: Dictionary, language: String, max_lines := 0) -> Control:
	var text: String = (item.get("code", {}) as Dictionary).get(language, "")
	var lines := text.strip_edges(false, true).split("\n")
	var shown := lines if max_lines <= 0 else lines.slice(0, max_lines)
	var painted: PackedStringArray = []
	for line in shown:
		painted.append(CodeColors.bbcode(line, language))
	if max_lines > 0 and lines.size() > max_lines:
		painted.append("[color=#6f5e46]%s[/color]" % Text.f("… %d more lines", [lines.size() - max_lines]))
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	# Code is never translated (Text, ADR-0047).
	rich.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rich.add_theme_font_override("normal_font", UiTheme.code_font())
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_OFF
	rich.add_theme_font_size_override("normal_font_size", 15)
	rich.text = "\n".join(painted)
	rich.mouse_filter = Control.MOUSE_FILTER_PASS
	var scroll := Ui.scroll(rich, true)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return Ui.panel(scroll, "Sunken")


static func relic(item: Dictionary, action: Control = null) -> PanelContainer:
	var colour := UiTheme.SHARD if item.get("cursed", false) else UiTheme.rarity(rank(item))
	var title := Ui.tint(Ui.label(Text.t(item.name), "Subheading"), colour)
	var icon := Ui.picture("shardrun/relic-" + String(item.get("icon", item.id)), Vector2(40, 40), "✦")
	var kind := Text.t("cursed relic") if item.get("cursed", false) else Text.f("%s relic", [Text.t(rank(item))])
	if not item.get("cursed", false) and item.has("tier"):
		kind += Text.f("  ·  tier %d", [ProgramLoot.tier_number(item)])
	var head := Ui.hbox([icon, Ui.vbox([title, Ui.label(kind, "Faint")], 0)], 10)
	var body := Ui.vbox([head, Ui.label(Text.t(item.summary), "", true)], 8)
	if item.has("flavor"):
		body.add_child(Ui.label(Text.t(item.flavor), "Faint", true))
	if action != null:
		body.add_child(action)
	return Ui.panel(body, "Card")


## A relic's icon for the header, with its name, tier and effect as a tooltip. A tiered relic (a program run's) sits in
## a ring of its tier's colour, so a legendary one stands out in a row of commons; a curse's ring is the curse colour.
static func relic_icon(item: Dictionary) -> Control:
	var icon := Ui.picture("shardrun/relic-" + String(item.get("icon", item.get("id", ""))), Vector2(30, 30), "✦")
	var kind := Text.t(" (cursed)") if item.get("cursed", false) else ""
	if kind == "" and item.has("tier"):
		kind = Text.f(" (%s, tier %d)", [Text.t(item.tier), ProgramLoot.tier_number(item)])
	var title := "%s%s" % [Text.t(item.get("name", "?")), kind]
	var detail := Text.t(String(item.get("flavor", "")))
	if not item.has("tier"):
		HoverInfo.attach(icon, title, Text.t(item.get("summary", "")), detail, UiTheme.AMBER)
		return icon
	var ring := UiTheme.SHARD if item.get("cursed", false) else UiTheme.rarity(String(item.tier))
	var framed := PanelContainer.new()
	framed.add_theme_stylebox_override(
		"panel",
		UiTheme.box(Color(ring, 0.16), Color(ring, 0.9), 2 if item.tier == "legendary" else 1, 8, Vector2(2, 2))
	)
	framed.add_child(icon)
	HoverInfo.attach(framed, title, Text.t(item.get("summary", "")), detail, ring)
	return framed


## A relic's rank in words: a program relic's tier, or an old relic's rarity.
static func rank(item: Dictionary) -> String:
	return String(item.get("tier", item.get("rarity", "")))


## Plain words written as a comment in the run's language ("# ..." or "// ..."), green, wrapped at `columns`: a card's
## summary reads like the docstring of the code it sits beside.
static func comment(text: String, language: String, columns: int) -> RichTextLabel:
	var lines: PackedStringArray = []
	for line in CodeColors.comment_lines(text, language, columns):
		lines.append(line.replace("[", "[lb]"))
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	# Code is never translated (Text, ADR-0047).
	rich.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rich.add_theme_font_override("normal_font", UiTheme.code_font())
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_OFF
	rich.add_theme_font_size_override("normal_font_size", 15)
	rich.text = "[color=%s]%s[/color]" % [CodeColors.DOC, "\n".join(lines)]
	return rich
