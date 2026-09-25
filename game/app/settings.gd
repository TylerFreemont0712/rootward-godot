class_name Settings
extends RefCounted
## The player's options, remembered in user://settings.json. Presentation only: nothing here changes a rule.
##
##   Settings.load_file()
##   Settings.code_speed = "fast"
##   Settings.save_file()

const PATH := "user://settings.json"
const CODE_SPEEDS: Array[String] = ["off", "slow", "normal", "fast"]
const CHARACTER_SKINS: Array[String] = ["vesper", "emberfox"]

## How fast a cast plays as code before its bolts fly; "off" skips straight to the bolts.
static var code_speed := "normal"
## Show what a spell will do before it is cast, where the difficulty allows it.
static var predictions := true
## Shake the stage on heavy hits.
static var shake := true
## The last journey selected on the title screen.
static var playstyle := "deck"
## The last selected battle look. Vesper is the first impression on a fresh install.
static var character_skin := "vesper"
static var music_volume := 0.6
static var sound_volume := 0.8
## The last language and difficulty a run was started with, offered first next time.
static var language := SandboxJob.PYTHON
static var difficulty := "beginner"
static var path := PATH


static func load_file(from := PATH) -> void:
	path = from
	if not FileAccess.file_exists(path):
		return
	var saved: Variant = JsJson.parse(FileAccess.get_file_as_string(path))
	if not saved is Dictionary:
		return
	var values: Dictionary = saved
	var speed: Variant = values.get("code_speed")
	if speed is String and speed in CODE_SPEEDS:
		code_speed = speed
	predictions = _bool(values, "predictions", predictions)
	shake = _bool(values, "shake", shake)
	music_volume = _volume(values, "music_volume", music_volume)
	sound_volume = _volume(values, "sound_volume", sound_volume)
	var chosen: Variant = values.get("language")
	if chosen is String and chosen in SandboxJob.LANGUAGES:
		language = chosen
	if values.get("difficulty") is String:
		difficulty = values.difficulty
	if values.get("playstyle") in ["deck", "spellbook", "verifier"]:
		playstyle = values.playstyle
	var skin: Variant = values.get("character_skin")
	if skin is String:
		if skin in ["moonlit_kitsune", "tamamo_no_mae"]:
			# Retired looks: their players get the default one.
			character_skin = "vesper"
		elif skin in CHARACTER_SKINS:
			character_skin = skin


static func save_file() -> void:
	var values := {
		"code_speed": code_speed,
		"predictions": predictions,
		"shake": shake,
		"music_volume": music_volume,
		"sound_volume": sound_volume,
		"language": language,
		"difficulty": difficulty,
		"character_skin": character_skin,
		"playstyle": playstyle,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(values, "\t", false))


static func _bool(values: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = values.get(key)
	return value if value is bool else fallback


static func _volume(values: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = values.get(key)
	return clampf(float(value), 0.0, 1.0) if value is float or value is int else fallback
