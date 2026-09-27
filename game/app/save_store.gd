class_name SaveStore
extends RefCounted
## Runs saved as JSON under user://, one file per playstyle: the latest run, finished or not, so the title can show how
## the last one ended. A run is a snapshot (docs/shardrun-state.md), written whole after every command.
##
##   var saves := SaveStore.new()                 # user://shardrun/
##   saves.save_run("spellbook", state)
##   var state := saves.load_run("spellbook")     # {} when there is none
##
## LEARN: a save is written to a temporary file and then renamed over the old one. A rename is atomic on the same disk,
## so a crash halfway through writing leaves the previous save intact instead of half a file.

const ROOT := "user://shardrun"

var root: String
## Why the last load found nothing usable, in plain words; "" when it was fine or there was simply no save.
var problem := ""


func _init(save_root := ROOT) -> void:
	root = save_root


func path_for(playstyle: String) -> String:
	return root.path_join("%s.json" % playstyle)


func save_run(playstyle: String, state: Dictionary) -> Error:
	var made := DirAccess.make_dir_recursive_absolute(root)
	if made != OK:
		return made
	var path := path_for(playstyle)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	# Tabs and keys in their own order: a save is meant to be readable. Full precision so a reload plays the same.
	file.store_string(JSON.stringify(state, "\t", false, true))
	file.close()
	return DirAccess.rename_absolute(temporary, path)


## The saved run, or {} when there is none. A file that is not a run this version can continue is set aside (renamed,
## never deleted) and `problem` says why.
func load_run(playstyle: String) -> Dictionary:
	problem = ""
	var path := path_for(playstyle)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JsJson.parse(FileAccess.get_file_as_string(path))
	var reason := unusable(parsed)
	if reason == "":
		return parsed
	var aside := path.get_basename() + ".unreadable-%d.json" % int(Time.get_unix_time_from_system())
	DirAccess.rename_absolute(path, aside)
	problem = "The saved run could not be continued (%s). It was kept as %s." % [reason, aside.get_file()]
	return {}


func delete_run(playstyle: String) -> void:
	var path := path_for(playstyle)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Why `value` cannot be played as a run, or "" when it can.
static func unusable(value: Variant) -> String:
	if not value is Dictionary:
		return "it is not a run"
	var state: Dictionary = value
	if state.get("version") != Shardrun.VERSION:
		return "it was saved by version %s of the rules" % JsMath.text(state.get("version"))
	for key: String in ["seed", "language", "difficulty", "status", "map", "spells", "stats", "log", "playstyle"]:
		if not state.has(key):
			return "it has no %s" % key
	return ""


## The finished runs, one JSON object a line, oldest first (RunHistory): appending is one write, and a line cut short
## by a crash loses only itself.
func history_path() -> String:
	return root.path_join("history.jsonl")


func append_history(record: Dictionary) -> Error:
	var made := DirAccess.make_dir_recursive_absolute(root)
	if made != OK:
		return made
	var path := history_path()
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.seek_end()
	file.store_line(JSON.stringify(record, "", false))
	file.close()
	return OK


## The finished runs, newest first; a line that does not parse is skipped.
func load_history() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var path := history_path()
	if not FileAccess.file_exists(path):
		return out
	var json := JSON.new()
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		# JSON.new().parse reports a bad line through its return value, where JSON.parse_string prints an error.
		if json.parse(line) == OK and json.data is Dictionary:
			out.push_front(json.data)
	return out
