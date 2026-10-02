class_name RuneCode
extends Control
## Code drawn by hand, for the Shardrun's live program (ADR-0012). A line that is new since the last `show_lines` is
## written in like a spell: each character first appears as a glowing rune that flickers, then cools into the real
## character in its syntax colour, left to right behind a bright point, as if a quill were writing. Long lines wrap
## to the width they are given.
##
## LEARN: a Control can draw itself. Override _draw() with draw_* calls and ask for queue_redraw() whenever the picture
## should change: here every frame while runes are settling, and never again once the code is still.

const FONT_SIZE := 14
const GUTTER := 34.0
const PAD := 6.0
const LINE_GAP := 3.0
## Seconds between one character's rune and the next's, and between one new line starting and the next.
const CHAR_DELAY := 0.009
const LINE_STAGGER := 0.075
## How long a character is a rune (its last SETTLE seconds a crossfade), and how long it then glows white-hot.
const RUNE_TIME := 0.36
const SETTLE := 0.14
const COOL := 0.3
const FLICKER := 0.06
const FLASH_TIME := 1.5
## A continuation row of a wrapped line starts this many columns further in than its line.
const WRAP_INDENT := 4
## How long a note's pop lasts: it swells, flashes and (when strong) shakes, then settles.
const POP_TIME := 0.5
## Runes as strokes in a unit cell (x right, y down), after the elder futhark: fehu, uruz, thurisaz, ansuz, raido,
## kaunan, gebo, wunjo, hagalaz, naudiz, isa, jera, eihwaz, algiz, sowilo, tiwaz, berkanan, mannaz, ingwaz, dagaz.
const RUNES: Array = [
	[
		[Vector2(0.3, 0), Vector2(0.3, 1)],
		[Vector2(0.3, 0.1), Vector2(0.8, 0.35)],
		[Vector2(0.3, 0.4), Vector2(0.8, 0.65)]
	],
	[[Vector2(0.25, 1), Vector2(0.25, 0), Vector2(0.75, 0.3), Vector2(0.75, 1)]],
	[[Vector2(0.3, 0), Vector2(0.3, 1)], [Vector2(0.3, 0.25), Vector2(0.75, 0.5), Vector2(0.3, 0.75)]],
	[
		[Vector2(0.3, 0), Vector2(0.3, 1)],
		[Vector2(0.3, 0), Vector2(0.75, 0.25)],
		[Vector2(0.3, 0.3), Vector2(0.75, 0.55)]
	],
	[
		[Vector2(0.3, 1), Vector2(0.3, 0), Vector2(0.75, 0.25), Vector2(0.3, 0.5)],
		[Vector2(0.3, 0.5), Vector2(0.8, 1)],
	],
	[[Vector2(0.7, 0.1), Vector2(0.3, 0.5), Vector2(0.7, 0.9)]],
	[[Vector2(0.2, 0.1), Vector2(0.8, 0.9)], [Vector2(0.8, 0.1), Vector2(0.2, 0.9)]],
	[[Vector2(0.3, 1), Vector2(0.3, 0), Vector2(0.75, 0.25), Vector2(0.3, 0.5)]],
	[
		[Vector2(0.25, 0), Vector2(0.25, 1)],
		[Vector2(0.75, 0), Vector2(0.75, 1)],
		[Vector2(0.25, 0.35), Vector2(0.75, 0.65)]
	],
	[[Vector2(0.5, 0), Vector2(0.5, 1)], [Vector2(0.25, 0.35), Vector2(0.75, 0.65)]],
	[[Vector2(0.5, 0), Vector2(0.5, 1)]],
	[
		[Vector2(0.45, 0.1), Vector2(0.2, 0.35), Vector2(0.45, 0.6)],
		[Vector2(0.55, 0.4), Vector2(0.8, 0.65), Vector2(0.55, 0.9)],
	],
	[[Vector2(0.75, 0.2), Vector2(0.5, 0), Vector2(0.5, 1), Vector2(0.25, 0.8)]],
	[[Vector2(0.5, 0), Vector2(0.5, 1)], [Vector2(0.2, 0.05), Vector2(0.5, 0.4), Vector2(0.8, 0.05)]],
	[[Vector2(0.7, 0.05), Vector2(0.3, 0.35), Vector2(0.7, 0.65), Vector2(0.3, 0.95)]],
	[[Vector2(0.5, 0), Vector2(0.5, 1)], [Vector2(0.2, 0.35), Vector2(0.5, 0), Vector2(0.8, 0.35)]],
	[
		[Vector2(0.3, 0), Vector2(0.3, 1)],
		[Vector2(0.3, 0), Vector2(0.75, 0.25), Vector2(0.3, 0.5), Vector2(0.75, 0.75), Vector2(0.3, 1)],
	],
	[
		[Vector2(0.2, 1), Vector2(0.2, 0), Vector2(0.8, 0.5)],
		[Vector2(0.8, 1), Vector2(0.8, 0), Vector2(0.2, 0.5)],
	],
	[[Vector2(0.5, 0.15), Vector2(0.8, 0.5), Vector2(0.5, 0.85), Vector2(0.2, 0.5), Vector2(0.5, 0.15)]],
	[
		[Vector2(0.2, 0), Vector2(0.2, 1), Vector2(0.8, 0), Vector2(0.8, 1), Vector2(0.2, 0)],
	],
]

