class_name WalkPreview
extends Control
## The player's complete 64 x 96 sheet. The creator alternates walking and idle while showing all four directions;
## a fixed facing and walking=false show the same idle animation used by the character lineup.

const TURN := 3.6
const WALK_TIME := 2.0
const FACINGS: Array[String] = ["down", "left", "up", "right"]

var zoom := 2.0:
	set(value):
		zoom = value
		_fit()
		queue_redraw()
var walking := true
var turning := true
var facing := "down"
var shadow := true

var _sheet: CharacterSheet
var _clock := 0.0
var _shown := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fit()


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func _fit() -> void:
	var frame := Vector2(_sheet.frame) * _sheet.scale if _sheet != null else Vector2(OverworldScale.PERSON)
	custom_minimum_size = frame * zoom


func set_look(look: Dictionary) -> void:
	_sheet = OverworldArt.player_character(look)
	_fit()
	queue_redraw()


func figure() -> CharacterSheet:
	return _sheet


func _process(delta: float) -> void:
	if not is_visible_in_tree() or Settings.reduced_motion:
		return
	_clock += delta
	var column := _sheet.animation_column(_clip_now(), _clip_clock()) if _sheet != null else 0
	var shown := "%s/%s/%d" % [_facing_now(), _clip_now(), column]
	if shown != _shown:
		_shown = shown
		queue_redraw()


func _facing_now() -> String:
	return FACINGS[int(_clock / TURN) % FACINGS.size()] if walking and turning else facing


func _clip_now() -> String:
	return "walk" if walking and (not turning or fposmod(_clock, TURN) < WALK_TIME) else "idle"


func _clip_clock() -> float:
	if Settings.reduced_motion:
		return 0.0
	return maxf(0.0, fposmod(_clock, TURN) - WALK_TIME) if _clip_now() == "idle" and walking else _clock


func _screen_scale() -> float:
	if not is_inside_tree():
		return 1.0
	return maxf(0.01, get_viewport().get_final_transform().get_scale().x * get_global_transform_with_canvas().get_scale().x)


func _draw() -> void:
	var on_screen := _screen_scale()
	var art_scale := _sheet.scale if _sheet != null else 1.0
	var frame := _sheet.frame if _sheet != null else OverworldScale.PERSON
	var pixel := maxf(1.0, roundf(zoom * art_scale * on_screen)) / on_screen
	var drawn := Vector2(frame) * pixel
	var origin := (size - drawn) / 2.0
	if shadow:
		var ground := float(_sheet.ground) if _sheet != null else 93.0
		draw_set_transform(origin + Vector2(drawn.x / 2.0, ground * pixel), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, drawn.x * 0.22, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO)
	if _sheet == null or _sheet.texture == null:
		draw_rect(Rect2(origin + drawn * Vector2(0.28, 0.1), drawn * Vector2(0.44, 0.85)), UiTheme.AMBER_DIM)
		return
	var way := _facing_now()
	var clip := "idle" if Settings.reduced_motion else _clip_now()
	var region := Rect2(_sheet.animation_rect(way, clip, _clip_clock()))
	if _sheet.flipped(way):
		draw_set_transform(origin + Vector2(drawn.x, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(_sheet.texture, Rect2(Vector2.ZERO, drawn), region)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect_region(_sheet.texture, Rect2(origin, drawn), region)
