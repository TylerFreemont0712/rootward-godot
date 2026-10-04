class_name CodeLanguage
extends RefCounted
## How each spell language looks on screen (ADR-0046): its name, how a comment starts, its files, and the command that
## runs a program, so no screen spells out "python" or "javascript" itself.

const INFO := {
	SandboxJob.PYTHON: {"name": "Python", "comment": "#", "extension": "py", "run": "py %s", "icon": "icons/python"},
	SandboxJob.JAVASCRIPT:
	{"name": "JavaScript", "comment": "//", "extension": "js", "run": "node %s", "icon": "icons/javascript"},
	# C++ is compiled before the run (ADR-0046), so what runs is the built program: ./main for main.cpp.
	SandboxJob.CPP: {"name": "C++", "comment": "//", "extension": "cpp", "run": "./%s", "icon": "icons/cpp"},
}


static func _of(language: String) -> Dictionary:
	return INFO.get(language, INFO[SandboxJob.PYTHON])


## "Python", "JavaScript" or "C++".
static func display_name(language: String) -> String:
	return _of(language).name


static func comment(language: String) -> String:
	return _of(language).comment


static func extension(language: String) -> String:
	return _of(language).extension


## The command that runs `file` (a program's own file name) in a terminal.
static func run(language: String, file: String) -> String:
	return String(_of(language).run) % (file.get_basename() if language == SandboxJob.CPP else file)


static func icon(language: String) -> String:
	return _of(language).icon
