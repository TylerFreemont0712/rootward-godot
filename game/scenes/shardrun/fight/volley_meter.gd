class_name VolleyMeter
extends Control
## The volley the Program has made so far, at a glance (ADR-0015): a pip for each bolt, coloured by its element and as
## large as the bolts are strong, and the volley's whole power as a big number that counts up and lands like a hit.
## Every number is the sandbox's: the whole volley's power and elements after each stage.

## Pips drawn at most (a bigger volley shows "+N").
const MOST_PIPS := 28
const POP_TIME := 0.45

var colour := Color("#9b6cff")
var _bolts := 0
var _power := 0.0
var _shown_power := 0.0
var _elements: Dictionary = {}
var _pop_at := -10.0
var _pop := 0.0
var _clock := 0.0
var _font: Font
var _big: Font


func _init() -> void:
	custom_minimum_size.y = 48
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiTheme.ui_font(600)
	_big = UiTheme.crt_font()
	set_process(false)


## Shows a volley of `bolts` bolts with `power` in all and `elements` ({element: count}). With `pop`, the power counts
## up from what was shown and the number lands as hard as the change deserves.
func show_volley(bolts: int, power: float, elements: Dictionary, pop := false) -> void:
	var change := absf(power - _power)
	_bolts = bolts
	_power = power
	_elements = elements
	colour = colour_of(elements)
	if pop:
		_pop = clampf(log(change + 1.0) / log(2.0) / 7.0, 0.2, 1.0)
		_pop_at = _clock
		set_process(true)
	else:
		_shown_power = power
	queue_redraw()


## The colour of a volley: its commonest element's (violet for none).
static func colour_of(elements: Dictionary) -> Color:
	return Color(SpellAnim.RAMPS.get(dominant(elements), SpellAnim.RAMPS.none)[1])


## The element most of a volley's power is in ("none" for none).
static func dominant(elements: Dictionary) -> String:
	var best := "none"
	var most := -1
	for element: String in elements:
		if int(elements[element]) > most:
			most = int(elements[element])
			best = element
	return best


func _process(delta: float) -> void:
	_clock += delta
	_shown_power = move_toward(_shown_power, _power, maxf(1.0, absf(_power - _shown_power)) * delta * 8.0)
	queue_redraw()
	if _clock > _pop_at + POP_TIME and is_equal_approx(_shown_power, _power):
		set_process(false)


func _draw() -> void:
	var middle := size.y * 0.5
	var average := _power / maxf(1.0, float(_bolts))
	var pip := clampf(5.0 + average / 3.0, 5.0, 11.0)
	var order: Array[String] = []
	for element: String in _elements:
		for i in int(_elements[element]):
			order.append(element)
	var x := pip + 2.0
	var right_edge := size.x - 190.0
	var drawn := 0
	for element in order:
		if drawn >= MOST_PIPS or x > right_edge:
			break
		var tint := Color(SpellAnim.RAMPS.get(element, SpellAnim.RAMPS.none)[1])
		var diamond := PackedVector2Array(
			[
				Vector2(x, middle - pip),
				Vector2(x + pip * 0.7, middle),
				Vector2(x, middle + pip),
				Vector2(x - pip * 0.7, middle)
			]
		)
		draw_circle(Vector2(x, middle), pip * 1.4, Color(tint, 0.18))
		draw_colored_polygon(diamond, tint.lightened(0.15))
		x += pip * 1.7 + 2.0
		drawn += 1
	if _bolts > drawn:
		draw_string(
			_font, Vector2(x + 2, middle + 5), "+%d" % (_bolts - drawn), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour
		)
	# The power: a big number, swelling and flashing as it lands.
	var since := _clock - _pop_at
	var swell := 0.0
	if since < POP_TIME:
		var left := 1.0 - since / POP_TIME
		swell = left * left * _pop
	var font_size := 42 + roundi(26.0 * swell)
	var tint := colour.lerp(Color.WHITE, 0.6 * swell)
	var shake := sin(since * 80.0) * 4.0 * swell if _pop > 0.5 else 0.0
	var number := str(roundi(_shown_power))
	var width := _big.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(size.x - 70.0 - width + shake, middle + font_size * 0.32)
	if swell > 0.0:
		draw_circle(Vector2(at.x + width * 0.5, middle), width * 0.7 + 8.0, Color(colour, 0.22 * swell))
	draw_string(_big, at, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
	draw_string(
		_font, Vector2(size.x - 64.0, middle - 2.0), "power", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(colour, 0.8)
	)
	var noun := "bolt" if _bolts == 1 else "bolts"
	draw_string(
		_font,
		Vector2(size.x - 64.0, middle + 13.0),
		"%d %s" % [_bolts, noun],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		UiTheme.MUTED
	)
