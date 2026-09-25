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
const RELIC_ATLAS := {
	"clockwork-hourglass": 0,
	"branching-key": 2,
	"cache-jar": 3,
	"copper-loop": 4,
	"firewall-tile": 5,
	"recursive-spiral": 6,
	"frost-ledger": 7,
	"ember-abacus": 8,
	"null-mask": 9,
	"star-clock": 10,
	"compiler-die": 11,
	"checksum-seal": 12,
	"ward-prism": 13,
	"thorn-battery": 14,
	"gear-halo": 15,
	"waveform-shell": 16,
	"memory-tablet": 17,
	"twin-lanterns": 18,
	"ouroboros-cable": 19,
	"sorting-comb": 20,
	"portal-ring": 21,
	"circuit-seed": 23,
	"pendulum-pin": 24,
	"algorithm-knot": 26,
}
const SHARD_ATLAS := {
	"early-return": 8,
	"branch-gate": 1,
	"binary-pick": 10,
	"index-map": 6,
	"weakest-route": 4,
	"reduce-sum": 9,
	"memo-table": 7,
	"pairwise-loop": 0,
}

static var _loops: Dictionary = {}


## A picture by id. A WebP (the painted, high-resolution backgrounds) wins over a PNG of the same name.
static func texture(id: String) -> Texture2D:
	for extension: String in [".webp", ".png"]:
		var path := ROOT + id + extension
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	if id.begins_with("shardrun/relic-"):
		return _atlas("relics", int(RELIC_ATLAS.get(id.trim_prefix("shardrun/relic-"), -1)), 6, 229)
	if id.begins_with("shardrun/shard-"):
		return _atlas("shards", int(SHARD_ATLAS.get(id.trim_prefix("shardrun/shard-"), -1)), 4, 362)
	return null


static func _atlas(sheet: String, index: int, columns: int, cell: int) -> Texture2D:
	if index < 0:
		return null
	var atlas := load("res://assets/concepts/%s.png" % sheet) as Texture2D
	if atlas == null:
		return null
	var piece := AtlasTexture.new()
	piece.atlas = atlas
	piece.region = Rect2((index % columns) * cell, floori(float(index) / float(columns)) * cell, cell, cell)
	piece.filter_clip = true
	return piece


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
