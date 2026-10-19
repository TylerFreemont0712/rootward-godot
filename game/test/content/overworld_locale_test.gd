extends GdUnitTestSuite
## Every English string the overworld shows has a Japanese entry (ADR-0061, ADR-0047). The strings are gathered from
## what the overworld's scripts pass to Text (the literals, labels and names included), what the content says (talk
## lines and choices, townsfolk names and titles, the things' texts), the four keys and Hotaru, and the messages the
## boots report. Japanese is still being written, so the coverage test fails until it lands: its failure names how many
## strings are missing and the first 30.

const SCENES := "res://scenes/overworld"
const BOOTS_RUN := "res://sandbox/overworld/boots_run.gd"
const PY_HARNESS := "res://sandbox/overworld/boots.py"
const JS_HARNESS := "res://sandbox/overworld/boots.js"
const SHOWN := 30
## The messages the boots' own harnesses (boots.py, boots.js) report when they cannot run the player's code: Hotaru
## shows them in her bubble, so they need Japanese too. The test below checks the harnesses still say these.
const HARNESS_MESSAGES: Array[String] = [
	"there is no function on_key(key, player)",
	"there is no function onKey(key, player)",
	"the recursion went too deep",
]
## A Text.t or Text.f call's first argument, a double-quoted or single-quoted literal (captured with its quotes).
const TEXT_CALL := "Text\\.[tf]\\(\\s*(\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*')"
## The messages the boots report: the last literal of a failed(...) call in BootsRun.
const FAILED_CALL := 'failed\\([^\\n]*("(?:[^"\\\\]|\\\\.)*")\\)'


func test_every_english_string_the_overworld_shows_has_a_japanese_entry() -> void:
	var shown := OverworldStrings.shown_list()
	var strings: Dictionary = ContentLocale.load_overlay("ja").strings
	var missing: Array[String] = []
	for english: String in shown:
		if not strings.has(english):
			missing.append(english)
	var first := missing.slice(0, SHOWN)
	print(
		(
			"overworld strings: %d shown, %d with Japanese, %d missing"
			% [shown.size(), shown.size() - missing.size(), missing.size()]
		)
	)
	# Every missing key, one to a line, so the Japanese can be written from the console as well as the failure message.
	for english: String in missing:
		print("missing: %s" % english)
	var message := "%d overworld strings have no Japanese yet; the first %d: %s" % [missing.size(), first.size(), first]
	assert_array(missing).override_failure_message(message).is_empty()


func test_no_key_is_defined_twice_across_the_japanese_files() -> void:
	var seen := {}
	var twice: Array[String] = []
	var files := 0
	for pack: String in ContentLoader._sorted_dirs(ContentLoader.ROOT.path_join("packs")):
		var dir := ContentLoader.ROOT.path_join("packs").path_join(pack).path_join("locales").path_join("ja")
		for name: String in ContentLoader._sorted_files(dir, ".jsonc"):
			files += 1
			var parsed := Jsonc.parse_file(dir.path_join(name))
			# A good parse has `ok` and `value`; only a failed one carries an `error`, so the reason is read only then.
			if not bool(parsed.get("ok", false)):
				var reason := String(parsed.get("error", ""))
				assert_bool(false).override_failure_message("%s does not parse: %s" % [name, reason]).is_true()
				continue
			for entry: Dictionary in parsed.value:
				var english := String(entry.get("en", ""))
				if seen.has(english):
					twice.append('"%s" is in %s and in %s' % [english, seen[english], name])
				else:
					seen[english] = name
	assert_array(twice).override_failure_message("keys defined twice: %s" % [twice]).is_empty()
	assert_int(files).override_failure_message("the Japanese folder should have files").is_greater(0)


func test_every_japanese_file_loads_without_diagnostics() -> void:
	var overlay := ContentLocale.load_overlay("ja")
	(
		assert_array(overlay.diagnostics)
		. override_failure_message("the Japanese overlays do not load: %s" % [overlay.diagnostics])
		. is_empty()
	)


## The harness messages listed in HARNESS_MESSAGES are still the ones the harnesses say, so a reworded message cannot
## slip past the coverage check unnoticed.
func test_the_harness_messages_listed_here_are_the_ones_the_harnesses_say() -> void:
	var py := FileAccess.get_file_as_string(PY_HARNESS)
	var js := FileAccess.get_file_as_string(JS_HARNESS)
	var said := [
		'"there is no function %s(key, player)" % ENTRY' in py,
		'"there is no function " + ENTRY + "(key, player)"' in js,
		'"the recursion went too deep"' in js,
	]
	assert_array(said).override_failure_message("a harness message changed: %s" % [said]).is_equal([true, true, true])


## Every string the overworld shows, in English, each once and in order (OverworldStrings, which the translators'
## batches use too).
func _shown() -> Array[String]:
	return OverworldStrings.shown_list()


## No overworld overlay keeps a key that nothing shows any more: an English line that changed leaves its old key
## behind, and its Japanese with it (a stale translation). The overworld's own files: overworld.jsonc,
## overworld-talk.jsonc and every overworld-*.jsonc.
func test_no_overworld_japanese_entry_is_stale() -> void:
	var shown := OverworldStrings.shown()
	var stale: Array[String] = []
	var dir := ContentLoader.ROOT.path_join("packs/core/locales/ja")
	for name: String in ContentLoader._sorted_files(dir, ".jsonc"):
		if not (name == "overworld.jsonc" or name.begins_with("overworld-")):
			continue
		var parsed := Jsonc.parse_file(dir.path_join(name))
		if not bool(parsed.get("ok", false)):
			continue
		for entry: Dictionary in parsed.value:
			var english := String(entry.get("en", ""))
			if not shown.has(english):
				stale.append("%s: %s" % [name, english])
	for line in stale:
		print("stale: %s" % line)
	assert_array(stale).override_failure_message("%d stale Japanese entries: %s" % [stale.size(), stale.slice(0, 20)]).is_empty()


## Every .gd file under `dir`, the subfolders too.
func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for name: String in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir.path_join(name))
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	return out


## The string literals `pattern` captures from `source`, each unquoted and unescaped.
func _literals(source: String, pattern: String) -> Array[String]:
	var out: Array[String] = []
	var regex := RegEx.create_from_string(pattern)
	assert_bool(regex.is_valid()).override_failure_message("bad pattern %s" % pattern).is_true()
	for hit: RegExMatch in regex.search_all(source):
		var text := _unquote(hit.get_string(1))
		if text != "":
			out.append(text)
	return out


static func _unquote(literal: String) -> String:
	var inner := literal.substr(1, literal.length() - 2)
	var out := ""
	var i := 0
	while i < inner.length():
		var c := inner[i]
		if c == "\\" and i + 1 < inner.length():
			out += String({"n": "\n", "t": "\t"}.get(inner[i + 1], inner[i + 1]))
			i += 2
		else:
			out += c
			i += 1
	return out
