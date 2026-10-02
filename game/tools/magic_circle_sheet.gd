extends Control
## Every tier of the magic circle (MagicCircle, ADR-0030) caught as it writes itself, complete, firing and closing:
##   scripts/screenshot.sh res://tools/magic_circle_sheet.tscn shots/circles.png 10
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
	var tiers := MagicCircle.TIERS.size()
	for tier in tiers:
		for column in MOMENTS.size():
			var moment: Array = MOMENTS[column]
			var at := Vector2(200 + column * 360, 140 + tier * 250)
			var circle := MagicCircle.cast(self, at, tier, element, 80.0 + tier * 12.0, "knapsackStrike()  charge()  ")
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
