class_name LanternCode
extends RefCounted
## What Lanternroot reads from the player's source without running it (ADR-0055): which of their own modules a file
## imports (the town's rope bridges), whether a function is already defined (so opening a letter adds its starter only
## once), and how a snake_case name is spelled in JavaScript.
##
## LEARN: these are deliberately shallow, line-based readings, not parsers. They only decide what the town draws and
## where a starter goes; whether code works is always decided by running it in the sandbox.

## The language ids, as SandboxJob names them (core stays free of the sandbox).
const PYTHON := "python"
const JAVASCRIPT := "javascript"

static var _python_import: RegEx
static var _js_require: RegEx


## The player's modules that `source` imports, in first-seen order, without duplicates or itself.
static func imports(language: String, source: String, modules: Array, self_module := "") -> Array[String]:
	var found: Array[String] = []
	for name in _imported_names(language, source):
		if name in modules and name != self_module and not name in found:
			found.append(name)
	return found


static func defines(language: String, source: String, function_name: String) -> bool:
	var pattern := (
		"(?m)^\\s*def\\s+%s\\s*\\(" % function_name
		if language == PYTHON
		else "(?m)(function\\s+%s\\s*\\(|(const|let|var)\\s+%s\\s*=)" % [function_name, function_name]
	)
	return RegEx.create_from_string(pattern).search(source) != null


## `loaves_for` -> `loavesFor`: the name a function has in JavaScript.
static func camel(snake: String) -> String:
	var parts := snake.split("_", false)
	var out := parts[0] if not parts.is_empty() else ""
	for i in range(1, parts.size()):
		out += parts[i].substr(0, 1).to_upper() + parts[i].substr(1)
	return out


static func function_name(request: Dictionary, language: String) -> String:
	return String(request.function) if language == PYTHON else camel(request.function)


static func file_name(module: String, language: String) -> String:
	return "%s.%s" % [module, "py" if language == PYTHON else "js"]


## `source` with `starter` added at its end, separated the way each language's style guide spaces top-level code.
static func append(language: String, source: String, starter: String) -> String:
	var body := source.strip_edges(false, true)
	if body.is_empty():
		return starter
	return body + ("\n\n\n" if language == PYTHON else "\n\n") + starter


static func _imported_names(language: String, source: String) -> Array[String]:
	var names: Array[String] = []
	if language == PYTHON:
		if _python_import == null:
			_python_import = RegEx.create_from_string(
				"(?m)^\\s*(?:from\\s+([A-Za-z_]\\w*)|import\\s+([A-Za-z_][\\w ,]*))"
			)
		for found in _python_import.search_all(source):
			if found.get_string(1) != "":
				names.append(found.get_string(1))
			else:
				for part in found.get_string(2).split(","):
					names.append(part.strip_edges().split(" ")[0])
	else:
		if _js_require == null:
			_js_require = RegEx.create_from_string("require\\(\\s*[\"']\\./([A-Za-z_]\\w*)(?:\\.js)?[\"']\\s*\\)")
		for found in _js_require.search_all(source):
			names.append(found.get_string(1))
	return names
