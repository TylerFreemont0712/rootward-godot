class_name BootsDraft
extends RefCounted
## The boots editor's unrun work (ADR-0061). The boots hold the program that runs (mode, blocks, code) and, while the
## player has changed something without pressing Try them, a draft beside it in the same shape: state.boots.draft. The
## program that runs changes only on Try them; closing the editor or switching language keeps the draft.
##
##   BootsDraft.of(boots)                       # the draft if there is one, else the program, as a fresh copy
##   BootsDraft.same(a, b)                      # whether two programs say the same thing
##   BootsDraft.typed(text, blocks, language)   # the Code tab's text as typed code: "" when it is only the blocks'
##                                              # code or the starter, so code nobody typed never freezes in place
##   BootsDraft.mode_of(tab, codes, language)   # the Code tab counts only once something is typed in it


static func of(boots: Dictionary) -> Dictionary:
	var source: Dictionary = boots["draft"] if boots.get("draft") is Dictionary else boots
	return program_of(source)


## A program (mode, blocks, code) copied out of a draft or the boots, with anything missing filled in.
static func program_of(source: Dictionary) -> Dictionary:
	var blocks: Variant = source.get("blocks", [])
	var code: Variant = source.get("code", {})
	return {
		"mode": String(source.get("mode", OverworldState.BLOCKS)),
		"blocks": (blocks as Array).duplicate(true) if blocks is Array else [],
		"code": (code as Dictionary).duplicate(true) if code is Dictionary else {},
	}


## Whether two programs say the same thing: the same mode, the same blocks, and the same code in each language, where
## empty code is its starter.
static func same(a: Dictionary, b: Dictionary) -> bool:
	if String(a.get("mode", "")) != String(b.get("mode", "")):
		return false
	if plain_blocks(a.get("blocks", [])) != plain_blocks(b.get("blocks", [])):
		return false
	for language: String in [BootsCode.PYTHON, BootsCode.JAVASCRIPT]:
		if code_for(a.get("code", {}), language) != code_for(b.get("code", {}), language):
			return false
	return true


## The blocks with their numbers as ints and their names as strings, so two programs compare by what they say.
static func plain_blocks(blocks: Array) -> Array:
	# LEARN: nested == is strict about int and float (1 != 1.0), and a save reads every number back as a float. So a
	# block made now and the same block from a save only compare equal once both are plain.
	var out: Array = []
	for block: Variant in blocks:
		if not block is Dictionary:
			continue
		var actions: Array = []
		for action: Variant in (block as Dictionary).get("do", []):
			if action is Dictionary:
				actions.append({"change": String(action.get("change", "")), "by": int(action.get("by", 0))})
		out.append({"key": String((block as Dictionary).get("key", "")), "do": actions})
	return out


## The code a language runs with: what was typed in it, else its starter.
static func code_for(codes: Dictionary, language: String) -> String:
	var typed_code := String(codes.get(language, ""))
	return typed_code if typed_code.strip_edges() != "" else BootsCode.starter(language)


## The Code tab's text as the player's typed code. The tab shows the blocks' code, or the starter, until the player
## types; that text is not theirs, so it is kept as "" (nothing typed) and the tab shows it fresh next time.
static func typed(text: String, blocks: Array, language: String) -> String:
	var plain := text.strip_edges()
	if plain == "" or plain == BootsCode.starter(language).strip_edges():
		return ""
	if plain == BootsCode.source(blocks, language).strip_edges():
		return ""
	return text


## The mode a draft takes from the tab on screen: the Code tab only once something is typed in it, so looking at the
## code the blocks make never turns the blocks into code.
static func mode_of(tab: String, codes: Dictionary, language: String) -> String:
	if tab == OverworldState.CODE and String(codes.get(language, "")).strip_edges() != "":
		return OverworldState.CODE
	return OverworldState.BLOCKS
