extends Control
## Every tier of the magic circle (MagicCircle, ADR-0030) caught as it writes itself, complete, firing and closing:
##   scripts/screenshot.sh res://tools/magic_circle_sheet.tscn shots/circles.png 10
## ROOTWARD_SHEET=stack shows the circle of 1 to 6 shards, each complete and large (the layers stack, ADR-0039);
## ROOTWARD_SHEET=time with ROOTWARD_SHARDS=N (1..6) shows one spell of N shards writing itself in six moments.
## ROOTWARD_ELEMENT picks the colours (none, fire, frost, spark), ROOTWARD_CIRCLE_STYLE the style (codex, rootglass,
## clockwork, constellation; ADR-0037).

const MOMENTS: Array[Array] = [
	["writing", 0.3], ["writing", 0.6], ["writing", 0.85], ["complete", 1.15], ["firing", 1.6]
]


func _ready() -> void:
	theme = UiTheme.shared()
	var backdrop := ColorRect.new()
	backdrop.color = Color("#120e14")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var element := OS.get_environment("ROOTWARD_ELEMENT")
	if element == "":
		element = "none"
	var sheet := OS.get_environment("ROOTWARD_SHEET")
	if sheet == "one":
		_one(element)
		return
	if sheet == "stack" or sheet == "time":
		_stack_sheet(sheet == "time", element)
		return
	var tiers := MagicCircle.TIERS.size()
	for tier in tiers:
		for column in MOMENTS.size():
			var moment: Array = MOMENTS[column]
			var at := Vector2(200 + column * 360, 140 + tier * 250)
			var circle := MagicCircle.cast(self, at, tier, element, 80.0 + tier * 12.0, "knapsackStrike()  charge()  ")
			circle.use_plan(CircleLayers.demo_plan(tier))
			circle.style = (
				OS.get_environment("ROOTWARD_CIRCLE_STYLE") if OS.get_environment("ROOTWARD_CIRCLE_STYLE") else "codex"
			)
			circle.set_process(false)
			# Played up to the moment in sixtieths, so its motes and sparks are where they would be.
			var until := float(moment[1]) * circle.form_time()
			while circle.clock < until:
				circle._process(1.0 / 60.0)
			if moment[0] == "firing":
				circle.pulse()
				for i in 5:
					circle._process(1.0 / 60.0)
			var label := Ui.label("tier %d · %s %.2fs" % [tier, moment[0], circle.clock], "Faint")
			label.position = at + Vector2(-90, 105)
			add_child(label)


## Large circles in a grid of three by two: shard counts 1 to 6 complete, or one spell's six moments.
func _stack_sheet(over_time: bool, element: String) -> void:
	var shards := clampi(int(OS.get_environment("ROOTWARD_SHARDS")), 1, 6) if over_time else 0
	var style := OS.get_environment("ROOTWARD_CIRCLE_STYLE")
	for cell in 6:
		var count := shards if over_time else cell + 1
		var tier := CircleLayers.tier_for(count)
		var at := Vector2(250 + (cell % 3) * 640, 260 + (cell / 3) * 520)
		var size := 150.0 + tier * 14.0
		var circle := MagicCircle.cast(
			self, at, tier, element, size, CircleLayers.words(CircleLayers.demo_cards(count)), 1.0, true
		)
		circle.use_plan(CircleLayers.plan(CircleLayers.demo_cards(count)))
		circle.style = style if style != "" else "codex"
		circle.set_process(false)
		var moments: Array[float] = [0.12, 0.3, 0.5, 0.7, 0.9, 1.2]
		var share: float = moments[cell] if over_time else 2.0
		while circle.clock < share * circle.form_time():
			circle._process(1.0 / 60.0)
		var words := "%d shard%s · tier %d" % [count, "" if count == 1 else "s", tier + 1]
		if over_time:
			words += " · %.0f%% of the writing" % (share * 100.0)
		var label := Ui.label(words, "Faint")
		label.position = at + Vector2(-110, size + 30)
		add_child(label)


## One circle of ROOTWARD_SHARDS shards, complete and as large as the sheet, to judge its layers close up.
func _one(element: String) -> void:
	var count := clampi(int(OS.get_environment("ROOTWARD_SHARDS")), 1, 6)
	var cards := CircleLayers.demo_cards(count)
	var circle := MagicCircle.cast(self, Vector2(620, 540), CircleLayers.tier_for(count), element, 400.0, "", 1.0, true)
	circle.use_plan(CircleLayers.plan(cards))
	var style := OS.get_environment("ROOTWARD_CIRCLE_STYLE")
	circle.style = style if style != "" else "codex"
	circle.set_process(false)
	while circle.clock < 2.2 * circle.form_time():
		circle._process(1.0 / 60.0)
