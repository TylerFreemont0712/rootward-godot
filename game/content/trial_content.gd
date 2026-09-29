class_name TrialContent
extends RefCounted
## The Trial's structure is JSONC. Its Japanese prose uses the same English-keyed overlay as other content.

const PATH := "res://content/trial/pip.jsonc"


static func load_trial(locale := "en") -> Dictionary:
	var parsed := Jsonc.parse_file(PATH)
	if not parsed.ok or not parsed.value is Dictionary:
		return {"ok": false, "error": "Pip's Trial content could not be read."}
	var trial: Dictionary = parsed.value
	if not trial.has("chapters") or not trial.has("steps") or (trial.steps as Array).is_empty():
		return {"ok": false, "error": "Pip's Trial has no chapters or steps."}
	if locale == "ja":
		var translations: Dictionary = ContentLocale.load_overlay("ja").strings
		if trial.has("loss_hint"):
			trial.loss_hint = translations.get(trial.loss_hint, trial.loss_hint)
		for chapter: Dictionary in trial.chapters:
			for field: String in ["title", "scene"]:
				chapter[field] = translations.get(chapter[field], chapter[field])
		for step: Dictionary in trial.steps:
			for field: String in ["say", "code"]:
				step[field] = translations.get(step[field], step[field])
	return {"ok": true, "value": trial}


static func step(trial: Dictionary, id: String) -> Dictionary:
	for entry: Dictionary in trial.get("steps", []):
		if entry.id == id:
			return entry
	return {}


static func chapter(trial: Dictionary, id: String) -> Dictionary:
	for entry: Dictionary in trial.get("chapters", []):
		if entry.id == id:
			return entry
	return {}
