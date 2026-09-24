class_name SandboxJob
extends RefCounted
## One program to run in the sandbox: its files, which one to start, what it reads on standard input, and its limits.

const PYTHON := "python"
const JAVASCRIPT := "javascript"
const LANGUAGES: Array[String] = [PYTHON, JAVASCRIPT]

var language: String
## Relative path -> contents. The program sees them under /work and nothing else of the machine.
var files: Dictionary[String, String] = {}
var entry: String
var stdin: String = ""
## CPU time for the program itself, enforced inside the engine (an endless loop stops here).
var time_ms: int = 2000
## A backstop on the whole process, startup included, in case the engine itself stalls.
var wall_ms: int = 10000
var memory_mb: int = 256
## Output past this is dropped and the run stops as a runtime error.
var output_kb: int = 256


static func of(job_language: String, job_files: Dictionary[String, String], job_entry: String) -> SandboxJob:
	var job := SandboxJob.new()
	job.language = job_language
	job.files = job_files
	job.entry = job_entry
	return job
