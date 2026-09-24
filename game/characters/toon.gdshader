// The characters' toon look (after Guilty Gear Xrd): flat two-tone shading from a light of the character's own, so an
// arena's lighting never changes how she reads, and a thin rim light on the lit side.
//
// Colour is the old Blender material's mix: the base vertex colour, blended toward the concept drawing (on UV 0) by a
// mask carried in the vertex colour's alpha (pipeline/blender/export_character.py packs them).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D drawing : source_color, filter_linear_mipmap, repeat_disable;
// Where the light comes from, in view space: from the upper left, a little in front.
uniform vec3 light_direction = vec3(-0.55, 0.65, 0.5);
// Where lit turns to shadow, and how soft that edge is (0 is a hard cel line).
uniform float threshold : hint_range(-1.0, 1.0) = 0.1;
uniform float softness : hint_range(0.0, 0.5) = 0.04;
// The shadow tone, multiplied into the colour: a cool purple reads as shade, not dirt.
uniform vec3 shadow_tint : source_color = vec3(0.62, 0.55, 0.78);
uniform vec3 rim_colour : source_color = vec3(1.0, 0.86, 0.7);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.35;
uniform float rim_width : hint_range(0.0, 1.0) = 0.22;
// Brightness overall, and a flash (hurt, cast) blended over everything.
uniform float exposure = 1.0;
uniform vec4 flash : source_color = vec4(1.0, 1.0, 1.0, 0.0);

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 drawn = texture(drawing, UV).rgb;
	vec3 albedo = mix(base, drawn, clamp(COLOR.a, 0.0, 1.0));
	float lit = smoothstep(threshold - softness, threshold + softness, dot(normalize(NORMAL), normalize(light_direction)));
	vec3 colour = albedo * mix(shadow_tint, vec3(1.0), lit);
	float facing = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0, facing) * lit;
	colour += rim_colour * rim * rim_strength;
	colour *= exposure;
	ALBEDO = mix(colour, flash.rgb, flash.a);
}