var language := "python"
## The colour runes burn with: the chosen paradigm's.
var glow := UiTheme.SHARD
## The line being run during a cast (its index), or -1.
var cursor := -1
## A loop being run: the lines it spans ({from, to}) get a bracket in the gutter with a turning arrow; {} when none.
var loop_span: Dictionary = {}
## A wash of colour over the whole code when the volley turns to an element, fading out.
var _wash := Color.TRANSPARENT
var _wash_at := -10.0
## [{text, key, colours: PackedColorArray, born, note, note_colour, warn, rows: [{from, to, indent}], top}]
var _lines: Array[Dictionary] = []
var _clock := 0.0
var _font: Font
var _char_w := 8.0
var _line_h := 18.0
var _ascent := 12.0
var _rows := 0


func _init() -> void:
	_font = UiTheme.code_font()
	_char_w = _font.get_char_size("M".unicode_at(0), FONT_SIZE).x
	_line_h = _font.get_height(FONT_SIZE) + LINE_GAP
	_ascent = _font.get_ascent(FONT_SIZE)
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size.x = 240
	set_process(false)
	resized.connect(_layout)


## Shows these lines ([{text, key, note?, note_colour?, warn?, dead?}]). A line whose key is new, or whose text
## changed, is written in with runes when `animate`; the others stay as they are. Returns the index of the first new
## line, or -1.
func show_lines(lines: Array[Dictionary], animate := true) -> int:
	var old := {}
	for line in _lines:
		old[line.key] = line
	var next: Array[Dictionary] = []
	var fresh := 0
	var first := -1
	for index in lines.size():
		var source: Dictionary = lines[index]
		var text: String = source.text
		var line := {
			"text": text,
			"key": source.key,
			"colours": _colours(text),
			"born": -1.0,
			"note": String(source.get("note", "")),
			"note_colour": source.get("note_colour", UiTheme.FAINT),
			"warn": bool(source.get("warn", false)),
		}
		if source.get("dead", false):
			# Dead code (after an Unreachable's `return`, ADR-0026): written, greyed, never run.
			var faded := PackedColorArray()
			faded.resize(text.length())
			faded.fill(Color(UiTheme.FAINT, 0.55))
			line.colours = faded
		var was: Dictionary = old.get(source.key, {})
		if not was.is_empty() and was.text == text:
			line.born = was.born
		elif animate:
			line.born = _clock + fresh * LINE_STAGGER
			fresh += 1
			if first < 0:
				first = index
		next.append(line)
	_lines = next
	_layout()
	if fresh > 0:
		set_process(true)
	queue_redraw()
	return first


