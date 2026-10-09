class_name BootsRules
extends RefCounted
## How the player moves in Lanternroot's town (ADR-0061): by their own code. The player writes `on_key(key, player)`;
## BootsRun calls it for every key on every tile and hands back a table, and this decides what one key press does:
##
##   var step := BootsRules.move(map, occupied, table, "right", Vector2i(3, 4))
##   # {kind, to: Vector2i, facing, error: {kind, message, line} or {}}
##
## A step's kind:
##   "walk"   the code moved the player one tile up, down, left or right onto open ground
##   "bump"   the code moved them one tile, into a wall, a house or someone: they turn to face it and stay
##   "still"  the code left them where they were (it has no rule for this key yet)
##   "far"    the code moved them further than one tile, or diagonally: boots take one step at a time
##   "outside" the code moved them off the map
##   "error"  the code raised an error for this key here (the table keeps the error and its line)
##   "empty"  there is no working table yet (no boots, or code that would not load)
##
## LEARN: asking the code once per key per tile turns a function into a table (a lookup). That only works because
## the rule depends on nothing but the key and the tile, which BootsRun checks ("remembers"), and it is exactly what
## makes the walk instant: no sandbox between the key and the step.

const KEYS: Array[String] = ["up", "down", "left", "right"]
const STEPS := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}


static func ready(table: Dictionary) -> bool:
	return (
		String(table.get("status", "")) == "ok"
		and not (table.get("x", PackedInt32Array()) as PackedInt32Array).is_empty()
	)


## Where the code sends the player from `cell` on `key`, and the error it raised there, if any.
static func answer(table: Dictionary, key: String, cell: Vector2i) -> Dictionary:
	if not ready(table):
		return {"ok": false, "to": cell, "error": {}}
	var keys: Array = table.keys
	var k := keys.find(key)
	var width := int(table.width)
	var height := int(table.height)
	if k == -1 or cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return {"ok": false, "to": cell, "error": {}}
	var i := (k * height + cell.y) * width + cell.x
	var mark: int = (table.error as PackedInt32Array)[i]
	var error: Dictionary = (table.errors as Array)[mark] if mark >= 0 and mark < (table.errors as Array).size() else {}
	return {
		"ok": true, "to": Vector2i((table.x as PackedInt32Array)[i], (table.y as PackedInt32Array)[i]), "error": error
	}


## What pressing `key` at `cell` does. `blocked` says whether a cell can be walked onto (walls, houses, people).
static func move(table: Dictionary, key: String, cell: Vector2i, size: Vector2i, blocked: Callable) -> Dictionary:
	var found := answer(table, key, cell)
	if not found.ok:
		return {"kind": "empty", "to": cell, "facing": "", "error": {}}
	if not (found.error as Dictionary).is_empty():
		return {"kind": "error", "to": cell, "facing": "", "error": found.error}
	var to: Vector2i = found.to
	var delta := to - cell
	if delta == Vector2i.ZERO:
		return {"kind": "still", "to": cell, "facing": "", "error": {}}
	if to.x < 0 or to.y < 0 or to.x >= size.x or to.y >= size.y:
		return {"kind": "outside", "to": cell, "facing": facing_of(delta), "error": {}}
	if absi(delta.x) + absi(delta.y) != 1:
		return {"kind": "far", "to": cell, "facing": facing_of(delta), "error": {}}
	if blocked.call(to):
		return {"kind": "bump", "to": cell, "facing": facing_of(delta), "error": {}}
	return {"kind": "walk", "to": to, "facing": facing_of(delta), "error": {}}


## The way a move faces: the larger part of it wins, and a tie goes to the side.
static func facing_of(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return ""
	if absi(delta.x) >= absi(delta.y):
		return "right" if delta.x > 0 else "left"
	return "down" if delta.y > 0 else "up"


## Which keys already do something somewhere on the map: the keys the player has taught their boots.
static func taught(table: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not ready(table):
		return out
	var width := int(table.width)
	var height := int(table.height)
	var xs: PackedInt32Array = table.x
	var ys: PackedInt32Array = table.y
	for k in (table.keys as Array).size():
		var key := String(table.keys[k])
		for i in width * height:
			var at := k * width * height + i
			if xs[at] != i % width or ys[at] != i / width:
				out.append(key)
				break
	return out
