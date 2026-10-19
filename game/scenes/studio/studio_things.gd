class_name StudioThings
extends RefCounted
## The files of the things made or changed in Lanternroot Studio (Concept/v0.3/10, S8): `things/<id>.jsonc` and its two
## starters, `<id>.starter.py` and `<id>.starter.js`. They are drafts until Publish writes them, kept in one record in
## the drafts folder (StudioFiles.save_file_drafts). Each file remembers the hash of the text it began from ("" for a
## file that does not exist yet), so Publish can tell a file someone changed meanwhile, as it does for maps.
##
##   var things := StudioThings.new(drafts_dir, content_root)
##   things.make({"id": "talking-barrel", "name": "The talking barrel", ...})   # the three files, as drafts
##   things.drafts()      # path -> data (the thing's file) or text (a starter), for OverworldContent.load_world
##   things.record("talking-barrel")   # the thing as the catalog holds it (name, hints, starter, code), for Play draft

const STARTER_PY := """def on_use(thing, player):
    # thing.fields holds this thing's fields; player has x, y, map, facing and name.
    # Give back {"say": "words"} to speak, {"set": {"field": value}} to change a field.
    return {"say": "%s"}
"""
const STARTER_JS := """function onUse(thing, player) {
  // thing.fields holds this thing's fields; player has x, y, map, facing and name.
  // Give back {say: "words"} to speak, {set: {field: value}} to change a field.
  return {say: "%s"};
}
"""

## The hints a new thing gets for any left empty (a thing's file needs three): about using it, not its answer.
const DEFAULT_HINTS: Array[String] = [
	"Use it, and read what your code makes it say.",
	"thing.fields holds what this thing remembers.",
	"Give back say to speak, or set to change a field.",
]

## Content path -> {text, base_hash}.
var files: Dictionary = {}
var drafts_dir := StudioFiles.DRAFTS
var content_root := ContentLoader.ROOT


func _init(drafts_folder := StudioFiles.DRAFTS, root := ContentLoader.ROOT) -> void:
	drafts_dir = drafts_folder
	content_root = root
	files = StudioFiles.load_file_drafts(drafts_dir)


## The folder of the things' files.
func folder() -> String:
	return content_root.path_join("packs/core/overworld/things")


## The three files of a thing: its own and its two starters.
func paths_of(id: String) -> Array[String]:
	var dir := folder()
	return [dir.path_join(id + ".jsonc"), dir.path_join(id + ".starter.py"), dir.path_join(id + ".starter.js")]


## Whether a thing's file exists (published) or is drafted here.
func has_thing(id: String) -> bool:
	var path := paths_of(id)[0]
	return files.has(path) or StudioFiles.exists(path)


## Drafts a thing's three files from `spec` ({id, name, hints: 3 lines, python, javascript}; a missing starter gets the
## template that says the thing's name). Returns the paths drafted.
func make(spec: Dictionary) -> Array[String]:
	var id := String(spec.id)
	var title := String(spec.get("name", id))
	var paths := paths_of(id)
	var hints: Array = spec.get("hints", [])
	var three: Array[String] = []
	for i: int in 3:
		three.append(String(hints[i]) if i < hints.size() and String(hints[i]).strip_edges() != "" else DEFAULT_HINTS[i])
	put(paths[0], thing_text(id, title, three))
	put(paths[1], String(spec.get("python", STARTER_PY % title.c_escape())))
	put(paths[2], String(spec.get("javascript", STARTER_JS % title.c_escape())))
	return paths


## Drafts `text` for the file at `path`. The first draft of a file remembers the text it began from.
func put(path: String, text: String) -> void:
	if not files.has(path):
		files[path] = {"text": text, "base_hash": StudioFiles.read_text(path).sha256_text()}
	else:
		(files[path] as Dictionary)["text"] = text


## Forgets the drafts of these files (Publish wrote them, or they were thrown away).
func forget(paths: Array) -> void:
	for path: Variant in paths:
		files.erase(String(path))


func save() -> bool:
	return StudioFiles.save_file_drafts(files, drafts_dir)


## The drafts as OverworldContent.load_world takes them: a thing's file as its data, a starter as its text.
func drafts() -> Dictionary:
	var out := {}
	for path: String in files:
		var text := String((files[path] as Dictionary).text)
		if path.ends_with(".jsonc"):
			var parsed := Jsonc.parse(text)
			if bool(parsed.ok) and parsed.value is Dictionary:
				out[path] = JsoncWriter.normalized(parsed.value)
		else:
			out[path] = text
	return out


## The drafted things' ids, sorted.
func ids() -> Array[String]:
	var out: Array[String] = []
	for path: String in files:
		if path.ends_with(".jsonc") and path.get_base_dir() == folder():
			out.append(path.get_file().get_basename())
	out.sort()
	return out


## A drafted thing as the catalog holds it ({id, name, hints, starter, code: {python, javascript}}), or {}.
func record(id: String) -> Dictionary:
	var paths := paths_of(id)
	var data: Variant = drafts().get(paths[0])
	if not data is Dictionary:
		return {}
	var out: Dictionary = (data as Dictionary).duplicate(true)
	var code := {}
	for i: int in [1, 2]:
		var language := BootsCode.PYTHON if i == 1 else BootsCode.JAVASCRIPT
		code[language] = String((files.get(paths[i], {}) as Dictionary).get("text", StudioFiles.read_text(paths[i])))
	out["code"] = code
	return out


## A thing's file, in the shape of the ones in things/: the header, then id, name, three hints, the starters' names.
static func thing_text(id: String, title: String, hints: Array[String]) -> String:
	var lines := PackedStringArray()
	lines.append("// %s (TownThings, ADR-0061), made in Lanternroot Studio. Its prop is in one of the maps." % title)
	lines.append("{")
	lines.append('  "id": %s,' % JSON.stringify(id))
	lines.append('  "name": %s,' % JSON.stringify(title))
	lines.append('  "hints": [')
	var quoted := PackedStringArray()
	for hint: String in hints:
		quoted.append("    " + JSON.stringify(hint))
	lines.append(",\n".join(quoted))
	lines.append("  ],")
	lines.append('  "starter": {"python": %s, "javascript": %s}' % [JSON.stringify(id + ".starter.py"), JSON.stringify(id + ".starter.js")])
	lines.append("}")
	return "\n".join(lines) + "\n"
