class_name UiFonts
extends RefCounted
## Shipped typeface candidates; no download or installed Latin font is needed at runtime.

const CHOICES := {
	"default": ["Original · IBM Plex Mono", "The original amber terminal", "今の琥珀色のターミナル"],
	"cinzel": ["Cinzel · Default", "Engraved brass & ancient inscriptions", "真鍮の刻印と古い碑文"],
	"alegreya": ["Alegreya", "A warm, handwritten storybook", "あたたかい物語の本"],
	"lora": ["Lora", "A lantern-lit journal", "灯りに照らされた日記"],
	"spectral": ["Spectral", "A scholar's field notes", "学者の観察ノート"],
	"exo2": ["Exo 2", "The artificer's precise instruments", "工匠の精密な道具"],
}
const ROOT := "res://ui/fonts/"
static var _faces: Dictionary = {}


static func face(id: String, weight := 400) -> Font:
	if id == "default" or not CHOICES.has(id):
		return null
	var key := "%s-%d" % [id, weight]
	if _faces.has(key):
		return _faces[key]
	var path := ROOT + id + ("-600" if id == "spectral" and weight >= 600 else "") + ".ttf"
	if not ResourceLoader.exists(path):
		return null
	var base := load(path) as FontFile
	var system := SystemFont.new()
	system.font_names = PackedStringArray(
		["Noto Sans CJK JP" if id == "exo2" else "Noto Serif CJK JP", "Noto Sans CJK JP", "DejaVu Sans"]
	)
	system.font_weight = weight
	base.fallbacks = [system]
	var font := FontVariation.new()
	font.base_font = base
	font.variation_opentype = {"wght": float(weight)} if id != "spectral" else {}
	font.fallbacks = [system]
	_faces[key] = font
	return font
