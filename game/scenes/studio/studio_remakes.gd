class_name StudioRemakes
extends Node
## The remake queue and Run remakes (Concept/v0.3/10, section 7.7). A thing dragged to a new size is drafted as
## `<id>-<w>x<h>` (StudioRemake makes its spec and catalog entry) and waits here, drawn as a placeholder, until Run
## remakes writes the waiting specs into pipeline/world/objects/ and runs `scripts/world.sh make --only <ids>` as a
## background process (it stops and starts ComfyUI and runs Blender itself: the GPU rule is the script's). Its output
## goes to a log read a line at a time for the progress line; when it ends, a remake whose picture world.json now lists
## is done, any other failed (it waits to be run again), and `finished` tells the Studio to draw the new pictures.
##
## The queue lives in `queue_path` (user://), so it survives a restart. Tests point `queue_path`, `log_path`,
## `objects_dir` and `program`/`arguments` somewhere harmless.

## A line of the running remake's output, as it comes.
signal progress(line: String)
## The run ended: the ids made, and the ids that failed.
signal finished(made: Array[String], failed: Array[String])

const QUEUE := "user://studio/remakes.json"
const LOG := "user://studio/remakes.log"

var queue_path := QUEUE
var log_path := LOG
## Where the specs go; "" for the repository's pipeline/world/objects.
var objects_dir := ""
## What runs: `program` with `arguments` and the comma-separated ids appended, from the repository's root.
var program := "bash"
var arguments: PackedStringArray = PackedStringArray(["scripts/world.sh", "make", "--only"])
## Whether world.json lists a picture (overridable by tests); by default it reads the art index again.
var made_check: Callable

var queue: Array = []
var running := false
var last_line := ""

var _pid := -1
var _running_ids: Array[String] = []
var _read := 0


func _init() -> void:
	name = "Remakes"
	made_check = StudioRemakes._listed_in_world


func _ready() -> void:
	load_queue()


func load_queue() -> void:
	var record: Variant = StudioFiles.read_record(queue_path)
	queue = (record as Array).duplicate(true) if record is Array else []
	# A run cut short by quitting the game left its ids running: they wait again.
	var stuck: Array[String] = []
	for item: Variant in queue:
		if item is Dictionary and String((item as Dictionary).get("state", "")) == StudioRemake.RUNNING:
			stuck.append(String((item as Dictionary).get("id", "")))
	if not stuck.is_empty():
		queue = StudioRemake.with_state(queue, stuck, StudioRemake.QUEUED)


func save_queue() -> bool:
	return StudioFiles.write_record(queue_path, queue)


## Queues the remake `id` of `source` at `size`, keeping its spec text to write when Run remakes starts.
func request(id: String, source: String, size: Vector2i, spec_text: String) -> void:
	queue = StudioRemake.enqueue(queue, id, source, size)
	for item: Variant in queue:
		if item is Dictionary and String((item as Dictionary).get("id", "")) == id:
			(item as Dictionary)["spec"] = spec_text
	save_queue()


## The ids still to make (queued, or failed and to try again).
func waiting() -> Array[String]:
	return StudioRemake.waiting(queue)


## Starts the waiting remakes: their specs written, the pipeline started in the background. False with nothing to do,
## while a run is going, outside the repository, or when a spec could not be written (that id fails at once).
func run() -> bool:
	if running or OS.has_feature("template"):
		return false
	var ids: Array[String] = []
	for id: String in waiting():
		var spec := String(_item(id).get("spec", ""))
		if spec == "" or not StudioFiles.write_world_spec(id, spec, objects_dir):
			queue = StudioRemake.with_state(queue, [id] as Array[String], StudioRemake.FAILED, "its spec could not be written")
			continue
		ids.append(id)
	if ids.is_empty():
		save_queue()
		return false
	var log_file := ProjectSettings.globalize_path(log_path)
	DirAccess.make_dir_recursive_absolute(log_file.get_base_dir())
	FileAccess.open(log_file, FileAccess.WRITE)
	var root := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var parts := PackedStringArray([_quoted(program)])
	for argument: String in arguments:
		parts.append(_quoted(argument))
	parts.append(_quoted(",".join(ids)))
	# LEARN: OS.create_process cannot redirect output, so the run goes through a shell that sends it to a log the Studio
	# reads as it grows; OS.get_process_exit_code gives the result once the process is gone.
	var line := "cd %s && %s > %s 2>&1" % [_quoted(root), " ".join(parts), _quoted(log_file)]
	_pid = OS.create_process("bash", PackedStringArray(["-c", line]))
	if _pid <= 0:
		queue = StudioRemake.with_state(queue, ids, StudioRemake.FAILED, "the pipeline could not be started")
		save_queue()
		return false
	running = true
	_running_ids = ids
	_read = 0
	last_line = ""
	queue = StudioRemake.with_state(queue, ids, StudioRemake.RUNNING)
	save_queue()
	return true


func _process(_delta: float) -> void:
	if not running:
		return
	_read_log()
	if OS.is_process_running(_pid):
		return
	_read_log()
	_finish(OS.get_process_exit_code(_pid))


func _read_log() -> void:
	var text := StudioFiles.read_text(log_path)
	if text.length() <= _read:
		return
	var fresh := text.substr(_read)
	var cut := fresh.rfind("\n")
	if cut < 0:
		return
	_read += cut + 1
	for raw: String in fresh.substr(0, cut).split("\n"):
		var line := raw.strip_edges()
		if line != "":
			last_line = line
			progress.emit(line)


func _finish(code: int) -> void:
	running = false
	var made: Array[String] = []
	var failed: Array[String] = []
	for id: String in _running_ids:
		if code == 0 and bool(made_check.call(id)):
			made.append(id)
		else:
			failed.append(id)
	queue = StudioRemake.with_state(queue, made, StudioRemake.DONE)
	var why := last_line if last_line != "" else "the pipeline ended with %d" % code
	queue = StudioRemake.with_state(queue, failed, StudioRemake.FAILED, why)
	save_queue()
	_running_ids = []
	_pid = -1
	finished.emit(made, failed)


## A word for the shell, in single quotes.
static func _quoted(word: String) -> String:
	return "'%s'" % word.replace("'", "'\\''")


func _item(id: String) -> Dictionary:
	for item: Variant in queue:
		if item is Dictionary and String((item as Dictionary).get("id", "")) == id:
			return item as Dictionary
	return {}


## Whether the world pipeline's index (read again from disk) lists a picture for `id`.
static func _listed_in_world(id: String) -> bool:
	var parsed: Variant = JSON.parse_string(StudioFiles.read_text(OverworldArt.ROOT + "world/world.json"))
	return parsed is Dictionary and (parsed as Dictionary).has(id)
