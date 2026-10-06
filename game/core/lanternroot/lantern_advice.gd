class_name LanternAdvice
extends RefCounted
## One sentence of advice for a test that did not pass (ADR-0055), in plain words, aimed at the most common beginner
## mistakes: printing instead of returning, a misspelt name, an off-by-one, a loop that never ends. It never says what
## the code should be; it says what to look at. English here, translated by the screen (Text.t keys).


static func nudge(result: Dictionary, language: String) -> String:
	var status: String = result.status
	var actual: String = result.get("actual", "")
	var printed: String = result.get("printed", "")
	var error: String = result.get("error", "")
	match status:
		"timeout":
			return "It never finished. Is there a loop whose condition never becomes false?"
		"missing":
			return "The Night Watch could not find this function. Check its name and spelling."
		"unreached":
			return "This test did not run: an earlier one never finished."
		"error":
			return _error_nudge(error, String(result.get("message", "")), language)
		"fail":
			if actual in ["None", "undefined"]:
				if printed.strip_edges() != "":
					return "It printed the answer but gave back nothing. Printing shows a value; return hands it back."
				return "It gave back nothing. Did the function reach a return?"
			if _off_by_one(actual, String(result.get("expected", ""))):
				return "Off by one! Look at the edges: < or <=, where a count starts, rounding."
			if (
				actual.is_valid_float()
				and String(result.get("expected", "")).is_valid_int()
				and not actual.is_valid_int()
			):
				return "It gave back a fraction where a whole number was expected."
			return "It gave back something else. Try this example by hand, step by step."
	return ""


static func _error_nudge(error: String, message: String, language: String) -> String:
	match error:
		"NameError", "ReferenceError":
			return "A name it uses is not defined here. Check the spelling, or whether it needs an import."
		"SyntaxError", "IndentationError", "TabError":
			if language == LanternCode.PYTHON:
				return "Python could not read this line. Check colons, brackets and indentation."
			return "JavaScript could not read this line. Check brackets, braces and quotes."
		"TypeError":
			if message.contains("NoneType") or message.contains("undefined") or message.contains("null"):
				return "Something here is empty (None or undefined). Did a function you call forget to return?"
			return "Two values of different kinds were mixed, like a number and text."
		"ZeroDivisionError":
			return "It divided by zero. Which input makes the divisor 0?"
		"IndexError", "RangeError":
			if message.contains("recursion"):
				return "A function kept calling itself. Where does it stop?"
			return "It reached past the end of a list. Lists start at 0 and end one before their length."
		"KeyError":
			return "It looked up a key that is not in the dictionary yet. What should happen the first time?"
		"ImportError", "ModuleNotFoundError":
			return "An import could not be found. Check the module's name: it is the house's file name."
		"AttributeError":
			return "That value has no such attribute or method. Check what kind of value it is."
	return "It raised an error. Read the message and the line it points at."


static func _off_by_one(actual: String, expected: String) -> bool:
	if not actual.is_valid_int() or not expected.is_valid_int():
		return false
	return absi(actual.to_int() - expected.to_int()) == 1
