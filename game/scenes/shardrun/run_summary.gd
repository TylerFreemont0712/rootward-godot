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


## How a run ended and its score. `title_variation` is the headline's label variation: "Title" at the end of a run,
## a smaller one where it shares a screen (the title screen).
static func ending(state: Dictionary, title_variation := "Title") -> Control:
	if state.has("trial"):
		var japanese: bool = Game.profile.get("preferred_language", "en") == "ja"
		var greeting := (
			"%s、やったね！" % Game.profile.get("name", "Player")
			if japanese
			else "Well played, %s." % Game.profile.get("name", "Player")
		)
		var title := Ui.tint(
			Ui.label("トライアル達成！" if japanese else "Pip's Trial complete!", title_variation), UiTheme.PASS
		)
		return Ui.vbox([Ui.label(greeting, "Subheading"), title, trial_score(state)], 12)
	var said: Array = ENDINGS.get(state.status, ["The run", UiTheme.AMBER])
	var title := Ui.tint(Ui.label(said[0], title_variation), said[1])
	var name := String(Game.profile.get("name", "Player"))
	var greeting := (
		"%s、おつかれさま！" % name if Game.profile.get("preferred_language", "en") == "ja" else "Well played, %s." % name
	)
	return Ui.vbox([Ui.label(greeting, "Subheading"), title, score(state)], 12)


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


static func trial_score(state: Dictionary) -> Control:
	var scored := TrialRules.score(state)
	var japanese: bool = Game.profile.get("preferred_language", "en") == "ja"
	var head := Ui.hbox(
		[Ui.label("トライアルのスコア" if japanese else "TRIAL SCORE", "Faint"), Ui.label("%d / 100" % scored.total, "Big")], 12
	)
	var names := {
		"progress": "進みぐあい" if japanese else "progress",
		"combat": "戦い" if japanese else "combat",
		"build": "カードと遺物" if japanese else "build",
		"survival": "生き残り" if japanese else "survival",
		"tempo": "速さ" if japanese else "tempo",
	}
	var parts := GridContainer.new()
	parts.columns = 4
	for part: String in names:
		parts.add_child(Ui.label(names[part], "Muted"))
		parts.add_child(Ui.label(str(int(scored.breakdown[part]))))
	var stats: Dictionary = state.stats
	var facts := "%d回の戦い · %d回の実行 · %d回のやり直し" if japanese else "%d fights · %d casts · %d retries"
	var summary := Ui.label(facts % [int(stats.fights), int(stats.casts), int(state.trial.failures)], "Muted")
	return Ui.vbox([head, parts, summary], 10)


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
	var skin := Settings.character_skin
	var portrait := TextureRect.new()
	var image := {
		"vesper": "res://assets/sprites/vesper/profile.png",
		"emberfox": "res://characters/emberfox/emberfox_front.png",
		"shibu": "res://assets/portraits/shibu.png",
		"dummy": "res://assets/portraits/dummy.png",
	}
	var portrait_path: String = image.get(skin, image.emberfox)
	portrait.texture = load(portrait_path) as Texture2D if ResourceLoader.exists(portrait_path) else null
	portrait.custom_minimum_size = Vector2(136, 136)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var names := {
		"vesper": ["Vesper", "Star-Script Witch"],
		"emberfox": ["Emberfox", "Salvage Runner"],
		"shibu": ["Shibu", "Hovering Caster"],
		"dummy": ["Motion Dummy", "Animation lab"],
	}
	var identity_text: Array = names.get(skin, names.emberfox)
	var identity := Ui.vbox(
		[
			Ui.label("ARTIFICER · FIELD PORTRAIT", "Faint"),
			Ui.label(identity_text[0], "Subheading"),
			Ui.label(identity_text[1], "Muted", true)
		],
		5
	)
	var column := (
		Ui
		. vbox(
			[
				Ui.label("This run", "Heading"),
				Ui.hbox([portrait, identity, Ui.spacer(), score(state)], 14),
			],
			12
		)
	)
	var by_spell: Dictionary = state.stats.get("damage_by_spell", {})
	if not by_spell.is_empty():
		column.add_child(Ui.label("Damage by spell", "Subheading"))
		for spell: Dictionary in state.spells:
			if by_spell.has(spell.id):
				column.add_child(Ui.hbox([Ui.label(spell.name, "Muted"), Ui.label(str(int(by_spell[spell.id])), "")]))
	return column
