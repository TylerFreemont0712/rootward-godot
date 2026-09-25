class_name StageCharacter
extends Node3D
## A character on the stage: an imported glTF dressed in the toon shader and ink outline, playing its authored clips
## with short blends between them.
##
##   var fox := StageCharacter.create("emberfox")
##   add_child(fox)
##   fox.play("cast-light")      # then back to idle on its own
##
## A character with no model file becomes an empty node: art is optional, and the stage still runs.

signal clip_finished(clip: String)

const TOON := preload("res://characters/toon.gdshader")
const OUTLINE := preload("res://characters/outline.gdshader")
## Seconds to cross-fade from one clip into the next.
const BLEND := 0.18
## Clips that loop; every other clip returns to the idle when it ends (or holds its last pose, see HOLDS).
const LOOPS: Array[String] = ["idle-breathe", "channel"]
const HOLDS: Array[String] = ["victory", "death", "windup"]
const IDLE := "idle-breathe"

var id: String
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var materials: Array[ShaderMaterial] = []


static func create(character_id: String) -> StageCharacter:
	var character := StageCharacter.new()
	character.id = character_id
	character.name = character_id
	var path := "res://characters/%s/%s.glb" % [character_id, character_id]
	if ResourceLoader.exists(path):
		character.model = (load(path) as PackedScene).instantiate() as Node3D
		character.add_child(character.model)
		character._dress()
	return character


func _ready() -> void:
	if player != null:
		play(IDLE)


func has_model() -> bool:
	return model != null


func play(clip: String) -> void:
	if player == null or not player.has_animation(clip):
		return
	player.play(clip, BLEND)


## A flash of colour over the whole character (a hit, a cast); alpha is its strength.
func set_flash(colour: Color) -> void:
	for material in materials:
		material.set_shader_parameter("flash", colour)


func _dress() -> void:
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		_toon(mesh as MeshInstance3D)
	if player != null:
		for clip in LOOPS:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		player.animation_finished.connect(_on_finished)
	_add_spring_bones()


func _toon(mesh: MeshInstance3D) -> void:
	for surface in mesh.mesh.get_surface_count():
		var imported := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		var toon := ShaderMaterial.new()
		toon.shader = TOON
		if imported != null and imported.albedo_texture != null:
			toon.set_shader_parameter("drawing", imported.albedo_texture)
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE
		toon.next_pass = outline
		mesh.set_surface_override_material(surface, toon)
		materials.append(toon)


## Tail and ears follow the body with a little lag and settle, instead of being stiff (no take moves them).
func _add_spring_bones() -> void:
	if skeleton == null:
		return
	var chains: Array[Array] = []
	if skeleton.find_bone("Tail1") >= 0:
		chains.append(["Tail1", "Tail5", 0.45, 0.35])
	for ear: String in ["LeftEar", "RightEar"]:
		if skeleton.find_bone(ear) >= 0:
			chains.append([ear, ear, 1.4, 0.6])
	if chains.is_empty():
		return
	var springs := SpringBoneSimulator3D.new()
	springs.name = "Springs"
	springs.setting_count = chains.size()
	for i in chains.size():
		var chain: Array = chains[i]
		springs.set_root_bone_name(i, chain[0])
		springs.set_end_bone_name(i, chain[1])
		springs.set_stiffness(i, chain[2])
		springs.set_drag(i, chain[3])
		springs.set_gravity(i, 0.0)
		# An ear is a single bone: the spring needs a tip beyond it to swing. The tail's last bone gets one too.
		springs.set_extend_end_bone(i, true)
		springs.set_end_bone_length(i, 0.06)
	skeleton.add_child(springs)


func _on_finished(clip: StringName) -> void:
	clip_finished.emit(String(clip))
	if not String(clip) in HOLDS and not String(clip) in LOOPS:
		play(IDLE)