## Where line `index` starts, from the top of this control: for scrolling it into view.
func line_top(index: int) -> float:
	if index < 0 or index >= _lines.size():
		return 0.0
	return float(_lines[index].top)


func line_height() -> float:
	return _line_h


func set_cursor(index: int) -> void:
	cursor = index
	queue_redraw()


## Writes `note` at the right of line `index`. `pop` (0 to 1) makes it land like a hit: it swells, flashes white and,
## when strong, shakes, as much as the number deserves.
func set_note(index: int, note: String, colour: Color, pop := 0.0) -> void:
	if index < 0 or index >= _lines.size():
		return
	_lines[index].note = note
	_lines[index].note_colour = colour
	if pop > 0.0:
		_lines[index].pop = clampf(pop, 0.0, 1.0)
		_lines[index].pop_at = _clock
		set_process(true)
	queue_redraw()


## The index of the line keyed `key` (ProgramSource's keys), or -1.
func line_of(key: String) -> int:
	for index in _lines.size():
		if _lines[index].key == key:
			return index
	return -1


func text_of(index: int) -> String:
	return _lines[index].text if index >= 0 and index < _lines.size() else ""


func line_count() -> int:
	return _lines.size()


func set_loop(from: int, to: int) -> void:
	loop_span = {"from": from, "to": to}
	set_process(true)
	queue_redraw()


## Sweeps a wash of `colour` over the code (the volley just turned to an element), and runs its highlights in it.
func wash(colour: Color) -> void:
	_wash = colour
	_wash_at = _clock
	glow = colour
	set_process(true)
	queue_redraw()


func clear_loop() -> void:
	loop_span = {}
	queue_redraw()


## Whether anything is still moving: a rune settling, a note popping, a loop turning.
func writing() -> bool:
	if not loop_span.is_empty() or _clock < _wash_at + 0.7:
		return true
	for line in _lines:
		if float(line.born) >= 0.0 and _clock < _settled_at(line):
			return true
		if _clock < float(line.get("pop_at", -10.0)) + POP_TIME:
			return true
	return false


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()
	if not writing():
		set_process(false)


func _settled_at(line: Dictionary) -> float:
	var writing_time := String(line.text).length() * CHAR_DELAY + RUNE_TIME + COOL
	return float(line.born) + maxf(writing_time, FLASH_TIME)


## Each character's syntax colour.
func _colours(text: String) -> PackedColorArray:
	var colours := PackedColorArray()
	for token in CodeColors.tokens(text, language):
		var colour := Color(token.colour) if token.colour != "" else UiTheme.TEXT
		for i in String(token.text).length():
			colours.append(colour)
	return colours


## Lays the lines out in rows for the current width: a line too long for it wraps, at a space when there is one.
func _layout() -> void:
	var columns := maxi(20, floori((size.x - GUTTER - PAD * 2.0) / _char_w))
	var row := 0
	for line in _lines:
		var text: String = line.text
		var indent := text.length() - text.lstrip(" ").length()
		var rows: Array[Dictionary] = []
		var from := 0
		var shift := 0
		while true:
			var room := columns - shift
			if text.length() - from <= room:
				rows.append({"from": from, "to": text.length(), "shift": shift})
				break
			var cut := text.rfind(" ", from + room)
			if cut <= from + room / 3:
				cut = from + room
			rows.append({"from": from, "to": cut, "shift": shift})
			from = cut
			while from < text.length() and text[from] == " ":
				from += 1
			shift = mini(indent + WRAP_INDENT, columns / 2)
		line.rows = rows
		line.top = PAD + row * _line_h
		row += rows.size()
	_rows = row
	var height := PAD * 2.0 + _rows * _line_h
	if not is_equal_approx(custom_minimum_size.y, height):
		custom_minimum_size.y = height


func _draw() -> void:
	for index in _lines.size():
		_draw_line(index, _lines[index])
	var washed := _clock - _wash_at
	if washed < 0.7:
		draw_rect(Rect2(Vector2.ZERO, size), Color(_wash, 0.22 * (1.0 - washed / 0.7)))


