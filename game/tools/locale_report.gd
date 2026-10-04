extends SceneTree
## How much of the content, the interface and the rules' sentences a locale translates: scripts/locale.sh ja [--missing]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var locale := args[0] if not args.is_empty() else "ja"
	var overlay := ContentLocale.load_overlay(locale)
	for diagnostic: Dictionary in overlay.diagnostics:
		print(ContentLoader.describe(diagnostic))
	var report := ContentLocale.coverage(ContentLoader.load_shardrun().catalog, overlay.strings)
	print("%s: %d of %d content strings translated" % [locale, report.translated, report.total])
	if args.has("--missing"):
		for text: String in report.missing:
			print("- en: %s" % JSON.stringify(text))
	# The interface and the rules' sentences (ADR-0047), found in the source (TextCoverage).
	for part: Array in [
		["interface", TextCoverage.interface_strings()], ["rule sentence", TextCoverage.rule_sentences()]
	]:
		var keys: Array[String] = part[1]
		var missing := keys.filter(func(text: String) -> bool: return not overlay.strings.has(text))
		print("%s: %d of %d %s strings translated" % [locale, keys.size() - missing.size(), keys.size(), part[0]])
		if args.has("--missing"):
			for text: String in missing:
				print("- %s: %s" % [part[0], JSON.stringify(text)])
	quit(1 if not overlay.diagnostics.is_empty() else 0)
