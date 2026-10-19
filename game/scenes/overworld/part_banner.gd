class_name PartBanner
extends Control
## The banner that says a part of the game is built (Concept/v0.4/01, section 8.6): 640 x 110 at the top centre, a
## turning gear, "NEW PART" (or "PART IMPROVED") in small amber capitals, the part's name, and what it does now. It
## slides in, holds for 3.5 seconds, and slides out. Its sounds are sfx-pass, then sfx-chime. Two calls in a row
## queue: the second slides in once the first has gone.
##
##   banner.show_part("The Menu", "Esc opens your menu now.")
##   banner.show_part("The Bag", "Your bag holds stacks now.", true)   # a later stage: "PART IMPROVED"
##   banner.busy()   # one is showing or waiting
##
## It takes no input and never holds the focus, so it can stay on screen while Hotaru talks.

const SIZE := Vector2(640, 110)
const SLIDE_TIME := 0.38
const HOLD_TIME := 3.5
const TOP := 22.0

## How long a banner holds, in seconds (a screenshot tool lengthens it).
var hold_time := HOLD_TIME
var _queue: Array[Dictionary] = []
var _showing := false
var _card: PanelContainer
var _gear: Control
var _kicker: Label
var _name: Label
var _line: Label
var _turn := 0.0
var _tween: Tween


func _ready() -> void:
	theme = OverworldStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_card.offset_left = -SIZE.x / 2.0
	_card.offset_right = SIZE.x / 2.0
	_card.offset_top = -SIZE.y - 30.0
	_card.offset_bottom = -30.0
	_card.custom_minimum_size = SIZE
	var box := PauseMenu.panel_style(Vector2(20, 12))
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 16
	_card.add_theme_stylebox_override("panel", box)
	add_child(_card)
	_gear = Control.new()
	_gear.custom_minimum_size = Vector2(80, 80)
	_gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gear.draw.connect(_draw_gear)
	_kicker = Ui.label("", "Muted")
	_kicker.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	_kicker.add_theme_color_override("font_color", UiTheme.AMBER)
	_name = Ui.label("", "Heading")
	_name.add_theme_font_size_override("font_size", 30)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.clip_text = true
	_line = Ui.label("", "Muted")
	_line.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	_line.add_theme_color_override("font_color", OverworldStyle.MUTED)
	_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_line.clip_text = true
	var words := Ui.vbox([_kicker, _name, _line], 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(Ui.hbox([_gear, words], 16))
	_card.visible = false


## Says that `part_name` is built, and `line` is what it does now. `improved` is for a later stage of a part that was
## already built (the banner then reads "PART IMPROVED"). A call while one is showing waits its turn.
func show_part(part_name: String, line: String, improved := false) -> void:
	_queue.append({"name": part_name, "line": line, "improved": improved})
	if not _showing:
		_next.call_deferred()


## Whether a banner is on screen or waiting to be.
func busy() -> bool:
	return _showing or not _queue.is_empty()


## How many banners are waiting behind the one on screen.
func waiting() -> int:
	return _queue.size()


func _next() -> void:
	if _showing or _queue.is_empty() or not is_inside_tree():
		return
	var banner: Dictionary = _queue.pop_front()
	_showing = true
	_kicker.text = Text.t("PART IMPROVED") if bool(banner.improved) else Text.t("NEW PART")
	_name.text = String(banner.name)
	_line.text = String(banner.line)
	_card.visible = true
	_card.offset_top = -SIZE.y - 30.0
	_card.offset_bottom = -30.0
	Sound.play("sfx-pass", 0.5)
	get_tree().create_timer(0.35).timeout.connect(func() -> void: Sound.play("sfx-chime", 0.5))
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_card, "offset_top", TOP, SLIDE_TIME)
	_tween.parallel().tween_property(_card, "offset_bottom", TOP + SIZE.y, SLIDE_TIME)
	_tween.tween_interval(hold_time)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_card, "offset_top", -SIZE.y - 30.0, SLIDE_TIME)
	_tween.parallel().tween_property(_card, "offset_bottom", -30.0, SLIDE_TIME)
	_tween.tween_callback(_done)


func _done() -> void:
	_showing = false
	_card.visible = false
	_next()


func _process(delta: float) -> void:
	if _showing and not Settings.reduced_motion:
		_turn += delta * 1.1
		_gear.queue_redraw()


func _draw_gear() -> void:
	GearArt.draw(_gear, _gear.size / 2.0, 32.0, _turn, true)
