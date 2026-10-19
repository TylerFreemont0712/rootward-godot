class_name Walker
extends Node2D
## Someone on the overworld's grid (ADR-0061): the player or a townsperson. Stands on a cell, faces a way, and walks
## one tile at a time. Authored clips continue across tiles; legacy NPC sheets use alternating step poses. Its position
## is its feet, so sorting the town by y draws whoever is nearer the bottom in front. Standing still plays the authored
## idle clip or alternates the cast's two breathing frames (ADR-0063, ADR-0071).

signal arrived(cell: Vector2i)

const TILE := OverworldScale.TILE
## Tile travel is independent of the authored 12 fps gait, so a quicker walk does not rush the animation.
const WALK_SPEED_MULTIPLIER := 1.25
const VERTICAL_WALK_ANIMATION_RATE := 0.85
const STEP_TIME := 0.22 / WALK_SPEED_MULTIPLIER
## Seconds per breath, and the share of it spent on the idle frame (the body settled a pixel).
const BREATH := 1.6
const SETTLED := 0.4

var cell := Vector2i.ZERO
var facing := "down"
var moving := false

var _sprite: Sprite2D
var _shadow: Node2D
var _art: Node2D
var _sheet: CharacterSheet
var _stride := 0
var _tween: Tween
var _clock := 0.0
var _pose := CharacterSheet.STAND
var _walk_clock := 0.0
var _rest_clock := 1.0


func _init(sheet: CharacterSheet = null) -> void:
	_sheet = sheet


func _ready() -> void:
	_shadow = Node2D.new()
	_shadow.z_index = -2
	_shadow.draw.connect(_draw_shadow)
	add_child(_shadow)
	_art = Node2D.new()
	add_child(_art)
	_apply_sheet()


func set_sheet(sheet: CharacterSheet) -> void:
	_sheet = sheet
	if _art != null:
		_apply_sheet()


static func feet(at: Vector2i) -> Vector2:
	return Vector2(at.x * TILE + TILE / 2.0, at.y * TILE + TILE - 1)


## The pose a still figure shows `clock` seconds into its breathing: standing, then settled for the end of each breath.
static func breath_pose(clock: float) -> int:
	return CharacterSheet.IDLE if fposmod(clock, BREATH) >= BREATH * (1.0 - SETTLED) else CharacterSheet.STAND


func place(at: Vector2i, way := "") -> void:
	if _tween != null:
		_tween.kill()
	moving = false
	_walk_clock = 0.0
	_rest_clock = 1.0
	cell = at
	if way != "":
		facing = way
	position = feet(at)
	# Neighbours do not breathe in step: each starts its breath at a point set by where it stands.
	_clock = float(posmod(at.x * 7 + at.y * 13, 10)) / 10.0 * BREATH
	_show(CharacterSheet.STAND)


func face(way: String) -> void:
	if way == "":
		return
	facing = way
	_show(CharacterSheet.STAND)


func walk_to(at: Vector2i, way: String, time := STEP_TIME) -> void:
	facing = way
	cell = at
	moving = true
	_rest_clock = 0.0
	if _sheet != null and _sheet.has_animation("walk"):
		_show_animation("walk", _walk_clock)
		_tween = create_tween()
		_tween.tween_property(self, "position", feet(at), time)
		_tween.tween_callback(_arrive)
		return
	_stride = 1 - _stride
	var phase_start := 2 if _stride == 1 else 0
	var poses: Array[int] = []
	for phase in 4:
		poses.append(CharacterSheet.STEP_A + posmod(phase_start + phase, 4))
	_show(poses[0])
	_tween = create_tween()
	_tween.tween_property(self, "position", feet(at), time)
	for phase in range(1, poses.size()):
		_tween.parallel().tween_callback(_show.bind(poses[phase])).set_delay(time * phase / poses.size())
	_tween.tween_callback(_arrive)


## A small push toward a wall and back, for walking into something.
func bump(way: String) -> void:
	face(way)
	if _art == null:
		return
	var push := Vector2(BootsRules.STEPS.get(way, Vector2i.ZERO)) * TILE / 8.0
	_tween = create_tween()
	_tween.tween_property(_art, "position", push, 0.05)
	_tween.tween_property(_art, "position", Vector2.ZERO, 0.08)


