extends SceneTree
## The overworld's English strings with no Japanese yet, with where each comes from, as JSON for the translators'
## batches (Concept/v0.4/06):
##   godot --headless --path game -s res://tools/overworld_missing.gd -- <out.json>
## Writes [{"en": ..., "from": ...}] in source order; prints how many.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := args[0] if not args.is_empty() else "user://overworld-missing.json"
	var strings: Dictionary = ContentLocale.load_overlay("ja").strings
	var shown := OverworldStrings.shown()
	var missing: Array = []
	for english: String in shown:
		if not strings.has(english):
			missing.append({"en": english, "from": String(shown[english])})
	missing.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.from) < String(b.from) if a.from != b.from else String(a.en) < String(b.en))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(missing, "  "))
	file.close()
	print("shown %d, missing %d -> %s" % [shown.size(), missing.size(), out_path])
	quit()
