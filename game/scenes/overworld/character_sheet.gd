class_name CharacterSheet
extends RefCounted
## One character's frames on one texture, and where each facing and pose sits (ADR-0061, ADR-0063, ADR-0071):
##
##   parts  a look built from parts by OverworldArt.compose: 25 x 35 frames, rows down, up, left (right is left,
##          mirrored), columns standing, step a, step b. It has no idle frame, so idle shows the standing one.
##   cast   a sheet made by pipeline/animation/cast.py, laid out as its index says: one row per facing,
##          with stop, four step poses, and idle when present. Older cast sheets without step columns use idle while
##          walking.
##   player the complete male/female sheets: four directional rows, four idle frames and eight walking frames,
##          selected by named animation clips with a continuous clock.
##
## `ground` is the frame's row the feet stand on: a walker draws the frame with that row on its tile. `scale` is how
## much larger than drawn the frames are shown: 1 for a sheet cut for this world, more for one drawn for 16 px tiles
## (ADR-0064).

const STAND := 0
const STEP_A := 1
const STEP_B := 2
const STEP_C := 3
const STEP_D := 4
const IDLE := 5

var texture: Texture2D
var frame := Vector2i.ZERO
var ground := 0
var scale := 1.0
## facing -> row, and the facings drawn as another row mirrored (facing -> true).
var rows := {}
var mirrored := {}
## pose -> column.
var columns := {}
## Named animation clips: {frames: [column, ...], fps: number, durations: [seconds, ...] (optional)}.
var animations: Dictionary = {}


## A sheet built from parts (OverworldArt.compose). `texture` may be null: there is no picture to draw. Parts are drawn
## for 16 px tiles, so they are shown enlarged.
static func parts(texture: Texture2D, frame: Vector2i) -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.texture = texture
	sheet.frame = frame
	sheet.ground = frame.y
	sheet.scale = OverworldScale.upscale(OverworldScale.OLD_TILE)
	sheet.rows = {"down": 0, "up": 1, "left": 2, "right": 2}
	sheet.mirrored = {"right": true}
	sheet.columns = {STAND: 0, STEP_A: 1, STEP_B: 2, STEP_C: 1, STEP_D: 2, IDLE: 0}
	return sheet


## A sheet from the cast pipeline, laid out by its index (`frame`, `ground`, `rows`, `columns`). A facing the index has
## no row for is drawn as its mirror's row, flipped, when that one is there.
static func cast(texture: Texture2D, layout: Dictionary) -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.texture = texture
	var size: Array = layout.get("frame", [0, 0])
	sheet.frame = Vector2i(int(size[0]), int(size[1]))
	sheet.ground = int(layout.get("ground", sheet.frame.y))
	sheet.scale = OverworldScale.upscale(OverworldScale.drawn_tile(layout))
	var facings: Array = layout.get("rows", [])
	for i in facings.size():
		sheet.rows[String(facings[i])] = i
	for pair: Array in [["left", "right"], ["right", "left"]]:
		if not sheet.rows.has(pair[1]) and sheet.rows.has(pair[0]):
			sheet.rows[pair[1]] = sheet.rows[pair[0]]
			sheet.mirrored[pair[1]] = true
	var poses: Array = layout.get("columns", [])
	var stop := maxi(0, poses.find("stop"))
	var idle := poses.find("idle")
	var step_a := poses.find("step_a")
	var step_b := poses.find("step_b")
	var step_c := poses.find("step_c")
	var step_d := poses.find("step_d")
	var fallback := idle if idle >= 0 else stop
	sheet.columns = {
		STAND: stop,
		STEP_A: step_a if step_a >= 0 else fallback,
		STEP_B: step_b if step_b >= 0 else fallback,
		STEP_C: step_c if step_c >= 0 else (step_a if step_a >= 0 else fallback),
		STEP_D: step_d if step_d >= 0 else (step_b if step_b >= 0 else fallback),
		IDLE: idle if idle >= 0 else stop,
	}
	var clips: Variant = layout.get("animations", {})
	if clips is Dictionary:
		sheet.animations = clips.duplicate(true)
	if sheet.has_animation("idle"):
		sheet.columns[STAND] = sheet.animation_column("idle", 0.0)
		sheet.columns[IDLE] = int((sheet.animations.idle.frames as Array)[1]) if (sheet.animations.idle.frames as Array).size() > 1 else sheet.columns[STAND]
	return sheet


## The frame for a facing and a pose (STAND, STEP_A, STEP_B, IDLE).
func rect(facing: String, pose: int) -> Rect2i:
	var row := int(rows.get(facing, 0))
	var column := int(columns.get(pose, 0))
	return Rect2i(Vector2i(column * frame.x, row * frame.y), frame)


## Whether a facing is drawn flipped left to right (it borrows its mirror's row).
func flipped(facing: String) -> bool:
	return bool(mirrored.get(facing, false))


## Whether standing still has a frame of its own to breathe on.
func breathes() -> bool:
	return int(columns.get(IDLE, 0)) != int(columns.get(STAND, 0))


func has_animation(clip: String) -> bool:
	var entry: Variant = animations.get(clip, {})
	if not entry is Dictionary:
		return false
	var frames: Variant = entry.get("frames", [])
	return frames is Array and not (frames as Array).is_empty()


## The clip clock runs across tiles. Per-frame durations keep a blink short without speeding up the whole breath.
func animation_column(clip: String, clock: float) -> int:
	if not has_animation(clip):
		return int(columns.get(STAND, 0))
	var entry: Dictionary = animations[clip]
	var frames: Array = entry.frames
	var durations: Array = entry.get("durations", [])
	if durations.size() == frames.size():
		var total := 0.0
		for duration: Variant in durations:
			total += maxf(0.001, float(duration))
		var phase := fposmod(maxf(0.0, clock), total)
		for i in frames.size():
			phase -= maxf(0.001, float(durations[i]))
			if phase < 0.0:
				return int(frames[i])
	var index := int(maxf(0.0, clock) * maxf(0.01, float(entry.get("fps", 12.0)))) % frames.size()
	return int(frames[index])


func animation_rect(facing: String, clip: String, clock: float) -> Rect2i:
	return Rect2i(Vector2i(animation_column(clip, clock) * frame.x, int(rows.get(facing, 0)) * frame.y), frame)
