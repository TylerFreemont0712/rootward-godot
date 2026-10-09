extends SceneTree
## How long the town's boots take to answer (ADR-0061): BootsRun on the 40 x 30 town with the four keys, in Python and
## in JavaScript, five runs each. Prints the median in milliseconds, the number of answers, and every run's status, so a
## run that hits the sandbox's time limit (BootsRun.TIME_MS) shows as "timeout" rather than as a slow median.
##   flock -w 580 /tmp/rootward-godot.lock godot --headless --path game -s res://tools/boots_timing.gd

const REPEATS := 5
const SIZE := Vector2i(40, 30)
const FOUR_KEYS := [
	{"key": "right", "do": [{"change": "x", "by": 1}]},
	{"key": "left", "do": [{"change": "x", "by": -1}]},
	{"key": "down", "do": [{"change": "y", "by": 1}]},
	{"key": "up", "do": [{"change": "y", "by": -1}]},
]


func _initialize() -> void:
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		_time(language)
	quit()


func _time(language: String) -> void:
	var source := BootsCode.source(FOUR_KEYS, language)
	var times: Array[int] = []
	var statuses := PackedStringArray()
	var answers := 0
	for i in REPEATS:
		var started := Time.get_ticks_usec()
		var table := BootsRun.run(language, source, SIZE)
		times.append(int((Time.get_ticks_usec() - started) / 1000))
		statuses.append(String(table.status))
		answers = (table.x as PackedInt32Array).size()
	var ordered := times.duplicate()
	ordered.sort()
	var listed := PackedStringArray()
	for ms: int in times:
		listed.append(str(ms))
	print(
		(
			"%s: median %d ms over %d runs (%s), %d answers, status %s"
			% [language, ordered[REPEATS / 2], REPEATS, ", ".join(listed), answers, ", ".join(statuses)]
		)
	)
