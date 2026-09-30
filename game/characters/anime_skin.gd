class_name AnimeSkin
extends RefCounted
## A normalised humanoid skin (ADR-0029): a glTF made by `pipeline/blender/normalize_rig.py`, with a `skin.json` beside
## it naming its materials' shaders, textures and colours and its spring chains. Dressed here in the anime shaders.
##
##   characters/<id>/skin.json            a shipped skin
##   characters/_local/<id>/skin.json     a reference skin kept on this machine only (git-ignored)

const TOON := preload("res://characters/anime_toon.gdshader")
const FACE := preload("res://characters/anime_face.gdshader")
const OUTLINE := preload("res://characters/anime_outline.gdshader")
## How a VRM skin is drawn: its own MToon, the anime shaders, or the anime shaders with ink lines (ADR-0029).
const VRM_STYLES: Array[String] = ["mtoon", "anime", "anime-ink"]
const FOLDERS: Array[String] = ["res://characters/%s/", "res://characters/_local/%s/"]
## skin.json colour names -> shader uniforms (the Blender material's group inputs keep their own names).
const COLOURS := {
	"ShadowColor1": "shadow_1",
	"ShadowColor2": "shadow_2",
	"ShadowColor3": "shadow_3",
	"ShadowColor4": "shadow_4",
	"ShadowColor5": "shadow_5",
	"SpecularColor1": "specular_1",
	"SpecularColor2": "specular_2",
	"SpecularColor3": "specular_3",
	"SpecularColor4": "specular_4",
	"SpecularColor5": "specular_5",
	"ShadowColor": "shadow",
}


## The skin's folder, or "" when the id has no skin.json.
static func folder(id: String) -> String:
	for pattern in FOLDERS:
		if FileAccess.file_exists(pattern % id + "skin.json"):
			return pattern % id
	return ""


static func read(skin_folder: String) -> Dictionary:
	var file := FileAccess.open(skin_folder + "skin.json", FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) as Dictionary if file != null else {}


## Every surface whose material skin.json knows gets its anime shader; returns the materials made.
static func dress(model: Node3D, skin_folder: String, facts: Dictionary) -> Array[ShaderMaterial]:
	var made: Array[ShaderMaterial] = []
	var known: Dictionary = facts.get("materials", {})
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var imported := mesh.mesh.surface_get_material(surface)
			var name := imported.resource_name if imported != null else ""
			if not name in known:
				continue
			var material := _material(skin_folder, known[name] as Dictionary)
			mesh.set_surface_override_material(surface, material)
			made.append(material)
	return made


static func is_face(material: ShaderMaterial) -> bool:
	return material.shader == FACE