func _draw_line(index: int, line: Dictionary) -> void:
	var top: float = line.top
	var height: float = (line.rows as Array).size() * _line_h
	var age := _clock - float(line.born) if float(line.born) >= 0.0 else 1e6
	if index == cursor:
		draw_rect(Rect2(0, top - 1, size.x, height), Color(glow, 0.2))
		draw_rect(Rect2(0, top - 1, 3, height), glow)
	if age < FLASH_TIME:
		draw_rect(Rect2(GUTTER - 4, top - 1, size.x - GUTTER + 4, height), Color(glow, 0.16 * (1.0 - age / FLASH_TIME)))
	var baseline := top + _ascent
	var number := Color(UiTheme.WARN, 0.95) if line.warn else Color(UiTheme.FAINT, 0.65)
	draw_string(
		_font, Vector2(0, baseline), str(index + 1), HORIZONTAL_ALIGNMENT_RIGHT, GUTTER - 10, FONT_SIZE - 3, number
	)
	if line.warn:
		draw_string(_font, Vector2(2, baseline), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UiTheme.WARN)
	var text: String = line.text
	var colours: PackedColorArray = line.colours
	var settled := age >= String(text).length() * CHAR_DELAY + RUNE_TIME + COOL
	var rows: Array = line.rows
	for r in rows.size():
		var chunk: Dictionary = rows[r]
		var y := top + r * _line_h
		var x0 := GUTTER + PAD + int(chunk.shift) * _char_w
		if settled:
			_draw_run(text, colours, int(chunk.from), int(chunk.to), Vector2(x0, y + _ascent))
			continue
		for at in range(int(chunk.from), int(chunk.to)):
			_draw_char(
				index,
				text[at],
				colours[at],
				Vector2(x0 + (at - int(chunk.from)) * _char_w, y),
				age - at * CHAR_DELAY,
				at
			)
	if not settled:
		_draw_quill(line, age)
	if line.note != "":
		_draw_note(line, baseline)
	if not loop_span.is_empty() and index == int(loop_span.from):
		_draw_loop()


