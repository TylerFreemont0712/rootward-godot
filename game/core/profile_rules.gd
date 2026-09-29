class_name ProfileRules
extends RefCounted
## Names and ordering are pure so profile storage and menus agree.

const MAX_NAME_LENGTH := 24
const HALF_KANA := "｡｢｣､･ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝﾞﾟ"
const FULL_KANA := "。「」、・ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン゛゜"


static func clean_name(raw: String) -> String:
	return raw.replace("　", " ").replace("\u00a0", " ").strip_edges()


static func name_key(raw: String) -> String:
	var output := ""
	for index in raw.length():
		var point := raw.unicode_at(index)
		var character := raw.substr(index, 1)
		# LEARN: Godot has case conversion but no NFKC helper; fold full-width ASCII and half-width kana here.
		if point >= 0xff01 and point <= 0xff5e:
			character = String.chr(point - 0xfee0)
		else:
			var kana_index := HALF_KANA.find(character)
			if kana_index >= 0:
				character = FULL_KANA.substr(kana_index, 1)
		output += character
	return clean_name(output).to_lower()


static func name_error(raw: String, existing: Array[String]) -> String:
	var name := clean_name(raw)
	if name.is_empty():
		return "Enter a name."
	if name.length() > MAX_NAME_LENGTH:
		return "Use at most %d characters." % MAX_NAME_LENGTH
	for index in name.length():
		if name.unicode_at(index) < 32:
			return "Names cannot contain control characters."
	var key := name_key(name)
	for other in existing:
		if name_key(other) == key:
			return "That name is already in use."
	return ""


static func ordered(profiles: Array[Dictionary], active_id: String) -> Array[Dictionary]:
	var result := profiles.duplicate()
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a.id == active_id or b.id == active_id:
				return a.id == active_id
			if a.get("last_played", "") != b.get("last_played", ""):
				return a.get("last_played", "") > b.get("last_played", "")
			return a.created_at < b.created_at
	)
	return result