static func _material(skin_folder: String, entry: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FACE if entry.get("shader") == "face" else TOON
	var textures: Dictionary = entry.get("textures", {})
	for role: String in textures:
		var path: String = skin_folder + "textures/" + String(textures[role])
		if ResourceLoader.exists(path):
			material.set_shader_parameter(role, load(path))
	# A texture's alpha is transparency only where skin.json says so (game rips pack masks into it).
	material.set_shader_parameter("alpha_cut", float(entry.get("alpha_cut", 0.0)))
	material.set_shader_parameter("use_mask", textures.has("mask"))
	material.set_shader_parameter("use_lightmap", textures.has("lightmap"))
	var params: Dictionary = entry.get("params", {})
	for key: String in params:
		if key in COLOURS and params[key] is Array:
			var c: Array = params[key]
			material.set_shader_parameter(COLOURS[key], Color(c[0], c[1], c[2], c[3] if c.size() > 3 else 1.0))
	if params.get("LUT") is float and textures.has("lut"):
		material.set_shader_parameter("lut_amount", params["LUT"])
	elif textures.has("lut"):
		material.set_shader_parameter("lut_amount", 1.0)
	return material


## Hair, skirt and accessory chains follow the body on springs (each from its root bone to its deepest descendant).
static func springs(skeleton: Skeleton3D, chains: Array) -> SpringBoneSimulator3D:
	var roots: Array[String] = []
	for chain: String in chains:
		if skeleton.find_bone(chain) >= 0 and not skeleton.get_bone_children(skeleton.find_bone(chain)).is_empty():
			roots.append(chain)
	if roots.is_empty():
		return null
	var simulator := SpringBoneSimulator3D.new()
	simulator.name = "Springs"
	simulator.setting_count = roots.size()
	for i in roots.size():
		var bone := skeleton.find_bone(roots[i])
		while not skeleton.get_bone_children(bone).is_empty():
			bone = skeleton.get_bone_children(bone)[0]
		simulator.set_root_bone_name(i, roots[i])
		simulator.set_end_bone_name(i, skeleton.get_bone_name(bone))
		simulator.set_stiffness(i, 0.6)
		simulator.set_drag(i, 0.45)
		simulator.set_gravity(i, 0.25)
		simulator.set_extend_end_bone(i, true)
		simulator.set_end_bone_length(i, 0.04)
	return simulator


## A VRM skin in the anime shaders instead of MToon: the lit colour from its main texture, the shade from its own
## painted shade texture, the face lit flat (a VRoid face is painted for it), and optionally an ink line and a rim.
## Soft-transparent layers (eye highlights, blush) keep MToon. Returns the materials made.
static func restyle_vrm(model: Node3D, ink: bool, rim: float) -> Array[ShaderMaterial]:
	var made: Array[ShaderMaterial] = []
	# A VRoid mesh splits one material over many surfaces (its hair over fifty): each is converted once and shared.
	var converted := {}
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var mtoon := mesh.get_active_material(surface) as ShaderMaterial
			if mtoon == null or mtoon.shader == null or "trans" in mtoon.shader.resource_path:
				continue
			if not mtoon in converted:
				var material := _from_mtoon(mtoon, mesh.mesh.surface_get_material(surface).resource_name, rim)
				if ink:
					var line := ShaderMaterial.new()
					line.shader = OUTLINE
					line.set_shader_parameter("diffuse", mtoon.get_shader_parameter("_MainTex"))
					line.set_shader_parameter("alpha_cut", material.get_shader_parameter("alpha_cut"))
					material.next_pass = line
				converted[mtoon] = material
				made.append(material)
			mesh.set_surface_override_material(surface, converted[mtoon])
	return made


static func _from_mtoon(mtoon: ShaderMaterial, name: String, rim: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var cutout := _number(mtoon.get_shader_parameter("_AlphaCutoutEnable"), 0.0) > 0.5
	cutout = cutout or "cutout" in mtoon.shader.resource_path
	var cut := _number(mtoon.get_shader_parameter("_Cutoff"), 0.5)
	var main: Variant = mtoon.get_shader_parameter("_MainTex")
	var lit: Variant = mtoon.get_shader_parameter("_Color")
	var shade: Variant = mtoon.get_shader_parameter("_ShadeColor")
	if "Face_00_SKIN" in name or "_FACE" in name.to_upper() and "SKIN" in name.to_upper():
		material.shader = FACE
		material.set_shader_parameter("diffuse", main)
		if shade is Color:
			material.set_shader_parameter("shadow", shade)
	else:
		material.shader = TOON
		material.set_shader_parameter("diffuse", main)
		material.set_shader_parameter("use_shade_map", true)
		material.set_shader_parameter("shade_map", mtoon.get_shader_parameter("_ShadeTexture"))
		if lit is Color:
			material.set_shader_parameter("lit_tint", lit)
		if shade is Color:
			material.set_shader_parameter("shade_tint", shade)
		material.set_shader_parameter("edge", 0.12)
		material.set_shader_parameter("rim", rim)
	material.set_shader_parameter("alpha_cut", cut if cutout else 0.0)
	return material


## A shader parameter never set on a material reads as null.
static func _number(value: Variant, fallback: float) -> float:
	return float(value) if value is float or value is int else fallback
