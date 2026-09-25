class_name Cards
extends RefCounted
## Shards and relics as cards: icon, name in its rarity's colour, what it costs, what it does, and (for a shard) the
## code itself, which is the point of the game.


## A shard's card. `summary` is false on a difficulty that shows only code; `code_lines` caps the code shown (0: all).
## `wide` puts the code beside the rest instead of under it, so whole lines show where there is room across.
static func shard(
	item: Dictionary, language: String, summary := true, code_lines := 0, action: Control = null, wide := false
) -> PanelContainer:
	var title := Ui.tint(Ui.label(item.get("name", item.get("id", "?")), "Subheading"), UiTheme.rarity(item.rarity))
	var icon := Ui.picture(ShardrunViews.art(item), Vector2(40, 40), "◆")
	var facts := "%s · %s" % [item.rarity, ShardrunViews.complexity(item)]
	if item.has("paradigm"):
		facts += " · %d mana" % int(item.get("cost", 0))
	elif int(item.get("cost", 0)) > 0:
		facts += " · +%d work" % int(item.cost)
	var head := Ui.hbox([icon, Ui.vbox([title, Ui.label(facts, "Faint")], 0)], 10)
	var body := Ui.vbox([head], 8)
	if summary and item.has("summary"):
		body.add_child(Ui.label(item.summary, "", true))
	var curse: Dictionary = item.get("curse", {})
	if not curse.is_empty():
		body.add_child(
			Ui.tint(Ui.label("Cursed: each cast burns %d Integrity." % int(curse.integrity), "", true), UiTheme.SHARD)
		)
	var listing := code(item, language, code_lines)
	if not wide:
		body.add_child(listing)
	var forge: Dictionary = item.get("forge", {})
	if forge.has("into"):
		var verb := {"repair": "repairs", "optimize": "optimises"}.get(forge.get("verb"), "upgrades") as String
		var into: Dictionary = (Game.catalog.get("shards", {}) as Dictionary).get(forge.into, {})
		body.add_child(Ui.label("A forge %s it into %s." % [verb, into.get("name", forge.into)], "Faint", true))
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
		painted.append("[color=#6f5e46]… %d more lines[/color]" % (lines.size() - max_lines))
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
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
	var colour := UiTheme.SHARD if item.get("cursed", false) else UiTheme.rarity(item.rarity)
	var title := Ui.tint(Ui.label(item.name, "Subheading"), colour)
	var icon := Ui.picture("shardrun/relic-" + String(item.get("icon", item.id)), Vector2(40, 40), "✦")
	var kind := "cursed relic" if item.get("cursed", false) else "%s relic" % item.rarity
	var head := Ui.hbox([icon, Ui.vbox([title, Ui.label(kind, "Faint")], 0)], 10)
	var body := Ui.vbox([head, Ui.label(item.summary, "", true)], 8)
	if item.has("flavor"):
		body.add_child(Ui.label(item.flavor, "Faint", true))
	if action != null:
		body.add_child(action)
	return Ui.panel(body, "Card")


## A relic's icon for the header, with its name and effect as a tooltip.
static func relic_icon(item: Dictionary) -> Control:
	var icon := Ui.picture("shardrun/relic-" + String(item.get("icon", item.id)), Vector2(30, 30), "✦")
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	icon.tooltip_text = "%s%s\n%s" % [item.name, " (cursed)" if item.get("cursed", false) else "", item.summary]
	return icon
