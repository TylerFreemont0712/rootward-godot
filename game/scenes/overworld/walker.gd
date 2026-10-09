class_name Walker
extends Node2D
## Someone on the overworld's grid (ADR-0061): the player or a townsperson. Stands on a cell, faces a way, and walks
## one tile at a time with a step frame in the middle of the stride. Its position is its feet, so sorting the town by
## y draws whoever is nearer the bottom in front.

signal arrived(cell: Vector2i)

const TILE := 16
## Seconds per tile: brisk, like the games it is modelled on.
const STEP_TIME := 0.2

var cell := Vector2i.ZERO
var facing := "down"
var moving := false

var _sprite: Sprite2D
var _shadow: Node2D
var _texture: Texture2D
var _stride := 0
var _tween: Tween


func _init(sheet: Texture2D = null) -> void:
	_texture = sheet


func _ready() -> void:
	_shadow = Node2D.new()
	_shadow.draw.connect(_draw_shadow)
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = _texture
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.position = Vector2(-OverworldArt.FRAME.x / 2.0, -OverworldArt.FRAME.y)
	add_child(_sprite)
	_show(0)


func set_sheet(sheet: Texture2D) -> void:
	_texture = sheet
	if _sprite != null:
		_sprite.texture = sheet
		_show(0)


static func feet(at: Vector2i) -> Vector2:
	return Vector2(at.x * TILE + TILE / 2.0, at.y * TILE + TILE - 1)


func place(at: Vector2i, way := "") -> void:
	if _tween != null:
		_tween.kill()
	moving = false
	cell = at
	if way != "":
		facing = way
	position = feet(at)
	_show(0)


func face(way: String) -> void:
	if way == "":
		return
	facing = way
	_show(0)


func walk_to(at: Vector2i, way: String, time := STEP_TIME) -> void:
	facing = way
	cell = at
	moving = true
	_stride = 1 - _stride
	_show(1 + _stride)
	_tween = create_tween()
	_tween.tween_property(self, "position", feet(at), time)
	_tween.parallel().tween_callback(_show.bind(0)).set_delay(time * 0.55)
	_tween.tween_callback(_arrive)


## A small push toward a wall and back, for walking into something.
func bump(way: String) -> void:
	face(way)
	var push := Vector2(BootsRules.STEPS.get(way, Vector2i.ZERO)) * 2.0
	_tween = create_tween()
	_tween.tween_property(_sprite, "position:x", _sprite.position.x + push.x, 0.05)
	_tween.parallel().tween_property(_sprite, "position:y", _sprite.position.y + push.y, 0.05)
	_tween.tween_property(_sprite, "position", Vector2(-OverworldArt.FRAME.x / 2.0, -OverworldArt.FRAME.y), 0.08)


func _arrive() -> void:
	moving = false
	arrived.emit(cell)


func _show(pose: int) -> void:
	if _sprite == null:
		return
	if _texture == null:
		_sprite.texture = null
		queue_redraw()
		return
	_sprite.region_rect = Rect2(OverworldArt.frame_rect(facing, pose))
	_sprite.flip_h = facing == "right"


func _draw() -> void:
	if _texture == null:
		# No picture: a plain figure, so the town still works without its art.
		draw_rect(Rect2(-5, -18, 10, 18), Color("#e8d8bc"))
		draw_rect(Rect2(-5, -18, 10, 18), Color("#2a1d2b"), false, 1.0)


func _draw_shadow() -> void:
	var points := PackedVector2Array()
	for i in 12:
		var angle := TAU * i / 12.0
		points.append(Vector2(cos(angle) * 5.5, sin(angle) * 2.0 - 0.5))
	_shadow.draw_colored_polygon(points, Color(0.1, 0.06, 0.12, 0.28))
