class_name StudioLiveCheck
extends RefCounted
## The Studio's passive whole-world check, kept off the frame (Concept/v0.3/10, sections 4 and 9.5). A check is
## StudioPublish.review over a snapshot of the sessions, run as one WorkerThreadPool task; the main thread only takes
## the snapshot (a handful of small objects) and, later, applies the answer. So the answer is the same one a synchronous
## review gives for the same drafts: this changes where the work happens, not what it finds.
##
##   var check := StudioLiveCheck.new(passive_service)
##   check.start(sessions, current_map_id)     # main thread: snapshot, then a task
##   ...each frame...
##   var done := check.poll()                  # {} while it runs, else {report, current_changes, fresh}
##   if not done.is_empty() and done.fresh:
##       apply(done.report)                    # an answer older than the newest change comes back with fresh false
##
## Whoever drops the check while one runs calls discard() first: a RefCounted cannot call its own methods while it is
## being freed, so there is no destructor to do it.
##
## One check runs at a time, and it uses the one service it was given, so nothing is shared between threads but the
## docs, which are never changed once they are in a history (see StudioSession.snapshot).

## The newest change the Studio knows of. A check keeps the number it started under; an older one is not fresh.
var generation := 0
var service: StudioPublish

var _job: Job


## One check in flight: what it was given, and what it found.
class Job:
	extends RefCounted
	var service: StudioPublish
	var sessions: Dictionary = {}
	var current_id := ""
	var generation := 0
	var task := -1
	var report: Dictionary = {}
	var current_changes := 0

	func run() -> void:
		report = service.review(sessions)
		var current: Variant = sessions.get(current_id)
		current_changes = (current as StudioSession).changes() if current is StudioSession else 0


func _init(passive: StudioPublish) -> void:
	service = passive
	_warm()


## Whether a check is running (or finished and not yet polled).
func busy() -> bool:
	return _job != null


## A change was made (or the files may have): a check that started before now is no longer fresh.
func invalidate() -> void:
	generation += 1


## Snapshots the sessions on this thread and starts the check. False when one is already running.
func start(sessions: Dictionary, current_id: String) -> bool:
	if _job != null:
		return false
	var job := Job.new()
	job.service = service
	job.sessions = snapshot(sessions)
	job.current_id = current_id
	job.generation = generation
	# LEARN: a WorkerThreadPool task is a Callable run on another thread. The job object carries everything in and out,
	# so the task reads no node and no live session; the main thread reads `report` only after wait_for_task_completion.
	job.task = WorkerThreadPool.add_task(job.run, false, "Studio live check")
	_job = job
	return true


## {} while the check runs (or none does). When it has finished: {report, current_changes, fresh}, and the task is
## collected. `fresh` is false when a change was made after the check started.
func poll() -> Dictionary:
	if _job == null or not WorkerThreadPool.is_task_completed(_job.task):
		return {}
	return _collect()


## Waits for the running check and returns its answer as poll does; {} when none runs.
func wait() -> Dictionary:
	return _collect() if _job != null else {}


## Waits for the running check and drops its answer.
func discard() -> void:
	if _job != null:
		_collect()


func _collect() -> Dictionary:
	var job := _job
	_job = null
	WorkerThreadPool.wait_for_task_completion(job.task)
	return {"report": job.report, "current_changes": job.current_changes, "fresh": job.generation == generation}


## The sessions as a check reads them: copies that share the docs (see StudioSession.snapshot), so the Studio can go on
## editing while the check runs. Anything that is not a session is left out, as review leaves it out.
static func snapshot(sessions: Dictionary) -> Dictionary:
	var copies: Dictionary = {}
	for id: Variant in sessions:
		var value: Variant = sessions[id]
		if value is StudioSession:
			copies[id] = (value as StudioSession).snapshot()
	return copies


## Some of the game's checkers make a RegEx the first time they are asked. Made here, on the main thread, they are
## never made by two threads at once.
static func _warm() -> void:
	Schema.check({"type": "id"}, "warm")
	Schema.check({"type": "tag"}, "warm")
	ProgramRules.card_tag("warm")
