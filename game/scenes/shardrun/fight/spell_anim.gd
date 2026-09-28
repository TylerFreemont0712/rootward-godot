class_name SpellAnim
extends Sprite2D
## One of the pipeline's spell animations (pipeline/sprites/spells.py, ADR-0014) playing on the stage: a sheet of frames
## drawn as light and shade, coloured by an element's ramp (spell_anim.gdshader). It plays once and frees itself, or
## loops until `stop()` (a bolt in flight). `impact` fires on the frame its blow lands, so a foe can recoil on it.
##
##   var hit := SpellAnim.play(stage_fx, "hit-compile", target, "fire", 1.2)
##   if hit != null: await hit.impact

signal impact

const ROOT := "res://assets/fx/spells/"
const SHADER := preload("res://scenes/shardrun/fight/spell_anim.gdshader")
## Each ramp's dark, mid and hot colours. The hot end is a pale tint of the colour, so a blow is vivid, not blinding.
const RAMPS := {
	"none": ["#1c0b3a", "#9b6cff", "#eadcff"],
	"fire": ["#3a0a00", "#ff6a1a", "#ffe2a8"],
	"frost": ["#041a3a", "#3fb6ff", "#dff6ff"],
	"spark": ["#2a1a00", "#ffc83a", "#fff4cc"],
	"ward": ["#032a22", "#33d6b6", "#d8fff4"],
	"foe": ["#2a0006", "#ff3a4a", "#ffd6d6"],
	"tempo": ["#2a1800", "#ffb13a", "#fff0c8"],
}

static var _facts: Dictionary = {}

var facts: Dictionary = {}
var looping := false
var clock := 0.0
var _landed := false
var _stopping := false


## The sheet's facts ({frames, columns, size, fps, loop, anchor, impact, texture}), or {} when it is not there.
static func facts_of(id: String) -> Dictionary:
	if not _facts.has(id):
		var found := {}
		var path := ROOT + id + ".json"
		if FileAccess.file_exists(path) and ResourceLoader.exists(ROOT + id + ".png"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				found = parsed
				found.texture = load(ROOT + id + ".png")
		_facts[id] = found
	return _facts[id]


static func has(id: String) -> bool:
	return not facts_of(id).is_empty()


## Plays animation `id` at `at` in `parent`, coloured by `ramp` (an element, or ward, foe, tempo), `size` times its
## drawn size, turned by `angle` radians. Null when the sheet is not there.
static func play(parent: Node, id: String, at: Vector2, ramp := "none", size := 1.0, angle := 0.0) -> SpellAnim:
	var found := facts_of(id)
	if found.is_empty():
		return null
	var anim := SpellAnim.new()
	anim.facts = found
	anim.looping = bool(found.get("loop", false))
	anim.texture = found.texture
	anim.hframes = int(found.columns)
	anim.vframes = ceili(float(found.frames) / float(found.columns))
	var frame_size := Vector2(float(found.size[0]), float(found.size[1]))
	var anchor: Array = found.get("anchor", [0.5, 0.5])
	anim.offset = Vector2(0.5 - float(anchor[0]), 0.5 - float(anchor[1])) * frame_size
	anim.position = at
	anim.scale = Vector2.ONE * size
	anim.rotation = angle
	var colours: Array = RAMPS.get(ramp, RAMPS.none)
	var shading := ShaderMaterial.new()
	shading.shader = SHADER
	shading.set_shader_parameter("dark", Color(colours[0]))
	shading.set_shader_parameter("mid", Color(colours[1]))
	shading.set_shader_parameter("hot", Color(colours[2]))
	anim.material = shading
	parent.add_child(anim)
	return anim


## Returns once the blow has landed (at once if it already has): a safe thing to await.
func landed() -> void:
	if not _landed:
		await impact


## Seconds from its start to its blow.
func impact_time() -> float:
	return float(facts.get("impact", 0.0)) * float(facts.frames) / float(facts.fps)


func duration() -> float:
	return float(facts.frames) / float(facts.fps)


## An animation taken off the stage before its blow still lets go of whoever waits for it (`landed()`): an awaited
## signal that never fires would hold that code forever.
func _exit_tree() -> void:
	if not _landed:
		_landed = true
		impact.emit()


## A looping animation fades out quickly and goes.
func stop() -> void:
	if _stopping:
		return
	_stopping = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)


## LEARN: _process gets `delta` already scaled by Engine.time_scale, so a hit-stop freezes every animation on the stage
## at once, which is what makes the stop feel like weight.
func _process(delta: float) -> void:
	clock += delta
	var index := floori(clock * float(facts.fps))
	var count := int(facts.frames)
	if not _landed and clock >= impact_time():
		_landed = true
		impact.emit()
	if looping:
		frame = index % count
	elif index >= count:
		queue_free()
	else:
		frame = index
