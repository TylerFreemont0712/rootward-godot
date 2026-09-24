extends SceneTree
## How much of the content a locale translates: scripts/locale.sh ja [--missing]


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
	quit(1 if not overlay.diagnostics.is_empty() else 0)
