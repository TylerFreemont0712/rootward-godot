class_name BootsCode
extends RefCounted
## The player's movement code (ADR-0061), from blocks or from text. Blocks are rules: "when this key is pressed,
## change x (or y) by this much". They become real code in the player's language, which runs in the sandbox like any
## typed code, so blocks and text are one thing seen two ways:
##
##   BootsCode.source([{"key": "right", "do": [{"change": "x", "by": 1}]}], "python")
##   # def on_key(key, player):
##   #     if key == "right":
##   #         player.x += 1
##
## LEARN: the screen's y grows downward (row 0 is the top of the map), as in Godot and most game engines, so "up" is
## y - 1. Hotaru says so the first time the player reaches for up.

const PYTHON := "python"
const JAVASCRIPT := "javascript"
const AXES: Array[String] = ["x", "y"]
const AMOUNTS: Array[int] = [-2, -1, 1, 2]
const ENTRY := {PYTHON: "on_key", JAVASCRIPT: "onKey"}


static func source(blocks: Array, language: String) -> String:
	if language == JAVASCRIPT:
		return _javascript(blocks)
	return _python(blocks)


static func _python(blocks: Array) -> String:
	var lines: PackedStringArray = ["def on_key(key, player):"]
	var body := 0
	for block: Dictionary in blocks:
		var actions := _actions(block)
		if actions.is_empty():
			continue
		lines.append('    if key == "%s":' % block.key)
		for action: Dictionary in actions:
			lines.append(
				"        player.%s %s %d" % [action.change, "+=" if int(action.by) > 0 else "-=", absi(action.by)]
			)
		body += 1
	if body == 0:
		lines.append("    pass")
	return "\n".join(lines) + "\n"


static func _javascript(blocks: Array) -> String:
	var lines: PackedStringArray = ["function onKey(key, player) {"]
	for block: Dictionary in blocks:
		var actions := _actions(block)
		if actions.is_empty():
			continue
		lines.append('  if (key === "%s") {' % block.key)
		for action: Dictionary in actions:
			lines.append(
				"    player.%s %s %d;" % [action.change, "+=" if int(action.by) > 0 else "-=", absi(action.by)]
			)
		lines.append("  }")
	lines.append("}")
	return "\n".join(lines) + "\n"


static func _actions(block: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not String(block.get("key", "")) in BootsRules.KEYS:
		return out
	for action: Dictionary in block.get("do", []):
		var axis := String(action.get("change", ""))
		var by := int(action.get("by", 0))
		if axis in AXES and by != 0:
			out.append({"change": axis, "by": by})
	return out


## The text a player starts from when they write their boots by hand: the function, and a comment saying what it
## receives. Nothing that moves; that part is theirs.
static func starter(language: String) -> String:
	if language == JAVASCRIPT:
		return (
			"// Called every time you press a key.\n"
			+ '// key is "up", "down", "left" or "right". player.x and player.y are where you stand.\n'
			+ "function onKey(key, player) {\n"
			+ "}\n"
		)
	return (
		"# Called every time you press a key.\n"
		+ '# key is "up", "down", "left" or "right". player.x and player.y are where you stand.\n'
		+ "def on_key(key, player):\n"
		+ "    pass\n"
	)


## A rule for the blocks editor: a key and one change.
static func rule(key: String, axis: String, by: int) -> Dictionary:
	return {"key": key, "do": [{"change": axis, "by": by}]}
