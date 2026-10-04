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
## Where a run can be (docs/shardrun-state.md).
const STATUSES: Array[String] = ["draft", "map", "battle", "reward", "rest", "forge", "won", "lost", "abandoned"]
## Every saved run's fields and their JSON types; a number may come back as a float.
const SHAPE := {
	"seed": TYPE_STRING,
	"language": TYPE_STRING,
	"difficulty": TYPE_STRING,
	"status": TYPE_STRING,
	"playstyle": TYPE_STRING,
	"map": TYPE_DICTIONARY,
	"spells": TYPE_ARRAY,
	"stats": TYPE_DICTIONARY,
	"log": TYPE_ARRAY,
	"integrity": TYPE_FLOAT,
	"integrity_max": TYPE_FLOAT,
	"layer": TYPE_FLOAT,
}

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
	var written := file.store_string(JSON.stringify(state, "\t", false, true))
	file.close()
	if not written:
		# The old save stays as it was: only a whole new one replaces it.
		DirAccess.remove_absolute(temporary)
		return ERR_FILE_CANT_WRITE
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
	problem = Text.f("The saved run could not be continued (%s). It was kept as %s.", [reason, aside.get_file()])
	return {}


func delete_run(playstyle: String) -> void:
	var path := path_for(playstyle)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Why `value` cannot be played as a run, or "" when it can.
static func unusable(value: Variant) -> String:
	if not value is Dictionary:
		return Text.t("it is not a run")
	var state: Dictionary = value
	if state.get("version") != Shardrun.VERSION:
		return Text.f("it was saved by version %s of the rules", [JsMath.text(state.get("version"))])
	for key: String in SHAPE:
		if not state.has(key):
			return Text.f("it has no %s", [key])
		var want: int = SHAPE[key]
		var found := typeof(state[key])
		var number := want == TYPE_FLOAT and found == TYPE_INT
		if found != want and not number:
			return Text.f("its %s is not what a run keeps there", [key])
	if not state.status in STATUSES:
		return Text.f("its status %s is unknown", [state.status])
	if not (state.map as Dictionary).get("nodes") is Array:
		return Text.t("its map has no rooms")
	for spell: Variant in state.spells:
		if not spell is Dictionary or not (spell as Dictionary).get("shards") is Array:
			return Text.t("a spell in it has no shards")
	if state.status == "battle":
		var battle: Variant = state.get("battle")
		if not battle is Dictionary or not (battle as Dictionary).get("foes") is Array:
			return Text.t("it is in a fight with no foes")
	return ""


## The finished runs, one JSON object a line, oldest first (RunHistory): appending is one write, and a line cut short
## by a crash loses only itself (a new line starts on a line of its own, P2-15).
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
	# A last line cut short by a crash has no newline: end it first, or the new record would join it and be lost too.
	var length := file.get_length()
	if length > 0:
		file.seek(length - 1)
		if file.get_8() != 10:
			file.seek_end()
			file.store_8(10)
	file.seek_end()
	var written := file.store_line(JSON.stringify(record, "", false))
	file.close()
	return OK if written else ERR_FILE_CANT_WRITE


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
