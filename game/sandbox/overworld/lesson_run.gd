class_name LessonRun
extends RefCounted
## Runs the player's lesson programs in the sandbox (ADR-0061): lesson 2's save (what the town remembers about the
## player) and lesson 3's light_all (every lamp on the lane). Placeholder surface, filled in by the lessons work:
##
##   LessonRun.save(language, source, player)   # {ok, kept: Dictionary, message}: what the player's save returns
##   LessonRun.lamps(language, source, lamps)   # {ok, lamps: Array, message}: the lamps after light_all ran


static func save(_language: String, _source: String, _player: Dictionary) -> Dictionary:
	return {"ok": false, "kept": {}, "message": "saving is not built yet"}


static func lamps(_language: String, _source: String, lamps_in: Array) -> Dictionary:
	return {"ok": false, "lamps": lamps_in, "message": "light_all is not built yet"}
