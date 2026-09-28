class_name Sound
extends RefCounted
## Music and sound effects by id (Art.music, Art.sound), on two buses whose volumes are the player's options. A missing
## file is silence. The players are made on first use and hang off the tree's root, so they outlive scene changes.
##
##   Sound.music("music-battle-salvage")   # crossfades from whatever was playing; the same track keeps playing
##   Sound.play("sfx-hit-compile", 0.8)    # one of its takes (sfx-hit-compile-1 ... -4), chosen at random
##   Sound.cue("cue-victory")              # in the music's place; music asked for meanwhile starts when it ends

const MUSIC_BUS := "Music"
const SOUND_BUS := "Sound"
## Enough for a volley: twenty bolts landing a tenth of a second apart, each ringing for half a second.
const VOICES := 12
const FADE := 0.8

static var _music: Array[AudioStreamPlayer] = []
static var _current := 0
static var _music_id := ""
static var _voices: Array[AudioStreamPlayer] = []
static var _next_voice := 0
static var _takes: Dictionary = {}
static var _cue: AudioStreamPlayer
## While a cue plays, the music it stands in for waits: the id asked for last, started when the cue ends.
static var _holding := false
static var _held := ""


static func music(id: String) -> void:
	if _holding:
		_held = id
		return
	if id == _music_id or not _ensure():
		return
	_music_id = id
	var stream := Art.music(id) if id != "" else null
	var old := _music[_current]
	_current = 1 - _current
	var new := _music[_current]
	var tween := old.create_tween()
	tween.tween_property(old, "volume_db", -40.0, FADE)
	tween.tween_callback(old.stop)
	if stream == null:
		return
	new.stream = stream
	new.volume_db = -40.0
	_start(new)
	new.create_tween().tween_property(new, "volume_db", 0.0, FADE)


static func play(id: String, volume := 1.0, pitch := 1.0) -> void:
	var found := takes(id)
	if found.is_empty() or not _ensure():
		return
	# LEARN: a sound heard many times over (a volley's hits) has several takes, so twenty hits do not sound like one
	# sample twenty times; randomness is fine here, since sound is presentation and never decides an outcome.
	var stream: AudioStream = found[randi() % found.size()]
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = stream
	voice.volume_db = linear_to_db(maxf(volume, 0.001))
	voice.pitch_scale = pitch
	_start(voice)


## The takes of sound `id`: its one file, or its numbered takes (`id-1`, `id-2` ...) when it was made as several
## (pipeline/audio/manifest.json, `variants`). Empty when there is neither.
static func takes(id: String) -> Array[AudioStream]:
	if not _takes.has(id):
		var found: Array[AudioStream] = []
		var one := Art.sound(id)
		if one != null:
			found.append(one)
		else:
			var index := 1
			var take := Art.sound("%s-%d" % [id, index])
			while take != null:
				found.append(take)
				index += 1
				take = Art.sound("%s-%d" % [id, index])
		_takes[id] = found
	return _takes[id]


## A cue in the music's place, as a fight won or a run lost: the music fades out, the cue plays on the music bus (it
## is music, and follows the music's volume), and whatever music is asked for while it plays starts when it ends, so
## the next screen's track never plays over the fanfare in another key.
static func cue(id: String, volume := 0.8) -> void:
	var stream := Art.sound(id)
	if stream == null or not _ensure():
		return
	_held = ""
	_holding = false
	music("")
	_holding = true
	_cue.stream = stream
	_cue.volume_db = linear_to_db(maxf(volume, 0.001))
	_start(_cue)


static func _cue_finished() -> void:
	_holding = false
	if _held != "":
		music(_held)
	_held = ""


## Stops everything and lets go of the streams. At exit, a stream still playing is otherwise reported as leaked.
static func silence() -> void:
	var players: Array[AudioStreamPlayer] = []
	players.append_array(_music)
	players.append_array(_voices)
	if is_instance_valid(_cue):
		players.append(_cue)
	for player in players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_music_id = ""
	_holding = false
	_held = ""


## The first sound can come before the players have joined the tree (they join deferred); it plays once they have.
static func _start(player: AudioStreamPlayer) -> void:
	if player.is_inside_tree():
		player.play()
	else:
		player.play.call_deferred()


static func set_volumes(music_volume: float, sound_volume: float) -> void:
	_buses()
	_set_bus(MUSIC_BUS, music_volume)
	_set_bus(SOUND_BUS, sound_volume)


static func _set_bus(bus: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume <= 0.001)


static func _buses() -> void:
	for bus: String in [MUSIC_BUS, SOUND_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


static func _ensure() -> bool:
	if not _music.is_empty() and is_instance_valid(_music[0]):
		return true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	_buses()
	_music.clear()
	_voices.clear()
	for i in 2:
		_music.append(_player(tree, MUSIC_BUS, "Music%d" % i))
	for i in VOICES:
		_voices.append(_player(tree, SOUND_BUS, "Voice%d" % i))
	_cue = _player(tree, MUSIC_BUS, "Cue")
	_cue.finished.connect(func() -> void: Sound._cue_finished())
	return true


static func _player(tree: SceneTree, bus: String, player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus
	# Sounds keep playing while the stage freezes for a heavy hit (hit-stop pauses nothing but time).
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(player)
	return player