## A note at the line's right: when it has just popped, larger, brighter and (for a strong pop) shaking, easing back.
func _draw_note(line: Dictionary, baseline: float) -> void:
	var colour: Color = line.note_colour
	var font_size := FONT_SIZE - 2
	var shake := 0.0
	var swell := 0.0
	var since := _clock - float(line.get("pop_at", -10.0))
	if since < POP_TIME:
		var left := 1.0 - since / POP_TIME
		var pop: float = line.get("pop", 0.0)
		swell = left * left * pop
		font_size = FONT_SIZE - 2 + roundi(10.0 * swell)
		colour = colour.lerp(Color.WHITE, 0.7 * swell)
		shake = sin(since * 90.0) * 3.0 * swell if pop > 0.5 else 0.0
	# A dark plate under the note, so it reads over a long line of code, lit while it pops.
	var width := _font.get_string_size(line.note, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var plate := Rect2(size.x - PAD - width - 6, baseline - _ascent - 2, width + 10, _line_h)
	draw_rect(plate, Color(0.07, 0.05, 0.08, 0.92))
	if swell > 0.0:
		draw_rect(plate.grow(2.0), Color(line.note_colour, 0.25 * swell))
	draw_string(_font, Vector2(shake, baseline), line.note, HORIZONTAL_ALIGNMENT_RIGHT, size.x - PAD, font_size, colour)


## The loop being run: a bracket down the gutter from its header to its last line, arrows at both ends, and a turning
## arrow by the header.
func _draw_loop() -> void:
	var from := int(loop_span.from)
	var to := int(loop_span.to)
	if from < 0 or to >= _lines.size():
		return
	var top := float(_lines[from].top) + 2.0
	var bottom := float(_lines[to].top) + (_lines[to].rows as Array).size() * _line_h - 2.0
	var x := GUTTER - 3.0
	var colour := Color(glow.lightened(0.3), 0.9)
	draw_line(Vector2(x, top), Vector2(x, bottom), colour, 2.0)
	draw_line(Vector2(x, top), Vector2(x + 5, top), colour, 2.0)
	draw_line(Vector2(x, bottom), Vector2(x + 5, bottom), colour, 2.0)
	draw_colored_polygon(
		PackedVector2Array([Vector2(x + 6, top), Vector2(x + 1, top - 4), Vector2(x + 1, top + 4)]), colour
	)
	var centre := Vector2(GUTTER - 16.0, top + _line_h * 0.4)
	var turn := _clock * 7.0
	draw_arc(centre, 6.0, turn, turn + TAU * 0.75, 12, colour, 2.0, true)
	var tip := centre + Vector2(cos(turn + TAU * 0.75), sin(turn + TAU * 0.75)) * 6.0
	draw_circle(tip, 2.2, colour)


## A settled stretch of a line, one draw per run of one colour.
func _draw_run(text: String, colours: PackedColorArray, from: int, to: int, at: Vector2) -> void:
	var start := from
	while start < to:
		var end := start + 1
		while end < to and colours[end] == colours[start]:
			end += 1
		var x := at.x + (start - from) * _char_w
		draw_string(
			_font,
			Vector2(x, at.y),
			text.substr(start, end - start),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			FONT_SIZE,
			colours[start]
		)
		start = end


## One character `t` seconds into its writing: nothing yet, a rune, a rune fading into the character, or the character
## cooling from white to its colour.
func _draw_char(line_index: int, character: String, colour: Color, at: Vector2, t: float, column: int) -> void:
	if t < 0.0 or character == " ":
		return
	var baseline := Vector2(at.x, at.y + _ascent)
	if t < RUNE_TIME - SETTLE:
		_draw_rune(at, line_index, column, t, 1.0)
	elif t < RUNE_TIME:
		var k := (t - (RUNE_TIME - SETTLE)) / SETTLE
		_draw_rune(at, line_index, column, t, 1.0 - k)
		draw_char(_font, baseline, character, FONT_SIZE, Color(Color.WHITE, k))
	else:
		var cool := clampf((t - RUNE_TIME) / COOL, 0.0, 1.0)
		draw_char(_font, baseline, character, FONT_SIZE, Color.WHITE.lerp(colour, cool))


func _draw_rune(at: Vector2, line_index: int, column: int, t: float, alpha: float) -> void:
	var shape: Array = RUNES[(line_index * 31 + column * 17 + int(t / FLICKER) * 7) % RUNES.size()]
	var cell := Rect2(at + Vector2(_char_w * 0.14, _line_h * 0.16), Vector2(_char_w * 0.72, _line_h * 0.6))
	var hot := Color.WHITE.lerp(glow, clampf(t / (RUNE_TIME - SETTLE), 0.0, 1.0))
	for stroke: Array in shape:
		var points := PackedVector2Array()
		for point: Vector2 in stroke:
			points.append(cell.position + point * cell.size)
		draw_polyline(points, Color(glow, 0.3 * alpha), 3.4, true)
		draw_polyline(points, Color(hot, alpha), 1.3, true)


## The bright point writing the line: where its next rune appears.
func _draw_quill(line: Dictionary, age: float) -> void:
	var at := age / CHAR_DELAY
	var text: String = line.text
	if at < 0.0 or at >= text.length():
		return
	var rows: Array = line.rows
	for r in rows.size():
		var chunk: Dictionary = rows[r]
		if at < float(chunk.to) or r == rows.size() - 1:
			var x := GUTTER + PAD + (int(chunk.shift) + at - float(chunk.from)) * _char_w
			var point := Vector2(x, float(line.top) + r * _line_h + _line_h * 0.5)
			draw_circle(point, 7.0, Color(glow, 0.18))
			draw_circle(point, 3.2, Color(glow.lightened(0.4), 0.7))
			draw_circle(point, 1.6, Color.WHITE)
			return
