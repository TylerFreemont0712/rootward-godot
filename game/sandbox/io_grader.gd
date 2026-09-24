class_name IoGrader
extends RefCounted
## Grades a program against io test cases: each case feeds standard input and compares standard output with what it
## expects, after the challenge's normalization. One sandbox run per case, so one case's crash or endless loop cannot
## touch another's.
##
## A case is a Dictionary from content: {id, name, stdin, expected_stdout}. A result is
## {id, name, passed, status, expected, actual, stderr, message, wall_ms}.


## Ignore spaces and tabs at line ends and blank lines at the end (`trailing_whitespace`); treat \r\n and \r as \n
## (`newlines`).
static func normalize(text: String, trailing_whitespace: bool, newlines: bool) -> String:
	var result := text
	if newlines:
		result = result.replace("\r\n", "\n").replace("\r", "\n")
	if trailing_whitespace:
		var lines := result.split("\n")
		for i in lines.size():
			lines[i] = lines[i].rstrip(" \t")
		result = "\n".join(lines).rstrip("\n")
	return result


static func grade(
	language: String,
	files: Dictionary[String, String],
	entry: String,
	cases: Array,
	rules: Dictionary,
	limits: SandboxJob = null
) -> Array[Dictionary]:
	var trailing: bool = rules.get("trailing_whitespace", true)
	var newlines: bool = rules.get("newlines", true)
	var results: Array[Dictionary] = []
	for case: Dictionary in cases:
		var job := SandboxJob.of(language, files, entry)
		if limits != null:
			job.time_ms = limits.time_ms
			job.wall_ms = limits.wall_ms
			job.memory_mb = limits.memory_mb
			job.output_kb = limits.output_kb
		job.stdin = case.stdin
		var run := Sandbox.run(job)
		var expected := normalize(case.expected_stdout, trailing, newlines)
		var actual := normalize(run.stdout, trailing, newlines)
		(
			results
			. append(
				{
					"id": case.id,
					"name": case.name,
					"passed": run.is_ok() and actual == expected,
					"status": run.status,
					"expected": expected,
					"actual": actual,
					"stderr": run.stderr,
					"message": run.message,
					"wall_ms": run.wall_ms,
				}
			)
		)
	return results
