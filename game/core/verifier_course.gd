class_name VerifierCourse
extends RefCounted
## A separate code-reading course. Source is executed by the same sandbox as the Artificer's spells.

const CONTENT := "res://content/packs/core/verifier/course.jsonc"
const SAVE := "user://verifier-course.json"

static var lessons: Array[Dictionary] = []
static var best: Dictionary = {}


static func load_course() -> String:
	var parsed := Jsonc.parse_file(CONTENT)
	if not parsed.ok or not parsed.value is Dictionary:
		return "Could not read the Verifier course."
	lessons.clear()
	for lesson: Variant in parsed.value.get("lessons", []):
		if lesson is Dictionary:
			lessons.append(lesson)
	best = {}
	if FileAccess.file_exists(SAVE):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if saved is Dictionary:
			best = saved
	return "" if not lessons.is_empty() else "The Verifier course has no lessons."


static func unlocked(index: int) -> bool:
	return index == 0 or int(best.get(lessons[index - 1].id, 0)) > 0


static func stars(index: int) -> int:
	return clampi(int(best.get(lessons[index].id, 0)), 0, 3)


static func record(index: int, earned: int) -> void:
	var id: String = lessons[index].id
	best[id] = maxi(stars(index), earned)
	var file := FileAccess.open(SAVE + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(best, "\t"))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE + ".tmp"), ProjectSettings.globalize_path(SAVE))


static func source(lesson: Dictionary) -> String:
	return "\n".join(PackedStringArray(lesson.code)) + "\n"


static func execute(lesson: Dictionary) -> SandboxResult:
	var files: Dictionary[String, String] = {"lesson.js": source(lesson)}
	var job := SandboxJob.of(SandboxJob.JAVASCRIPT, files, "lesson.js")
	job.time_ms = 1500
	job.wall_ms = 6000
	job.output_kb = 8
	return Sandbox.run(job)


static func normalize_output(value: String) -> String:
	return value.replace("\r\n", "\n").strip_edges()
