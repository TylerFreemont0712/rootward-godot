class_name Art
extends RefCounted
## Pictures and sounds by id, with nothing required: a missing file is `null`, and every caller has a fallback (a
## plain shape, silence). Files live under res://assets/ as the pipeline writes them (pipeline/README.md).
##
##   Art.texture("backgrounds/arena-salvage")   # Texture2D or null
##   Art.music("music-battle-salvage")          # loops where music.json says it does
##   Art.sound("sfx-hit")

const ROOT := "res://assets/"
const LOOPS := "res://assets/audio/music.json"

static var _loops: Dictionary = {}


static func texture(id: String) -> Texture2D:
	var path := ROOT + id + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func sound(id: String) -> AudioStream:
	var path := ROOT + "audio/" + id + ".ogg"
	return load(path) as AudioStream if ResourceLoader.exists(path) else null


## A music track set to loop. LEARN: each file ends exactly at its loop point (the pipeline crossfades the seam into
## the file), so looping from `loopStart` to the end of the file is the whole loop; Godot has no loop-end setting.
static func music(id: String) -> AudioStream:
	var stream := sound(id) as AudioStreamOggVorbis
	if stream == null:
		return null
	if _loops.is_empty() and FileAccess.file_exists(LOOPS):
		_loops = JSON.parse_string(FileAccess.get_file_as_string(LOOPS))
	var loop: Dictionary = _loops.get(id, {})
	stream.loop = true
	stream.loop_offset = float(loop.get("loopStart", 0.0))
	return stream
