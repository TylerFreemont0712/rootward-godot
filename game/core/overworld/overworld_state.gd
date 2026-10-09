class_name OverworldState
extends RefCounted
## Where the player is in Lanternroot's overworld and what the town remembers (ADR-0061), as plain data for the save:
##
##   {version, map, cell: [x, y], facing, flags: {name: true}, name, look: {...},
##    language, boots: {mode: "blocks" | "code", blocks: [...], code: {python, javascript}}}
##
## The boots are kept both ways: the blocks the player placed, and the code they typed in each language. Which one
## walks is `mode`.

const VERSION := 1
const BLOCKS := "blocks"
const CODE := "code"


static func fresh(map_id: String, cell: Vector2i, facing: String, language: String) -> Dictionary:
	return {
		"version": VERSION,
		"map": map_id,
		"cell": [cell.x, cell.y],
		"facing": facing,
		"flags": {},
		"name": "",
		"look": {},
		"language": language,
		"boots": {"mode": BLOCKS, "blocks": [], "code": {}},
	}


## A saved state with anything missing filled in, so an older save still loads.
static func normalized(saved: Dictionary, fallback: Dictionary) -> Dictionary:
	var out := fallback.duplicate(true)
	for key: String in saved:
		out[key] = saved[key]
	var boots: Dictionary = out.boots if out.boots is Dictionary else {}
	out.boots = {
		"mode": String(boots.get("mode", BLOCKS)),
		"blocks": boots.get("blocks", []) if boots.get("blocks", []) is Array else [],
		"code": boots.get("code", {}) if boots.get("code", {}) is Dictionary else {},
	}
	if not out.flags is Dictionary:
		out.flags = {}
	if not out.look is Dictionary:
		out.look = {}
	out.version = VERSION
	return out


static func cell(state: Dictionary) -> Vector2i:
	return OverworldMap.cell_of(state.get("cell", [0, 0]))


static func moved(state: Dictionary, map_id: String, to: Vector2i, facing: String) -> Dictionary:
	var out := state.duplicate(true)
	out.map = map_id
	out.cell = [to.x, to.y]
	if facing != "":
		out.facing = facing
	return out


static func flagged(state: Dictionary, flags: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	out.flags = flags.duplicate()
	return out


## The code the boots run: the blocks as code, or what the player typed (their starter if they typed nothing).
static func boots_source(state: Dictionary) -> String:
	var boots: Dictionary = state.boots
	var language := String(state.get("language", BootsCode.PYTHON))
	if String(boots.mode) == CODE:
		var typed := String((boots.code as Dictionary).get(language, ""))
		return typed if typed.strip_edges() != "" else BootsCode.starter(language)
	return BootsCode.source(boots.blocks, language)


static func with_blocks(state: Dictionary, blocks: Array) -> Dictionary:
	var out := state.duplicate(true)
	out.boots.blocks = blocks.duplicate(true)
	out.boots.mode = BLOCKS
	return out


static func with_code(state: Dictionary, code: String) -> Dictionary:
	var out := state.duplicate(true)
	out.boots.code[String(state.get("language", BootsCode.PYTHON))] = code
	out.boots.mode = CODE
	return out
