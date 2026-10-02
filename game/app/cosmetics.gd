class_name Cosmetics
extends RefCounted
## The cosmetic catalogue (content/cosmetics.jsonc, ADR-0037) and the loadout the player wears, read once a session.
## The rules of choosing are CosmeticRules; this only reads the file, translates names and notes for the screen, and
## answers for the saved loadout (Settings.loadout).

const PATH := "res://content/cosmetics.jsonc"

static var _catalog: Dictionary = {}
static var _japanese: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed := Jsonc.parse_file(PATH)
		_catalog = parsed.value if parsed.ok and parsed.value is Dictionary else {}
	return _catalog


## The saved loadout with every slot filled.
static func loadout(saved: Variant = null) -> Dictionary:
	return CosmeticRules.sanitize(Settings.loadout if saved == null else saved, catalog())


## The option worn in `slot` by `chosen` (a loadout; the saved one when empty).
static func look(slot: String, chosen: Dictionary = {}) -> Dictionary:
	var worn := loadout(chosen if not chosen.is_empty() else null)
	return CosmeticRules.option(catalog(), slot, String(worn.get(slot, "")))


static func options(slot: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Variant in catalog().get(slot, []):
		if entry is Dictionary:
			found.append(entry)
	return found


## An option's name or note as the player reads it (Japanese from the content overlay when the profile is).
static func text(english: String) -> String:
	if Game.profile.get("preferred_language", "en") != "ja":
		return english
	if _japanese.is_empty():
		_japanese = ContentLocale.load_overlay("ja").strings
	return String(_japanese.get(english, english))
