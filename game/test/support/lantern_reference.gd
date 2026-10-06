class_name LanternReference
extends RefCounted
## A town built from the reference solutions, for tests and content checks: every letter up to `last_order` answered
## the way its solution answers it. A change order's solution takes the place of the function it changes.


static func files(catalog: Dictionary, language: String, last_order := 1 << 30) -> Dictionary:
	var chunks := {}  # module -> {function: source}, in the order functions first appear
	for id: String in catalog.order:
		var request: Dictionary = catalog.requests[id]
		if int(request.order) > last_order:
			break
		var module := String(request.module)
		if not chunks.has(module):
			chunks[module] = {}
		chunks[module][String(request.function)] = String(request.solution[language]).strip_edges()
	var out := {}
	for module: String in chunks:
		var parts: Array[String] = []
		parts.assign((chunks[module] as Dictionary).values())
		out[module] = ("\n\n\n" if language == SandboxJob.PYTHON else "\n\n").join(parts) + "\n"
	return out


## A town with every letter up to `last_order` answered by the reference, lanterns lit, on the day of the last one.
static func town(catalog: Dictionary, language: String, last_order := 1 << 30) -> Dictionary:
	var built := LanternRules.new_town(language)
	built.files = files(catalog, language, last_order)
	for id: String in catalog.order:
		var request: Dictionary = catalog.requests[id]
		if int(request.order) > last_order:
			break
		built.day = int(request.day)
		(built.read as Array).append(id)
		built.solved[id] = {"day": request.day}
		built.lanterns[LanternRules.lantern_of(catalog, id)] = LanternRules.LIT
	return built
