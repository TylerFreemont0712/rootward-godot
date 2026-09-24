class_name Sound
extends RefCounted
## Music and sound effects by id (Art.music, Art.sound), on two buses whose volumes are the player's options. A missing
## file is silence. The players are made on first use and hang off the tree's root, so they outlive scene changes.
##
##   Sound.music("music-battle-salvage")   # crossfades from whatever was playing; the same track keeps playing
##   Sound.play("sfx-hit", 0.8)

const MUSIC_BUS := "Music"
const SOUND_BUS := "Sound"
const VOICES := 8
const FADE := 0.8

static var _music: Array[AudioStreamPlayer] = []
static var _current := 0
static var _music_id := ""
static var _voices: Array[AudioStreamPlayer] = []
static var _next_voice := 0


static func music(id: String) -> void:
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
	var stream := Art.sound(id)
	if stream == null or not _ensure():
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = stream
	voice.volume_db = linear_to_db(maxf(volume, 0.001))
	voice.pitch_scale = pitch
	_start(voice)


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
	return true


static func _player(tree: SceneTree, bus: String, player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus
	# Sounds keep playing while the stage freezes for a heavy hit (hit-stop pauses nothing but time).
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(player)
	return player
