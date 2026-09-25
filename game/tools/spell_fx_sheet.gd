extends Control
## Every spell effect on a dark stage, caught at several moments of its life, for a screenshot (ADR-0008):
##   ROOTWARD_FX_SHEET=impacts scripts/screenshot.sh res://tools/spell_fx_sheet.tscn shots/fx-impacts.png 1
##   ROOTWARD_FX_SHEET=flight  scripts/screenshot.sh res://tools/spell_fx_sheet.tscn shots/fx-flight.png 1
## Each column is started early by its phase, so at the capture (CAPTURE seconds in, when `shot_ready` fires) the
## columns sit at those phases. Timed in seconds, not frames: a headless run draws frames far faster than 60 a second.

signal shot_ready

const CAPTURE := 1.6
const PHASES: Array[float] = [0.1, 0.25, 0.45, 0.7]
const ELEMENTS: Array[String] = ["none", "fire", "frost", "spark"]

var _stage: Control


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#171422")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	var sheet := OS.get_environment("ROOTWARD_FX_SHEET")
	if sheet == "flight":
		_flight()
	elif sheet == "strikes":
		_strikes()
	else:
		_impacts()
	_later(
		CAPTURE,
		func() -> void:
			set_meta("shot_ready", true)
			shot_ready.emit()
	)


func _later(seconds: float, action: Callable) -> void:
	get_tree().create_timer(maxf(0.0, seconds)).timeout.connect(action)


func _impacts() -> void:
	var rows := ELEMENTS.size() + 1
	for row in rows:
		for column in PHASES.size():
			var at := Vector2(300 + column * 420, 120 + row * 210)
			var phase: float = PHASES[column]
			if row < ELEMENTS.size():
				var element: String = ELEMENTS[row]
				var seconds := 0.62
				_later(
					CAPTURE - phase * seconds,
					func() -> void:
						var fx := BattleFX.spawn(
							_stage, BattleFX.Kind.BURST, at, UiTheme.element(element), seconds, element
						)
						fx.scale = Vector2.ONE * 0.8
				)
			else:
				_later(
					CAPTURE - phase * 0.75,
					func() -> void:
						BattleFX.spawn(_stage, BattleFX.Kind.CAST, at, UiTheme.element("none"), 0.75, "none")
				)
	for row in rows:
		_label(["none", "fire", "frost", "spark", "cast seal"][row], Vector2(30, 110 + row * 210))


func _flight() -> void:
	for row in ELEMENTS.size():
		var element: String = ELEMENTS[row]
		var from := Vector2(120, 110 + row * 165)
		var to := Vector2(1800, 90 + row * 165)
		for column in 2:
			var phase: float = [0.35, 0.8][column]
			var seconds := 0.7
			_later(
				CAPTURE - phase * seconds,
				func() -> void:
					var bolt := BattleFX.spawn(
						_stage, BattleFX.Kind.BOLT, from, UiTheme.element(element), seconds + 0.05, element
					)
					bolt.set_flight(from, to, 60.0)
					var tween := bolt.create_tween()
					tween.tween_method(bolt.set_flight_progress, 0.0, 1.0, seconds)
					tween.tween_callback(bolt.finish)
			)
		_label(element, Vector2(30, 100 + row * 165))
	for column in PHASES.size():
		var phase: float = PHASES[column]
		_later(
			CAPTURE - phase * 0.95,
			func() -> void:
				BattleFX.spawn(_stage, BattleFX.Kind.WARD, Vector2(220 + column * 420, 900), UiTheme.TEAL, 0.95, "ward")
		)
	_label("ward", Vector2(30, 890))


## Each element's strike in four moments (falling or rising, the impact, holding, leaving), then a wave and a vortex.
func _strikes() -> void:
	var phases: Array[float] = [0.06, 0.2, 0.4, 0.7]
	for column in ELEMENTS.size():
		var element: String = ELEMENTS[column]
		for row in phases.size():
			var phase: float = phases[row]
			# Four columns of elements, their moments side by side at half size.
			var at := Vector2(130 + column * 460 + (row % 2) * 220, 330 + (row / 2) * 330)
			_later(
				CAPTURE - phase * 0.8,
				func() -> void:
					var fx := BattleFX.spawn(_stage, BattleFX.Kind.STRIKE, at, UiTheme.element(element), 0.8, element)
					fx.scale = Vector2.ONE * 0.62
			)
		_label(element, Vector2(90 + column * 460, 20))
	_later(
		CAPTURE - 0.35 * 0.9,
		func() -> void:
			BattleFX.spawn(_stage, BattleFX.Kind.WAVE, Vector2(700, 950), UiTheme.element("fire"), 0.9, "fire")
	)
	_later(
		CAPTURE - 0.4 * 0.62,
		func() -> void:
			BattleFX.spawn(_stage, BattleFX.Kind.VORTEX, Vector2(1500, 900), UiTheme.element("none"), 0.62, "none")
	)
	_label("wave (fire)", Vector2(620, 1040))
	_label("vortex", Vector2(1460, 1040))


func _label(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9))
	add_child(label)
