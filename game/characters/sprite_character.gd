class_name SpriteCharacter
extends Control
## A character drawn as sprite sheets rather than a 3D model (ADR-0008): one grid of frames per clip, made by the
## sprite pipeline (pipeline/sprites/) into res://assets/sprites/<id>/ with a clips.json that says, per clip, how many
## frames, how fast, whether it loops, what follows it, and where the casting hand is in every frame.
##
##   var vesper := SpriteCharacter.create("vesper")
##   add_child(vesper)
##   vesper.play("cast-light")   # then back to the idle on its own
##
## A clip the skin was not drawn with plays its nearest stand-in (a heavy cast as the light one, a guard as the idle),
## so a skin with two clips still answers everything the fight asks.

signal clip_finished(clip: String)

const ROOT := "res://assets/sprites/%s/"
const IDLE := "idle-breathe"
## What to play when a clip was not drawn: the first one of these that exists.
const STAND_INS := {
	"cast-heavy": ["cast-heavy", "cast-light"],
	"cast-sigil": ["cast-sigil", "cast-light"],
	"windup": ["windup", "idle-breathe"],
	"channel": ["channel", "idle-breathe"],
	"guard": ["guard", "idle-breathe"],
	"hurt": ["hurt", "idle-breathe"],
	"victory": ["victory", "idle-breathe"],
	"death": ["death", "idle-breathe"],
	"idle-fidget": ["idle-fidget", "idle-breathe"],
}
## A cast's wind-up plays in exactly this long, whatever its frame count, so the palm is out when the stage launches
## the bolts (log_player.gd waits 380 ms after starting the cast).
const RELEASE_MS := 380.0
const FLASH := preload("res://characters/sprite_flash.gdshader")

## How much of the hero slot's height the frame fills. The slot is portrait and a frame is wide (room for the cast's
## arm), so the frame is fitted by height, its body line centred in the slot, and its empty sides allowed to overflow.
const FILL := 0.95

var id: String
var manifest: Dictionary = {}
var clip := ""
var frame := 0
var _time := 0.0
var _sheets: Dictionary = {}


static func exists(character_id: String) -> bool:
	return FileAccess.file_exists((ROOT % character_id) + "clips.json")


static func create(character_id: String) -> SpriteCharacter:
	var character := SpriteCharacter.new()
	character.id = character_id
	character.name = character_id
	character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character._load()
	return character


func _load() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string((ROOT % id) + "clips.json"))
	if not parsed is Dictionary:
		return
	manifest = parsed
	var format: String = manifest.get("format", "png")
	for name: String in manifest.get("clips", {}):
		var path := (ROOT % id) + "%s.%s" % [name, format]
		if ResourceLoader.exists(path):
			_sheets[name] = load(path)
	var flash := ShaderMaterial.new()
	flash.shader = FLASH
	material = flash
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	play(IDLE)


func has_clips() -> bool:
	return not _sheets.is_empty()


func play(wanted: String) -> void:
	var name := _resolve(wanted)
	if name == "":
		return
	clip = name
	frame = 0
	_time = 0.0
	queue_redraw()


func _resolve(wanted: String) -> String:
	for name: String in STAND_INS.get(wanted, [wanted]):
		if _sheets.has(name):
			return name
	return IDLE if _sheets.has(IDLE) else ""


## A colour flash over the whole figure (a hit, a cast); alpha is its strength.
func set_flash(colour: Color) -> void:
	(material as ShaderMaterial).set_shader_parameter("flash", colour)


## Where the casting hand is in this frame, in this control's own coordinates. While a cast winds up, the hand at its
## release: that is where the bolts leave from.
func hand_point() -> Vector2:
	var info: Dictionary = manifest.get("clips", {}).get(clip, {})
	var track: Array = info.get("hand", [])
	if track.is_empty():
		return Vector2(size.x * 0.72, size.y * 0.4)
	var index := frame
	if info.has("releaseFrame") and frame <= int(info.releaseFrame):
		index = int(info.releaseFrame)
	var point: Array = track[clampi(index, 0, track.size() - 1)]
	var box := _frame_rect()
	return box.position + Vector2(0.5 + float(point[0]), 1.0 - float(point[1])) * box.size


## Where a frame is drawn: fitted by height, its body line on the slot's centre, its soles on the slot's floor.
func _frame_rect() -> Rect2:
	var frame_size := Vector2(float(manifest.frame.width), float(manifest.frame.height))
	var drawn := frame_size * (size.y * FILL / frame_size.y)
	var baseline := float(manifest.get("baseline", 1.0))
	var x := size.x * 0.5 - float(manifest.get("center", 0.5)) * drawn.x
	var y := size.y - drawn.y * baseline
	return Rect2(Vector2(x, y), drawn)


func _process(delta: float) -> void:
	if clip == "":
		return
	var info: Dictionary = manifest.clips[clip]
	var count := int(info.frames)
	_time += delta
	var next := _frame_at(info, _time)
	if next >= count:
		if bool(info.get("loop", false)):
			_time = fposmod(_time, _duration(info))
			next = _frame_at(info, _time) % count
		else:
			var finished := clip
			clip_finished.emit(finished)
			if clip == finished:
				play(str(info.get("after", IDLE)))
			return
	if next != frame:
		frame = next
		queue_redraw()


## Which frame is showing `seconds` into a clip. A cast's frames up to its release take RELEASE_MS; the rest play at
## the clip's own rate.
func _frame_at(info: Dictionary, seconds: float) -> int:
	# The epsilon keeps a time that lands exactly on a frame (1 s at 32 fps) from rounding down to the one before.
	var fps := float(info.get("fps", 12.0))
	if not info.has("releaseFrame") or bool(info.get("loop", false)):
		return floori(seconds * fps + 1e-6)
	var release := int(info.releaseFrame)
	var windup := RELEASE_MS / 1000.0
	if seconds < windup:
		return floori(seconds / windup * release + 1e-6)
	return release + floori((seconds - windup) * fps + 1e-6)


func _duration(info: Dictionary) -> float:
	return float(info.frames) / float(info.get("fps", 12.0))


func _draw() -> void:
	var sheet: Texture2D = _sheets.get(clip)
	if sheet == null:
		return
	var info: Dictionary = manifest.clips[clip]
	var columns := int(info.get("columns", 8))
	var w := float(manifest.frame.width)
	var h := float(manifest.frame.height)
	var source := Rect2((frame % columns) * w, (frame / columns) * h, w, h)
	draw_texture_rect_region(sheet, _frame_rect(), source)