func _process(delta: float) -> void:
	if _sheet == null:
		return
	if moving:
		if _sheet.has_animation("walk"):
			_walk_clock += delta * (
				VERTICAL_WALK_ANIMATION_RATE if facing in ["up", "down"] else 1.0
			)
			_show_animation("walk", _walk_clock)
		return
	_rest_clock += delta
	# LEARN: A tile arrival is not the end of a held-key walk. Keep the clip clock and allow the next tile to start
	# before changing to idle, so crossing a grid seam cannot flash a standing pose or restart the same boot.
	if _sheet.has_animation("walk") and _rest_clock < 0.06 and _walk_clock > 0.0:
		return
	if _rest_clock > 0.12:
		_walk_clock = 0.0
	_clock += delta
	if _sheet.has_animation("idle"):
		_show_animation("idle", 0.0 if Settings.reduced_motion else _clock)
		return
	if not _sheet.breathes():
		return
	var pose := breath_pose(_clock)
	if pose != _pose:
		_show(pose)


func _arrive() -> void:
	moving = false
	_rest_clock = 0.0
	if _sheet == null or not _sheet.has_animation("walk"):
		_show(CharacterSheet.STAND)
	arrived.emit(cell)


## Where the frame's top-left sits from the feet: centred, with the sheet's ground row on the tile.
func _rest() -> Vector2:
	var frame := Vector2(_frame()) * _scale()
	var ground := _sheet.ground * _scale() if _sheet != null else frame.y
	return Vector2(-floorf(frame.x / 2.0), -roundf(ground))


func _frame() -> Vector2i:
	return _sheet.frame if _sheet != null and _sheet.frame != Vector2i.ZERO else OverworldScale.PERSON


## How much larger than drawn the sheet is shown (ADR-0064): 1 for a cast sheet cut for this world.
func _scale() -> float:
	return _sheet.scale if _sheet != null else 1.0


func _apply_sheet() -> void:
	if _art == null:
		return
	if _sprite == null:
		_sprite = _new_sprite()
		_art.add_child(_sprite)
	_sprite.texture = _sheet.texture if _sheet != null else null
	_sprite.scale = Vector2.ONE * _scale()
	_sprite.position = _rest()
	_shadow.queue_redraw()
	queue_redraw()
	_show(CharacterSheet.STAND)


func _new_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.region_enabled = true
	sprite.centered = false
	return sprite


func _show(pose: int) -> void:
	_pose = pose
	if _sheet == null or _sheet.texture == null:
		if _sprite != null:
			_sprite.texture = null
		queue_redraw()
		return
	if _sprite == null:
		return
	_sprite.region_rect = Rect2(_sheet.rect(facing, pose))
	_sprite.flip_h = _sheet.flipped(facing)


func _show_animation(clip: String, clock: float) -> void:
	if _sprite == null or _sheet == null or _sheet.texture == null:
		return
	_sprite.region_rect = Rect2(_sheet.animation_rect(facing, clip, clock))
	_sprite.flip_h = _sheet.flipped(facing)


func _draw() -> void:
	if _sheet == null or _sheet.texture == null:
		# No picture: a plain figure, so the town still works without its art.
		var tall := OverworldScale.PERSON.y * 0.8
		var width := OverworldScale.PERSON.x * 0.5
		var fallback := Rect2(Vector2(-width / 2.0, -tall), Vector2(width, tall))
		draw_rect(fallback, Color("#e8d8bc"))
		draw_rect(fallback, Color("#2a1d2b"), false, 1.0)


func _draw_shadow() -> void:
	# The shadow is a flat oval under the feet, as wide as about half the figure: 28 px on a 64 px frame.
	var radius := _frame().x * _scale() * 0.22
	var flat := TILE / 8.0
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		points.append(Vector2(cos(angle) * radius, sin(angle) * flat - 1.0))
	_shadow.draw_colored_polygon(points, Color(0.1, 0.06, 0.12, 0.28))
