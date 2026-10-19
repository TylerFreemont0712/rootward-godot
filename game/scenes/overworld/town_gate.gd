class_name TownGate
extends Node2D
## An authored hinged passage. Occupancy is visual and never changes a programmed lock or the map's collision.

const SWING_TIME := 0.16

var footprint := Rect2i()
var automatic := false
var opened := false
var progress := 0.0

var _sprite: Sprite2D
var _frames := 1
var _width := 0.0


func configure(object: Dictionary, texture: Texture2D, frames: int, is_open := false) -> void:
	footprint = Rect2i(object.at, object.size)
	automatic = not object.has("program") and not bool(object.get("solid", true))
	opened = is_open
	progress = 1.0 if opened else 0.0
	_frames = maxi(1, frames)
	position = Vector2(
		(footprint.position.x + footprint.size.x / 2.0) * OverworldScale.TILE,
		(footprint.position.y + 0.5) * OverworldScale.TILE
	)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = texture
	if texture != null:
		var stretch := TownMapView._stretch(object)
		_sprite.scale = stretch
		_width = texture.get_width() / float(_frames)
		_sprite.region_enabled = true
		_sprite.flip_h = bool(object.get("flip", false))
		_sprite.position = Vector2(-_width / 2.0 * stretch.x, (footprint.size.y - 0.5) * OverworldScale.TILE - texture.get_height() * stretch.y)
		_sprite.position.y += float(object.get("sink", 0)) * stretch.y
	add_child(_sprite)
	_show_frame()


func update_occupancy(cells: Dictionary) -> void:
	if not automatic:
		return
	opened = false
	for cell: Vector2i in cells:
		if footprint.has_point(cell):
			opened = true
			return


func _process(delta: float) -> void:
	var target := 1.0 if opened else 0.0
	var next := target if Settings.reduced_motion else move_toward(progress, target, delta / SWING_TIME)
	if next != progress:
		progress = next
		_show_frame()


func _show_frame() -> void:
	queue_redraw()
	if _sprite != null and _sprite.texture != null:
		var eased := progress * progress * (3.0 - 2.0 * progress)
		_sprite.region_rect = Rect2(roundi(eased * (_frames - 1)) * _width, 0, _width, _sprite.texture.get_height())


func _draw() -> void:
	if _sprite != null and _sprite.texture == null:
		var width := footprint.size.x * OverworldScale.TILE
		for x: float in [-width / 2.0 + 2.0, width / 2.0 - 6.0]:
			draw_rect(Rect2(x, -40, 5, 40), Color("#9a6a3a"))
		if not opened:
			draw_rect(Rect2(-width / 2.0 + 7, -36, width - 14, 30), Color("#6d472d"))
