class_name ProgramCatalogs
extends RefCounted
## Program run catalogs for tests, changed the way a test needs them and nothing else.


## The catalog with Initiative off (ADR-0017), so a test's arithmetic is the landing alone. Initiative has its own test.
static func without_initiative(from: Dictionary) -> Dictionary:
	var copy := from.duplicate()
	copy.programs = (from.programs as Dictionary).duplicate()
	copy.programs.config = (from.programs.config as Dictionary).duplicate()
	copy.programs.config.initiative = 0.0
	return copy
