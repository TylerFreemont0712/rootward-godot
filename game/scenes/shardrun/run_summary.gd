class_name RunSummary
extends RefCounted
## A run in numbers: the score and how it was made, and what the run did. The end of a run shows it, and so does the
## Stats panel during one.

const ENDINGS := {
	"won": ["The Machine is cleared", UiTheme.PASS],
	"lost": ["Kernel panic", UiTheme.FAIL],
	"abandoned": ["You climbed back out", UiTheme.MUTED],
}
const PARTS := ["progress", "combat", "build", "survival", "tempo", "completion", "penalties"]


static func ending(state: Dictionary) -> Control:
	var said: Array = ENDINGS.get(state.status, ["The run", UiTheme.AMBER])
	var title := Ui.tint(Ui.label(said[0], "Title"), said[1])
	return Ui.vbox([title, score(state)], 12)


static func score(state: Dictionary) -> Control:
	var scored := ShardrunScore.score(state)
	var total := Ui.label(str(int(scored.total)), "Big")
	var rank := Ui.tint(Ui.label(scored.rank, "Big"), UiTheme.SHARD)
	var head := Ui.hbox([Ui.label("SCORE", "Faint"), total, Ui.label("rank", "Faint"), rank], 12)
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	var parts := GridContainer.new()
	parts.columns = 4
	parts.add_theme_constant_override("h_separation", 24)
	for part: String in PARTS:
		var value := int(scored.breakdown[part])
		if value == 0 and part in ["completion", "penalties"]:
			continue
		parts.add_child(Ui.label(part, "Muted"))
		parts.add_child(Ui.label(("-%d" if part == "penalties" else "%d") % value, ""))
	return Ui.vbox([head, parts, totals(state)], 10)


static func totals(state: Dictionary) -> Control:
	var stats: Dictionary = state.stats
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	var rows := [
		["layers cleared", stats.layers],
		["fights", stats.fights],
		["turns", stats.turns],
		["casts", stats.casts],
		["damage dealt", stats.damage],
		["best cast", stats.best_cast],
		["bolts", stats.bolts],
		["fizzled", stats.fizzled],
		["shards taken", stats.shards],
		["relics", stats.relics],
		["mana spent", stats.mana_spent],
	]
	for row: Array in rows:
		grid.add_child(Ui.label(row[0], "Muted"))
		grid.add_child(Ui.label(str(int(row[1])), ""))
	return grid


## The Stats panel during a run: the score so far, the totals, and damage by spell.
static func stats_panel(state: Dictionary) -> Control:
	var column := Ui.vbox([Ui.label("This run", "Heading"), score(state)], 12)
	var by_spell: Dictionary = state.stats.get("damage_by_spell", {})
	if not by_spell.is_empty():
		column.add_child(Ui.label("Damage by spell", "Subheading"))
		for spell: Dictionary in state.spells:
			if by_spell.has(spell.id):
				column.add_child(Ui.hbox([Ui.label(spell.name, "Muted"), Ui.label(str(int(by_spell[spell.id])), "")]))
	return column
